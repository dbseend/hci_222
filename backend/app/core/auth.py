import asyncio
from dataclasses import dataclass
from functools import lru_cache
from uuid import UUID

import httpx
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from app.core.env import env_value


AUTH_TIMEOUT_SECONDS = 5.0


class InvalidAccessToken(RuntimeError):
    pass


class AuthenticationUnavailable(RuntimeError):
    pass


@dataclass(frozen=True)
class AuthenticatedUser:
    id: str
    is_anonymous: bool = False


class SupabaseAuthVerifier:
    def __init__(
        self,
        *,
        supabase_url: str | None = None,
        publishable_key: str | None = None,
        http_client: httpx.AsyncClient | None = None,
    ) -> None:
        self._supabase_url = (
            supabase_url
            if supabase_url is not None
            else (env_value("SUPABASE_URL") or "")
        ).rstrip("/")
        self._publishable_key = (
            publishable_key
            if publishable_key is not None
            else (
                env_value("SUPABASE_PUBLISHABLE_KEY")
                or env_value("SUPABASE_ANON_KEY")
                or ""
            )
        )
        self._http_client = http_client
        self._owns_http_client = http_client is None
        self._client_lock = asyncio.Lock()

    async def verify(self, access_token: str) -> AuthenticatedUser:
        if not self._supabase_url or not self._publishable_key:
            raise AuthenticationUnavailable(
                "Set SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY on the backend."
            )

        client = await self._get_http_client()
        try:
            response = await client.get(
                f"{self._supabase_url}/auth/v1/user",
                headers={
                    "apikey": self._publishable_key,
                    "Authorization": f"Bearer {access_token}",
                },
            )
        except (httpx.TimeoutException, httpx.RequestError) as exc:
            raise AuthenticationUnavailable("Supabase Auth is unavailable.") from exc

        if response.status_code in {400, 401, 403}:
            raise InvalidAccessToken("Invalid or expired access token.")
        if response.status_code != 200:
            raise AuthenticationUnavailable("Supabase Auth is unavailable.")

        try:
            payload = response.json()
            user_id = str(UUID(str(payload["id"])))
        except (KeyError, TypeError, ValueError) as exc:
            raise AuthenticationUnavailable(
                "Supabase Auth returned an invalid user response."
            ) from exc

        return AuthenticatedUser(
            id=user_id,
            is_anonymous=bool(payload.get("is_anonymous", False)),
        )

    async def aclose(self) -> None:
        client = self._http_client
        if self._owns_http_client and client is not None:
            await client.aclose()
            self._http_client = None

    async def _get_http_client(self) -> httpx.AsyncClient:
        if self._http_client is not None:
            return self._http_client
        async with self._client_lock:
            if self._http_client is None:
                self._http_client = httpx.AsyncClient(
                    timeout=AUTH_TIMEOUT_SECONDS,
                )
            return self._http_client


_bearer = HTTPBearer(auto_error=False)


@lru_cache(maxsize=1)
def get_auth_verifier() -> SupabaseAuthVerifier:
    return SupabaseAuthVerifier()


async def get_current_user(
    credentials: HTTPAuthorizationCredentials | None = Depends(_bearer),
    verifier: SupabaseAuthVerifier = Depends(get_auth_verifier),
) -> AuthenticatedUser:
    if credentials is None or credentials.scheme.lower() != "bearer":
        raise _unauthorized()

    try:
        return await verifier.verify(credentials.credentials)
    except InvalidAccessToken as exc:
        raise _unauthorized() from exc
    except AuthenticationUnavailable as exc:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Authentication service is unavailable.",
        ) from exc


def _unauthorized() -> HTTPException:
    return HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Valid bearer token required.",
        headers={"WWW-Authenticate": "Bearer"},
    )
