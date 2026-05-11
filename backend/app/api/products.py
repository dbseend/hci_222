from fastapi import APIRouter, HTTPException, Query

from app.models.price import PriceStats, Product
from app.services.catalog_service import get_price_stats, get_product, load_products


router = APIRouter(prefix="/api/v1/products", tags=["products"])


@router.get("", response_model=list[Product])
def list_products() -> list[Product]:
    return load_products()


@router.get("/{product_id}", response_model=Product)
def read_product(product_id: str) -> Product:
    product = get_product(product_id)
    if product is None:
        raise HTTPException(status_code=404, detail="Unknown product_id")
    return product


@router.get("/{product_id}/price-stats", response_model=PriceStats)
def read_price_stats(
    product_id: str,
    region: str = Query(default="cairo"),
) -> PriceStats:
    if get_product(product_id) is None:
        raise HTTPException(status_code=404, detail="Unknown product_id")

    stats = get_price_stats(product_id, region)
    if stats is None:
        raise HTTPException(status_code=404, detail="No price stats for product/region")
    return stats
