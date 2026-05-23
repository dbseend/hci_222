from app.models.price import PriceCompareRequest, PriceCompareResponse, PriceStats, Product, Verdict


def compare_price(
    request: PriceCompareRequest,
    product: Product,
    stats: PriceStats,
) -> PriceCompareResponse:
    percent_diff = _percent_diff(request.user_price, stats.avg_price)
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
        message=_message(verdict, percent_diff),
    )


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


def _message(verdict: Verdict, percent_diff: float) -> str:
    if verdict == "safe":
        return "At or below the Cairo reference. Use it as a negotiation guide."
    if verdict == "negotiable":
        return f"Slightly above the Cairo reference ({percent_diff:+.1f}%). Try negotiating."
    return f"High quote versus the Cairo reference ({percent_diff:+.1f}%). Negotiate strongly."
