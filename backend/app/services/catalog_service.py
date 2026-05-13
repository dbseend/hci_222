import json
import logging
from functools import lru_cache
from pathlib import Path
from typing import Any

from app.models.price import PriceStats, Product
from app.services.supabase_backend import SupabaseBackendUnavailable, get_supabase_client


DATA_DIR = Path(__file__).resolve().parents[1] / "data"
DEFAULT_REGION = "cairo"
logger = logging.getLogger(__name__)


@lru_cache(maxsize=1)
def load_products() -> list[Product]:
    try:
        return _load_products_from_supabase()
    except SupabaseBackendUnavailable as exc:
        logger.warning("catalog_products_supabase_unavailable reason=%s", exc)
        return _load_products_from_json()


@lru_cache(maxsize=1)
def load_price_stats() -> list[PriceStats]:
    try:
        return _load_price_stats_from_supabase()
    except SupabaseBackendUnavailable as exc:
        logger.warning("catalog_price_stats_supabase_unavailable reason=%s", exc)
        return _load_price_stats_from_json()


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


def _load_products_from_supabase() -> list[Product]:
    client = get_supabase_client()
    try:
        response = (
            client.table("price_reference_stats")
            .select("products!inner(code,name,default_unit,is_active)")
            .eq("region_code", DEFAULT_REGION)
            .order("stat_date", desc=True)
            .execute()
        )
    except Exception as exc:
        raise SupabaseBackendUnavailable("Failed to load products from Supabase.") from exc

    products_by_id: dict[str, Product] = {}
    for row in _rows(response):
        product_row = row.get("products") or {}
        if not product_row.get("is_active", True):
            continue
        product = _product_from_db_row(product_row)
        products_by_id.setdefault(product.product_id, product)
    products = sorted(products_by_id.values(), key=lambda item: item.product_id)
    if not products:
        raise SupabaseBackendUnavailable("Supabase products table returned no rows.")
    return products


def _load_price_stats_from_supabase() -> list[PriceStats]:
    client = get_supabase_client()
    try:
        response = (
            client.table("price_reference_stats")
            .select(
                "region_code,unit,window_days,stat_date,sample_count,"
                "weighted_avg_price_egp,median_price_egp,min_price_egp,"
                "max_price_egp,stddev_price_egp,"
                "products!inner(code,name,default_unit)"
            )
            .eq("region_code", DEFAULT_REGION)
            .order("stat_date", desc=True)
            .execute()
        )
    except Exception as exc:
        raise SupabaseBackendUnavailable("Failed to load price stats from Supabase.") from exc

    latest_by_product: dict[str, PriceStats] = {}
    for row in _rows(response):
        product = row.get("products") or {}
        product_id = str(product.get("code") or "").strip().lower()
        if not product_id or product_id in latest_by_product:
            continue
        latest_by_product[product_id] = _price_stats_from_db_row(row, product_id)

    stats = list(latest_by_product.values())
    if not stats:
        raise SupabaseBackendUnavailable("Supabase price_reference_stats returned no rows.")
    return stats


def _load_products_from_json() -> list[Product]:
    raw = json.loads((DATA_DIR / "product_catalog.json").read_text())
    return [Product(**item) for item in raw]


def _load_price_stats_from_json() -> list[PriceStats]:
    raw = json.loads((DATA_DIR / "price_stats.json").read_text())
    return [PriceStats(**item) for item in raw]


def _product_from_db_row(row: dict[str, Any]) -> Product:
    return Product(
        product_id=str(row["code"]).strip().lower(),
        display_name=str(row["name"]),
        unit=str(row.get("default_unit") or "kg"),
        aliases=[],
    )


def _price_stats_from_db_row(row: dict[str, Any], product_id: str) -> PriceStats:
    return PriceStats(
        product_id=product_id,
        region=str(row.get("region_code") or DEFAULT_REGION),
        currency="EGP",
        avg_price=float(row.get("weighted_avg_price_egp") or 0),
        median_price=float(row.get("median_price_egp") or 0),
        min_price=float(row.get("min_price_egp") or 0),
        max_price=float(row.get("max_price_egp") or 0),
        stddev_price=float(row.get("stddev_price_egp") or 0),
        sample_count=int(row.get("sample_count") or 0),
    )


def _rows(response) -> list[dict[str, Any]]:
    data = getattr(response, "data", None)
    if data is None and isinstance(response, dict):
        data = response.get("data")
    if data is None:
        return []
    return list(data)
