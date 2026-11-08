import json
import logging
from pathlib import Path
from threading import RLock
from time import monotonic
from typing import Any

from app.core.config import DEFAULT_CURRENCY, DEFAULT_REGION
from app.core.env import env_value
from app.models.price import PriceStats, Product
from app.services.supabase_backend import SupabaseBackendUnavailable, get_supabase_client


DATA_DIR = Path(__file__).resolve().parents[1] / "data"
logger = logging.getLogger(__name__)
SUPPORTED_PRODUCT_IDS = {
    "apple",
    "avocado",
    "banana",
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
}
DEFAULT_CATALOG_CACHE_TTL_SECONDS = 300.0
_products_cache: tuple[float, list[Product]] | None = None
_price_stats_cache: tuple[float, list[PriceStats]] | None = None
_products_cache_lock = RLock()
_price_stats_cache_lock = RLock()


def load_products() -> list[Product]:
    global _products_cache
    with _products_cache_lock:
        now = monotonic()
        if _products_cache is not None and _products_cache[0] > now:
            return _products_cache[1]
        try:
            products = _load_products_from_supabase()
        except SupabaseBackendUnavailable as exc:
            if not _local_fallback_allowed():
                raise
            logger.warning("catalog_products_supabase_unavailable reason=%s", exc)
            products = _load_products_from_json()
        _products_cache = (now + _catalog_cache_ttl_seconds(), products)
        return products


def load_price_stats() -> list[PriceStats]:
    global _price_stats_cache
    with _price_stats_cache_lock:
        now = monotonic()
        if _price_stats_cache is not None and _price_stats_cache[0] > now:
            return _price_stats_cache[1]
        try:
            stats = _load_price_stats_from_supabase()
        except SupabaseBackendUnavailable as exc:
            if not _local_fallback_allowed():
                raise
            logger.warning("catalog_price_stats_supabase_unavailable reason=%s", exc)
            stats = _load_price_stats_from_json()
        _price_stats_cache = (now + _catalog_cache_ttl_seconds(), stats)
        return stats


def clear_catalog_cache() -> None:
    global _products_cache, _price_stats_cache
    with _products_cache_lock, _price_stats_cache_lock:
        _products_cache = None
        _price_stats_cache = None


def _catalog_cache_ttl_seconds() -> float:
    raw_value = env_value("TRUEPRICE_CATALOG_CACHE_TTL_SECONDS")
    if not raw_value:
        return DEFAULT_CATALOG_CACHE_TTL_SECONDS
    try:
        value = float(raw_value)
    except ValueError as exc:
        raise RuntimeError(
            "TRUEPRICE_CATALOG_CACHE_TTL_SECONDS must be a number."
        ) from exc
    if value <= 0:
        raise RuntimeError("TRUEPRICE_CATALOG_CACHE_TTL_SECONDS must be positive.")
    return value


def _local_fallback_allowed() -> bool:
    app_env = (env_value("TRUEPRICE_APP_ENV", "development") or "development").lower()
    if app_env == "production":
        return False
    configured = env_value("TRUEPRICE_ALLOW_LOCAL_DATA_FALLBACK")
    if configured is None:
        return True
    return configured.strip().lower() in {"1", "true", "yes", "on"}


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
        if product.product_id not in SUPPORTED_PRODUCT_IDS:
            continue
        products_by_id.setdefault(product.product_id, product)
    products = sorted(products_by_id.values(), key=lambda item: item.product_id)
    if not products:
        raise SupabaseBackendUnavailable("Supabase products table returned no rows.")
    return products


def _load_price_stats_from_supabase() -> list[PriceStats]:
    client = get_supabase_client()
    base_columns = (
        "region_code,unit,window_days,stat_date,sample_count,"
        "weighted_avg_price_egp,median_price_egp,min_price_egp,"
        "max_price_egp,stddev_price_egp,"
    )
    # Robust-stat columns exist only after backend/supabase/robust_stats_columns.sql
    # has been applied; fall back to the legacy column set before that.
    robust_columns = (
        "mad_price_egp,real_sample_count,synthetic_sample_count,"
        "effective_sample_size,decay_tau_days,"
    )
    response = None
    last_error: Exception | None = None
    for columns in (base_columns + robust_columns, base_columns):
        try:
            response = (
                client.table("price_reference_stats")
                .select(columns + "products!inner(code,name,default_unit)")
                .eq("region_code", DEFAULT_REGION)
                .order("stat_date", desc=True)
                .execute()
            )
            break
        except Exception as exc:
            last_error = exc
    if response is None:
        raise SupabaseBackendUnavailable("Failed to load price stats from Supabase.") from last_error

    latest_by_product: dict[str, PriceStats] = {}
    for row in _rows(response):
        product = row.get("products") or {}
        product_id = str(product.get("code") or "").strip().lower()
        if (
            not product_id
            or product_id not in SUPPORTED_PRODUCT_IDS
            or product_id in latest_by_product
        ):
            continue
        latest_by_product[product_id] = _price_stats_from_db_row(row, product_id)

    stats = list(latest_by_product.values())
    if not stats:
        raise SupabaseBackendUnavailable("Supabase price_reference_stats returned no rows.")
    return stats


def _load_products_from_json() -> list[Product]:
    raw = json.loads((DATA_DIR / "product_catalog.json").read_text())
    return [
        Product(**item)
        for item in raw
        if item["product_id"] in SUPPORTED_PRODUCT_IDS
    ]


def _load_price_stats_from_json() -> list[PriceStats]:
    raw = json.loads((DATA_DIR / "price_stats.json").read_text())
    return [
        PriceStats(**item)
        for item in raw
        if item["product_id"] in SUPPORTED_PRODUCT_IDS
    ]


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
        currency=DEFAULT_CURRENCY,
        avg_price=float(row.get("weighted_avg_price_egp") or 0),
        median_price=float(row.get("median_price_egp") or 0),
        min_price=float(row.get("min_price_egp") or 0),
        max_price=float(row.get("max_price_egp") or 0),
        stddev_price=float(row.get("stddev_price_egp") or 0),
        sample_count=int(row.get("sample_count") or 0),
        window_days=_optional_int(row.get("window_days")),
        stat_date=str(row.get("stat_date")) if row.get("stat_date") else None,
        data_source="Talabat + traveler reports",
        mad_price=_optional_float(row.get("mad_price_egp")),
        real_sample_count=_optional_int(row.get("real_sample_count")),
        synthetic_sample_count=_optional_int(row.get("synthetic_sample_count")),
        effective_sample_size=_optional_float(row.get("effective_sample_size")),
        decay_tau_days=_optional_float(row.get("decay_tau_days")),
    )


def _rows(response) -> list[dict[str, Any]]:
    data = getattr(response, "data", None)
    if data is None and isinstance(response, dict):
        data = response.get("data")
    if data is None:
        return []
    return list(data)


def _optional_float(value: Any) -> float | None:
    if value is None:
        return None
    try:
        return float(value)
    except (TypeError, ValueError):
        return None


def _optional_int(value: Any) -> int | None:
    if value is None:
        return None
    try:
        return int(value)
    except (TypeError, ValueError):
        return None
