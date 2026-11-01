from app.models.price import PriceCompareRequest, PriceStats, Product
from app.services.price_matcher import compare_price


def test_comparison_message_uses_the_actual_reference_region() -> None:
    result = compare_price(
        PriceCompareRequest(
            product_id="tomato",
            region="alexandria",
            user_price=22,
            currency="EGP",
        ),
        Product(
            product_id="tomato",
            display_name="Tomato",
            category="food",
            unit="kg",
        ),
        PriceStats(
            product_id="tomato",
            region="alexandria",
            currency="EGP",
            unit="kg",
            sample_count=20,
            avg_price=20,
            median_price=20,
            min_price=10,
            max_price=30,
            stddev_price=3,
        ),
    )

    assert "Alexandria reference" in result.message
    assert "Cairo" not in result.message
