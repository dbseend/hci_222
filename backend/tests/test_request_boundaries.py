from fastapi.testclient import TestClient

from app import main as app_main


client = TestClient(app_main.app)


def test_request_body_content_length_is_rejected_before_route() -> None:
    response = client.post(
        "/health",
        content=b"0" * (app_main.MAX_REQUEST_BODY_BYTES + 1),
    )

    assert response.status_code == 413
    assert response.json() == {"detail": "Request body is too large."}
