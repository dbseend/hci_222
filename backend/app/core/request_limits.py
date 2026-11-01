from starlette.responses import JSONResponse
from starlette.types import ASGIApp, Message, Receive, Scope, Send


class _RequestBodyTooLarge(RuntimeError):
    pass


class RequestBodyLimitMiddleware:
    def __init__(self, app: ASGIApp, *, max_bytes: int) -> None:
        if max_bytes <= 0:
            raise ValueError("max_bytes must be positive")
        self._app = app
        self._max_bytes = max_bytes

    async def __call__(
        self,
        scope: Scope,
        receive: Receive,
        send: Send,
    ) -> None:
        if scope["type"] != "http":
            await self._app(scope, receive, send)
            return

        content_lengths = [
            value
            for name, value in scope.get("headers", [])
            if name.lower() == b"content-length"
        ]
        if len(content_lengths) > 1:
            await self._error_response(
                scope,
                receive,
                send,
                status_code=400,
                detail="Invalid Content-Length header.",
            )
            return
        if content_lengths:
            try:
                declared_size = int(content_lengths[0])
            except (TypeError, ValueError):
                await self._error_response(
                    scope,
                    receive,
                    send,
                    status_code=400,
                    detail="Invalid Content-Length header.",
                )
                return
            if declared_size < 0:
                await self._error_response(
                    scope,
                    receive,
                    send,
                    status_code=400,
                    detail="Invalid Content-Length header.",
                )
                return
            if declared_size > self._max_bytes:
                await self._too_large_response(scope, receive, send)
                return

        received_bytes = 0
        response_started = False

        async def limited_receive() -> Message:
            nonlocal received_bytes
            message = await receive()
            if message["type"] == "http.request":
                received_bytes += len(message.get("body", b""))
                if received_bytes > self._max_bytes:
                    raise _RequestBodyTooLarge
            return message

        async def tracked_send(message: Message) -> None:
            nonlocal response_started
            if message["type"] == "http.response.start":
                response_started = True
            await send(message)

        try:
            await self._app(scope, limited_receive, tracked_send)
        except _RequestBodyTooLarge:
            if response_started:
                raise
            await self._too_large_response(scope, receive, send)

    async def _too_large_response(
        self,
        scope: Scope,
        receive: Receive,
        send: Send,
    ) -> None:
        await self._error_response(
            scope,
            receive,
            send,
            status_code=413,
            detail="Request body is too large.",
        )

    async def _error_response(
        self,
        scope: Scope,
        receive: Receive,
        send: Send,
        *,
        status_code: int,
        detail: str,
    ) -> None:
        response = JSONResponse(
            status_code=status_code,
            content={"detail": detail},
        )
        await response(scope, receive, send)
