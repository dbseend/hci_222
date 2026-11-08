import math

from app.models.price import PriceCompareRequest, PriceCompareResponse, PriceStats, Product, Verdict
from app.services import robust_stats


def compare_price(
    request: PriceCompareRequest,
    product: Product,
    stats: PriceStats,
) -> PriceCompareResponse:
    robust = _has_robust_scale(stats)
    center = stats.median_price if robust else stats.avg_price
    percent_diff = _percent_diff(request.user_price, center)
    if robust:
        sigma = robust_stats.MAD_TO_SIGMA * float(stats.mad_price or 0)
        z = robust_stats.robust_z(request.user_price, stats.median_price, sigma)
        verdict: Verdict = robust_stats.classify_z(z)  # type: ignore[assignment]
        confidence = _robust_confidence(stats, sigma)
    else:
        z, confidence = None, None
        verdict = _verdict(request.user_price, stats)

    return PriceCompareResponse(
        product_id=product.product_id,
        display_name=product.display_name,
        unit=product.unit,
        region=stats.region,
        currency=stats.currency,
        user_price=request.user_price,
        avg_price=stats.avg_price,
        median_price=stats.median_price,
        min_price=stats.min_price,
        max_price=stats.max_price,
        stddev_price=stats.stddev_price,
        sample_count=stats.sample_count,
        percent_diff=percent_diff,
        verdict=verdict,
        message=_message(verdict, percent_diff, stats.region),
        method="robust_mad" if robust else "zscore",
        robust_z=round(z, 3) if z is not None and math.isfinite(z) else None,
        confidence_score=confidence,
    )


def _has_robust_scale(stats: PriceStats) -> bool:
    return stats.mad_price is not None and stats.median_price > 0


def _robust_confidence(stats: PriceStats, sigma: float) -> float:
    # Only real (non-synthetic) observations earn trust.
    real_n = stats.real_sample_count
    if real_n is None:
        real_n = stats.sample_count
    effective = min(float(real_n), stats.effective_sample_size or float(real_n))
    return robust_stats.confidence_score(effective, stats.median_price, sigma)


def _percent_diff(user_price: float, avg_price: float) -> float:
    if avg_price <= 0:
        return 0
    return round((user_price - avg_price) / avg_price * 100, 1)


def _verdict(user_price: float, stats: PriceStats) -> Verdict:
    if stats.stddev_price <= 0:
        return "warning" if user_price > stats.avg_price else "safe"

    z_score = (user_price - stats.avg_price) / stats.stddev_price
    if z_score > 1.5:
        return "warning"
    if z_score > 0:
        return "negotiable"
    return "safe"


def _message(verdict: Verdict, percent_diff: float, region: str) -> str:
    region_label = region.replace("_", " ").strip().title()
    if verdict == "safe":
        return f"At or below the {region_label} reference. Use it as a negotiation guide."
    if verdict == "negotiable":
        return (
            f"Slightly above the {region_label} reference "
            f"({percent_diff:+.1f}%). Try negotiating."
        )
    return (
        f"High quote versus the {region_label} reference "
        f"({percent_diff:+.1f}%). Negotiate strongly."
    )
