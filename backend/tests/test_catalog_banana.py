from app.services import catalog_service


def test_banana_is_a_supported_product() -> None:
    assert "banana" in catalog_service.SUPPORTED_PRODUCT_IDS


def test_banana_exists_in_local_catalog_and_price_stats() -> None:
    products = {item.product_id for item in catalog_service._load_products_from_json()}
    stats = {item.product_id for item in catalog_service._load_price_stats_from_json()}

    assert "banana" in products
    assert "banana" in stats
