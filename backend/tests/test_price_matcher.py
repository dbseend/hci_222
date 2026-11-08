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


def _robust_stats(**overrides) -> PriceStats:
    base = dict(
        product_id="tomato",
        region="cairo",
        currency="EGP",
        avg_price=30,
        median_price=20,
        min_price=10,
        max_price=90,
        stddev_price=25,
        sample_count=40,
        mad_price=4,
        real_sample_count=5,
        synthetic_sample_count=35,
    )
    base.update(overrides)
    return PriceStats(**base)


def _compare(price: float, stats: PriceStats):
    return compare_price(
        PriceCompareRequest(product_id="tomato", region="cairo", user_price=price, currency="EGP"),
        Product(product_id="tomato", display_name="Tomato", unit="kg"),
        stats,
    )


def test_robust_verdict_uses_median_and_mad_not_skewed_mean() -> None:
    # sigma_r = 1.4826 * 4 = 5.93; price 30 -> z = 1.69 -> warning,
    # although the skewed legacy mean (30) would call it "safe".
    result = _compare(30, _robust_stats())
    assert result.method == "robust_mad"
    assert result.verdict == "warning"
    assert result.robust_z == 1.686


def test_robust_confidence_ignores_synthetic_samples() -> None:
    few_real = _compare(20, _robust_stats(real_sample_count=5))
    many_real = _compare(20, _robust_stats(real_sample_count=40))
    assert few_real.confidence_score < many_real.confidence_score
    assert few_real.confidence_score < 45  # low confidence while data is synthetic


def test_legacy_zscore_path_is_unchanged_without_mad() -> None:
    result = _compare(30, _robust_stats(mad_price=None))
    assert result.method == "zscore"
    assert result.robust_z is None and result.confidence_score is None
