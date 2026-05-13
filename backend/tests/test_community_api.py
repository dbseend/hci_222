from fastapi.testclient import TestClient

from app.api import community
from app.main import app
from app.models.community import CommunityPostResponse


client = TestClient(app)


def test_read_community_feed(monkeypatch) -> None:
    monkeypatch.setattr(
        community,
        "list_community_posts",
        lambda: [
            CommunityPostResponse(
                id="post-1",
                product_name="Apple",
                price=20,
                store_name="Market",
                location_name="Cairo",
                image_path="https://example.com/apple.jpg",
                created_at="2026-05-13T00:00:00Z",
            )
        ],
    )

    response = client.get("/api/v1/community/feed")

    assert response.status_code == 200
    assert response.json()[0]["product_name"] == "Apple"
    assert response.json()[0]["image_path"] == "https://example.com/apple.jpg"


def test_create_community_post(monkeypatch) -> None:
    calls = {}

    def fake_create_community_post(**kwargs):
        calls.update(kwargs)

    monkeypatch.setattr(community, "create_community_post", fake_create_community_post)

    response = client.post(
        "/api/v1/community/posts",
        files={"image": ("apple.jpg", b"fake-image", "image/jpeg")},
        data={
            "payload": (
                '{"product_name":"Apple","price":20,'
                '"product_code":"p001","store_name":"Market",'
                '"location_name":"Cairo","client_user_id":"client-1"}'
            )
        },
    )

    assert response.status_code == 201
    assert calls["payload"].product_name == "Apple"
    assert calls["image_bytes"] == b"fake-image"
    assert calls["filename"] == "apple.jpg"
