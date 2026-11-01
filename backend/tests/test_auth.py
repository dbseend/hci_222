import asyncio

import httpx
import pytest

from app.core import auth
from app.core.auth import (
    AuthenticationUnavailable,
    InvalidAccessToken,
    SupabaseAuthVerifier,
)


def test_supabase_auth_verifier_returns_verified_user() -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        assert request.url == "https://project.supabase.co/auth/v1/user"
        assert request.headers["apikey"] == "publishable-key"
        assert request.headers["authorization"] == "Bearer valid-token"
        return httpx.Response(
            200,
            json={
                "id": "11111111-1111-4111-8111-111111111111",
                "is_anonymous": True,
            },
        )

    verifier = SupabaseAuthVerifier(
        supabase_url="https://project.supabase.co",
        publishable_key="publishable-key",
        http_client=httpx.AsyncClient(transport=httpx.MockTransport(handler)),
    )

    user = asyncio.run(verifier.verify("valid-token"))

    assert user.id == "11111111-1111-4111-8111-111111111111"
    assert user.is_anonymous is True


def test_supabase_auth_verifier_rejects_invalid_token() -> None:
    verifier = SupabaseAuthVerifier(
        supabase_url="https://project.supabase.co",
        publishable_key="publishable-key",
        http_client=httpx.AsyncClient(
            transport=httpx.MockTransport(
                lambda _: httpx.Response(401, json={"message": "invalid JWT"})
            )
        ),
    )

    with pytest.raises(InvalidAccessToken):
        asyncio.run(verifier.verify("invalid-token"))


def test_supabase_auth_verifier_fails_closed_when_not_configured() -> None:
    verifier = SupabaseAuthVerifier(supabase_url="", publishable_key="")

    with pytest.raises(AuthenticationUnavailable):
        asyncio.run(verifier.verify("token"))


def test_supabase_auth_verifier_reuses_owned_http_client(monkeypatch) -> None:
    clients = []

    class FakeAsyncClient:
        closed = False

        def __init__(self, **_kwargs):
            clients.append(self)

        async def get(self, *_args, **_kwargs):
            return httpx.Response(
                200,
                json={"id": "11111111-1111-4111-8111-111111111111"},
            )

        async def aclose(self):
            self.closed = True

    monkeypatch.setattr(auth.httpx, "AsyncClient", FakeAsyncClient)
    verifier = SupabaseAuthVerifier(
        supabase_url="https://project.supabase.co",
        publishable_key="publishable-key",
    )

    async def exercise_verifier() -> None:
        await verifier.verify("first-token")
        await verifier.verify("second-token")
        await verifier.aclose()

    asyncio.run(exercise_verifier())

    assert len(clients) == 1
    assert clients[0].closed is True
