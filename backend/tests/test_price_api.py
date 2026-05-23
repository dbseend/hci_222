from fastapi.testclient import TestClient

from app.main import app
from app.services import catalog_service


client = TestClient(app)


def test_list_products_contains_supported_price_reference_classes() -> None:
    response = client.get("/api/v1/products")

    assert response.status_code == 200
    product_ids = {item["product_id"] for item in response.json()}
    assert {
        "apple",
        "avocado",
        "blueberry",
        "camel_doll",
        "cherry",
        "cherry_tomato",
        "kiwi",
        "mango",
        "orange",
        "rockmelon",
        "strawberry",
        "tomato",
    }.issubset(product_ids)


def test_list_products_excludes_products_without_current_reference() -> None:
    response = client.get("/api/v1/products")

    assert response.status_code == 200
    product_ids = {item["product_id"] for item in response.json()}
    assert "banana" not in product_ids
    assert "watermelon" not in product_ids


def test_every_catalog_product_has_cairo_price_stats() -> None:
    products_response = client.get("/api/v1/products")

    assert products_response.status_code == 200
    for product in products_response.json():
        stats_response = client.get(
            f"/api/v1/products/{product['product_id']}/price-stats?region=cairo"
        )

        assert stats_response.status_code == 200, product["product_id"]
        assert stats_response.json()["currency"] == "EGP"


def test_read_price_stats_for_multiclass_fruit() -> None:
    response = client.get("/api/v1/products/apple/price-stats?region=cairo")

    assert response.status_code == 200
    body = response.json()
    assert body["product_id"] == "apple"
    assert body["avg_price"] > 0


def test_read_price_stats_for_avocado_mvp_seed() -> None:
    response = client.get("/api/v1/products/avocado/price-stats?region=cairo")

    assert response.status_code == 200
    body = response.json()
    assert body["product_id"] == "avocado"
    assert body["avg_price"] > 0


def test_read_price_stats_for_cherry_tomato_fixed_mvp_seed() -> None:
    response = client.get("/api/v1/products/cherry_tomato/price-stats?region=cairo")

    assert response.status_code == 200
    body = response.json()
    assert body["product_id"] == "cherry_tomato"
    assert body["avg_price"] > 0


def test_read_price_stats_for_tomato() -> None:
    response = client.get("/api/v1/products/tomato/price-stats?region=cairo")

    assert response.status_code == 200
    body = response.json()
    assert body["product_id"] == "tomato"
    assert body["avg_price"] > 0


def test_read_price_stats_for_today_egypt_orange_seed() -> None:
    response = client.get("/api/v1/products/orange/price-stats?region=cairo")

    assert response.status_code == 200
    body = response.json()
    assert body["product_id"] == "orange"
    assert body["avg_price"] > 0
    assert body["sample_count"] > 0


def test_compare_price_returns_warning_for_high_price() -> None:
    response = client.post(
        "/api/v1/price/compare",
        json={
            "product_id": "tomato",
            "region": "cairo",
            "user_price": 1000,
            "currency": "EGP",
        },
    )

    assert response.status_code == 200
    body = response.json()
    assert body["product_id"] == "tomato"
    assert body["verdict"] == "warning"
    assert body["percent_diff"] > 0


def test_unknown_product_returns_404() -> None:
    response = client.get("/api/v1/products/moon_fruit/price-stats?region=cairo")

    assert response.status_code == 404


def test_catalog_service_maps_supabase_rows(monkeypatch) -> None:
    catalog_service.load_products.cache_clear()
    catalog_service.load_price_stats.cache_clear()

    fake_client = _FakeSupabaseClient(
        {
            "products": [
                {"code": "tomato", "name": "Tomato", "default_unit": "kg"},
            ],
            "price_reference_stats": [
                {
                    "region_code": "cairo",
                    "unit": "kg",
                    "sample_count": 151,
                    "weighted_avg_price_egp": "25.04",
                    "median_price_egp": "22.23",
                    "min_price_egp": "10.0",
                    "max_price_egp": "99.99",
                    "stddev_price_egp": "12.34",
                    "products": {
                        "code": "tomato",
                        "name": "Tomato",
                        "default_unit": "kg",
                    },
                },
            ],
        }
    )
    monkeypatch.setattr(catalog_service, "get_supabase_client", lambda: fake_client)

    products = catalog_service.load_products()
    stats = catalog_service.load_price_stats()

    assert products[0].product_id == "tomato"
    assert products[0].display_name == "Tomato"
    assert stats[0].product_id == "tomato"
    assert stats[0].avg_price == 25.04
    assert stats[0].sample_count == 151

    catalog_service.load_products.cache_clear()
    catalog_service.load_price_stats.cache_clear()


class _FakeSupabaseClient:
    def __init__(self, rows_by_table: dict[str, list[dict]]) -> None:
        self.rows_by_table = rows_by_table

    def table(self, name: str):
        return _FakeSupabaseQuery(self.rows_by_table[name])


class _FakeSupabaseQuery:
    def __init__(self, rows: list[dict]) -> None:
        self.rows = rows

    def select(self, *_args, **_kwargs):
        return self

    def eq(self, *_args, **_kwargs):
        return self

    def order(self, *_args, **_kwargs):
        return self

    def execute(self):
        return _FakeSupabaseResponse(self.rows)


class _FakeSupabaseResponse:
    def __init__(self, data: list[dict]) -> None:
        self.data = data
