from fastapi import APIRouter, HTTPException

from app.models.price import PriceCompareRequest, PriceCompareResponse
from app.services.catalog_service import get_price_stats, get_product
from app.services.price_matcher import compare_price


router = APIRouter(prefix="/api/v1/price", tags=["price"])


@router.post("/compare", response_model=PriceCompareResponse)
def compare(request: PriceCompareRequest) -> PriceCompareResponse:
    product = get_product(request.product_id)
    if product is None:
        raise HTTPException(status_code=404, detail="Unknown product_id")

    stats = get_price_stats(request.product_id, request.region)
    if stats is None:
        raise HTTPException(status_code=404, detail="No price stats for product/region")

    if request.currency.upper() != stats.currency.upper():
        raise HTTPException(status_code=400, detail="Unsupported currency for product/region")

    return compare_price(request, product, stats)
