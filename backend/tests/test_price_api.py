from fastapi.testclient import TestClient

from app.main import app


client = TestClient(app)


def test_list_products_contains_yolo_classes() -> None:
    response = client.get("/api/v1/products")

    assert response.status_code == 200
    product_ids = {item["product_id"] for item in response.json()}
    assert {"tomato", "camel_doll"}.issubset(product_ids)


def test_read_price_stats_for_tomato() -> None:
    response = client.get("/api/v1/products/tomato/price-stats?region=cairo")

    assert response.status_code == 200
    body = response.json()
    assert body["product_id"] == "tomato"
    assert body["avg_price"] == 20


def test_compare_price_returns_negotiable_verdict() -> None:
    response = client.post(
        "/api/v1/price/compare",
        json={
            "product_id": "tomato",
            "region": "cairo",
            "user_price": 25,
            "currency": "EGP",
        },
    )

    assert response.status_code == 200
    body = response.json()
    assert body["product_id"] == "tomato"
    assert body["verdict"] == "negotiable"
    assert body["percent_diff"] == 25.0


def test_unknown_product_returns_404() -> None:
    response = client.get("/api/v1/products/grapes/price-stats?region=cairo")

    assert response.status_code == 404
