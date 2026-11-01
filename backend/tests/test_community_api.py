from fastapi.testclient import TestClient

from app.api import community
from app.core.auth import get_current_user
from app.main import app
from app.models.community import CommunityPostResponse
from app.services.supabase_backend import SupabaseUnknownProduct
from tests.image_fixtures import jpeg_bytes


client = TestClient(app)
TEST_USER_ID = "11111111-1111-4111-8111-111111111111"
FAKE_JPEG = jpeg_bytes()


def test_read_community_feed(monkeypatch) -> None:
    calls = {}

    def fake_list_community_posts(*, limit: int):
        calls["limit"] = limit
        return [
            CommunityPostResponse(
                id="post-1",
                product_name="Apple",
                price=20,
                store_name="Market",
                location_name="Cairo",
                image_path="https://example.com/apple.jpg",
                created_at="2026-05-13T00:00:00Z",
            )
        ]

    monkeypatch.setattr(
        community,
        "list_community_posts",
        fake_list_community_posts,
    )

    response = client.get("/api/v1/community/feed?limit=25")

    assert response.status_code == 200
    assert response.json()[0]["product_name"] == "Apple"
    assert response.json()[0]["image_path"] == "https://example.com/apple.jpg"
    assert calls == {"limit": 25}


def test_read_community_feed_rejects_excessive_limit() -> None:
    response = client.get("/api/v1/community/feed?limit=101")

    assert response.status_code == 422


def test_create_community_post(monkeypatch) -> None:
    calls = {}

    def fake_create_community_post(**kwargs):
        calls.update(kwargs)

    monkeypatch.setattr(community, "create_community_post", fake_create_community_post)

    response = client.post(
        "/api/v1/community/posts",
        files={"image": ("apple.jpg", FAKE_JPEG, "image/jpeg")},
        data={
            "payload": (
                '{"product_name":"Apple","price":20,'
                '"product_code":"p001","store_name":"Market",'
                '"location_name":"Cairo"}'
            )
        },
    )

    assert response.status_code == 201
    assert calls["payload"].product_name == "Apple"
    assert calls["client_user_id"] == TEST_USER_ID
    assert calls["image_bytes"] == FAKE_JPEG
    assert calls["filename"] == "apple.jpg"


def test_create_community_post_requires_authentication() -> None:
    override = app.dependency_overrides.pop(get_current_user)
    try:
        response = client.post(
            "/api/v1/community/posts",
            data={
                "payload": (
                    '{"product_name":"Apple","price":20,'
                    '"product_code":"p001","store_name":"Market",'
                    '"location_name":"Cairo"}'
                )
            },
        )
    finally:
        app.dependency_overrides[get_current_user] = override

    assert response.status_code == 401


def test_create_community_post_rejects_unknown_product(monkeypatch) -> None:
    def fake_create_community_post(**_kwargs):
        raise SupabaseUnknownProduct("Unknown product code: attacker_product")

    monkeypatch.setattr(community, "create_community_post", fake_create_community_post)

    response = client.post(
        "/api/v1/community/posts",
        data={
            "payload": (
                '{"product_name":"Injected","price":20,'
                '"product_code":"attacker_product","store_name":"Market",'
                '"location_name":"Cairo"}'
            )
        },
    )

    assert response.status_code == 422


def test_create_community_post_rejects_oversized_image(monkeypatch) -> None:
    monkeypatch.setattr(community, "MAX_IMAGE_UPLOAD_BYTES", 8)

    response = client.post(
        "/api/v1/community/posts",
        files={"image": ("large.jpg", FAKE_JPEG, "image/jpeg")},
        data={
            "payload": (
                '{"product_name":"Apple","price":20,'
                '"product_code":"apple","store_name":"Market",'
                '"location_name":"Cairo"}'
            )
        },
    )

    assert response.status_code == 413
