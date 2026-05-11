import json
from functools import lru_cache
from pathlib import Path

from app.models.price import PriceStats, Product


DATA_DIR = Path(__file__).resolve().parents[1] / "data"


@lru_cache(maxsize=1)
def load_products() -> list[Product]:
    raw = json.loads((DATA_DIR / "product_catalog.json").read_text())
    return [Product(**item) for item in raw]


@lru_cache(maxsize=1)
def load_price_stats() -> list[PriceStats]:
    raw = json.loads((DATA_DIR / "price_stats.json").read_text())
    return [PriceStats(**item) for item in raw]


def get_product(product_id: str) -> Product | None:
    normalized = product_id.strip().lower()
    return next(
        (product for product in load_products() if product.product_id == normalized),
        None,
    )


def get_price_stats(product_id: str, region: str) -> PriceStats | None:
    normalized_product = product_id.strip().lower()
    normalized_region = region.strip().lower()
    return next(
        (
            stats
            for stats in load_price_stats()
            if stats.product_id == normalized_product and stats.region == normalized_region
        ),
        None,
    )
