import asyncio

from app.core.request_limits import RequestBodyLimitMiddleware


def test_chunked_body_is_rejected_after_crossing_limit() -> None:
    downstream_completed = False

    async def downstream(_scope, receive, send):
        nonlocal downstream_completed
        while True:
            message = await receive()
            if not message.get("more_body", False):
                break
        downstream_completed = True
        await send({"type": "http.response.start", "status": 204, "headers": []})
        await send({"type": "http.response.body", "body": b""})

    sent = asyncio.run(
        _run_middleware(
            RequestBodyLimitMiddleware(downstream, max_bytes=5),
            headers=[],
            request_messages=[
                {"type": "http.request", "body": b"123", "more_body": True},
                {"type": "http.request", "body": b"456", "more_body": False},
            ],
        )
    )

    assert sent[0]["status"] == 413
    assert downstream_completed is False


def test_invalid_content_length_is_rejected_before_downstream() -> None:
    async def downstream(_scope, _receive, _send):
        raise AssertionError("downstream must not run")

    sent = asyncio.run(
        _run_middleware(
            RequestBodyLimitMiddleware(downstream, max_bytes=5),
            headers=[(b"content-length", b"not-a-number")],
            request_messages=[],
        )
    )

    assert sent[0]["status"] == 400


async def _run_middleware(middleware, *, headers, request_messages):
    messages = iter(request_messages)
    sent = []

    async def receive():
        return next(messages)

    async def send(message):
        sent.append(message)

    await middleware(
        {
            "type": "http",
            "http_version": "1.1",
            "method": "POST",
            "scheme": "http",
            "path": "/upload",
            "raw_path": b"/upload",
            "query_string": b"",
            "headers": headers,
            "client": ("127.0.0.1", 1234),
            "server": ("testserver", 80),
        },
        receive,
        send,
    )
    return sent
