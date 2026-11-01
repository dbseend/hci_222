import logging
from datetime import datetime, timezone
from functools import lru_cache
from pathlib import Path
from uuid import uuid4

from app.core.env import env_value
from app.models.community import CommunityPostCreate, CommunityPostResponse
from app.models.scan_history import (
    ScanHistoryDetectionUpdate,
    ScanHistoryPriceUpdate,
    ScanHistoryUploadResponse,
)


SCAN_HISTORY_BUCKET = "scan-history-images"
COMMUNITY_IMAGES_BUCKET = "community-images"
SCAN_HISTORY_SIGNED_URL_SECONDS = 60 * 60
logger = logging.getLogger(__name__)


class SupabaseBackendUnavailable(RuntimeError):
    pass


class SupabaseResourceNotFound(RuntimeError):
    pass


class SupabaseUnknownProduct(RuntimeError):
    pass


@lru_cache(maxsize=1)
def get_supabase_client():
    url = env_value("SUPABASE_URL")
    key = env_value("SUPABASE_SERVICE_ROLE_KEY")
    if not url or not key:
        raise SupabaseBackendUnavailable(
            "Set SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY on the backend."
        )

    try:
        from supabase import create_client
    except ImportError as exc:
        raise SupabaseBackendUnavailable(
            "supabase is not installed. Run `pip install -r backend/requirements.txt`."
        ) from exc

    return create_client(url, key)


def save_scan_history_image(
    *,
    image_bytes: bytes,
    filename: str,
    content_type: str,
    client_user_id: str,
) -> ScanHistoryUploadResponse:
    client = get_supabase_client()
    object_path = _object_path(client_user_id, filename)
    _upload_bytes(
        client=client,
        bucket=SCAN_HISTORY_BUCKET,
        path=object_path,
        image_bytes=image_bytes,
        content_type=content_type,
    )

    try:
        response = _execute(
            client.table("scan_histories").insert(
                {"client_user_id": client_user_id, "image_path": object_path}
            ),
            "Failed to save scan history.",
        )
        row = _first_row(response)
    except Exception:
        _delete_object(client=client, bucket=SCAN_HISTORY_BUCKET, path=object_path)
        raise
    return ScanHistoryUploadResponse(
        id=str(row.get("id", "")),
        image_path=str(row.get("image_path", object_path)),
        image_url=_signed_url(
            client,
            SCAN_HISTORY_BUCKET,
            str(row.get("image_path", object_path)),
        ),
        created_at=str(row.get("created_at", "")),
    )


def list_scan_history_images(
    *,
    client_user_id: str,
    limit: int = 50,
) -> list[ScanHistoryUploadResponse]:
    client = get_supabase_client()
    query = (
        client.table("scan_histories")
        .select(
            "id, image_path, created_at, detected_product_code, "
            "detected_product_name, detected_product_name_ar, detection_confidence, "
            "detected_price_egp, quoted_total_price_egp, quoted_quantity, "
            "quoted_unit, quoted_unit_price_egp"
        )
        .eq("client_user_id", client_user_id)
        .order("created_at", desc=True)
        .limit(limit)
    )
    response = _execute(query, "Failed to list scan history.")

    rows = _rows(response)
    signed_urls = _signed_urls(
        client,
        SCAN_HISTORY_BUCKET,
        [str(row.get("image_path", "")) for row in rows],
    )
    items: list[ScanHistoryUploadResponse] = []
    for row in rows:
        image_path = str(row.get("image_path", ""))
        items.append(
            ScanHistoryUploadResponse(
                id=str(row.get("id", "")),
                image_path=image_path,
                image_url=signed_urls.get(image_path),
                created_at=str(row.get("created_at", "")),
                detected_product_code=_optional_str(row.get("detected_product_code")),
                detected_product_name=_optional_str(row.get("detected_product_name")),
                detected_product_name_ar=_optional_str(row.get("detected_product_name_ar")),
                detection_confidence=_optional_float(row.get("detection_confidence")),
                detected_price_egp=_optional_float(row.get("detected_price_egp")),
                quoted_total_price_egp=_optional_float(row.get("quoted_total_price_egp")),
                quoted_quantity=_optional_float(row.get("quoted_quantity")),
                quoted_unit=_optional_str(row.get("quoted_unit")),
                quoted_unit_price_egp=_optional_float(row.get("quoted_unit_price_egp")),
            )
        )
    return items


def update_scan_history_detection(
    *,
    history_id: str,
    client_user_id: str,
    payload: ScanHistoryDetectionUpdate,
) -> ScanHistoryUploadResponse:
    client = get_supabase_client()
    now = _utc_now()
    query = (
        client.table("scan_histories")
        .update(
            {
                "detected_product_code": payload.product_id,
                "detected_product_name": payload.name_kr,
                "detected_product_name_ar": payload.name_ar,
                "detection_confidence": payload.confidence,
                "detected_price_egp": payload.detected_price,
                "detected_at": now,
                "updated_at": now,
            }
        )
        .eq("id", history_id)
        .eq("client_user_id", client_user_id)
    )
    response = _execute(query, "Failed to update scan detection.")
    return _scan_history_response(client, _owned_row(response))


def update_scan_history_price(
    *,
    history_id: str,
    client_user_id: str,
    payload: ScanHistoryPriceUpdate,
) -> ScanHistoryUploadResponse:
    client = get_supabase_client()
    now = _utc_now()
    query = (
        client.table("scan_histories")
        .update(
            {
                "quoted_total_price_egp": payload.quoted_total_price_egp,
                "quoted_quantity": payload.quoted_quantity,
                "quoted_unit": payload.quoted_unit,
                "quoted_unit_price_egp": payload.quoted_unit_price_egp,
                "price_entered_at": now,
                "updated_at": now,
            }
        )
        .eq("id", history_id)
        .eq("client_user_id", client_user_id)
    )
    response = _execute(query, "Failed to update scan price.")
    return _scan_history_response(client, _owned_row(response))


def create_community_post(
    *,
    payload: CommunityPostCreate,
    client_user_id: str,
    image_bytes: bytes | None = None,
    filename: str | None = None,
    content_type: str = "image/jpeg",
) -> None:
    client = get_supabase_client()
    product_id, canonical_product_name = _require_product(
        client=client,
        product_code=payload.product_code,
    )
    image_path = None
    if image_bytes:
        image_path = _object_path(client_user_id, filename or "purchase.jpg")
        _upload_bytes(
            client=client,
            bucket=COMMUNITY_IMAGES_BUCKET,
            path=image_path,
            image_bytes=image_bytes,
            content_type=content_type,
        )

    try:
        _execute(
            client.table("purchases").insert(
                {
                    "client_user_id": client_user_id,
                    "product_id": product_id,
                    "product_name_override": canonical_product_name,
                    "store_name_override": payload.store_name,
                    "location_override": payload.location_name,
                    "unit": "kg",
                    "quantity": 1,
                    "final_price_egp": payload.price,
                    "image_path": image_path,
                }
            ),
            "Failed to create community post.",
        )
    except Exception:
        if image_path:
            _delete_object(
                client=client,
                bucket=COMMUNITY_IMAGES_BUCKET,
                path=image_path,
            )
        raise


def list_community_posts(*, limit: int = 50) -> list[CommunityPostResponse]:
    client = get_supabase_client()
    query = (
        client.table("community_feed_v1")
        .select("id, product_name, store_name, location_name, price_egp, image_path, created_at")
        .order("created_at", desc=True)
        .limit(max(1, min(limit, 100)))
    )
    response = _execute(query, "Failed to list community posts.")

    posts: list[CommunityPostResponse] = []
    for row in _rows(response):
        image_path = row.get("image_path")
        if image_path:
            image_path = _public_url(client, COMMUNITY_IMAGES_BUCKET, str(image_path))
        posts.append(
            CommunityPostResponse(
                id=str(row.get("id", "")),
                product_name=str(row.get("product_name", "")),
                price=float(row.get("price_egp") or 0),
                store_name=str(row.get("store_name", "Traveler Report")),
                location_name=str(row.get("location_name", "Unknown")),
                image_path=image_path,
                created_at=str(row.get("created_at", "")),
            )
        )
    return posts


def _require_product(*, client, product_code: str) -> tuple[str, str]:
    response = _execute(
        client.table("products")
        .select("id,name")
        .eq("code", product_code)
        .limit(1),
        "Failed to validate product code.",
    )
    rows = _rows(response)
    if rows:
        product_id = str(rows[0].get("id") or "")
        product_name = str(rows[0].get("name") or "").strip()
        if product_id and product_name:
            return product_id, product_name
        raise SupabaseBackendUnavailable("Product master data is incomplete.")
    raise SupabaseUnknownProduct(f"Unknown product code: {product_code}")


def _upload_bytes(*, client, bucket: str, path: str, image_bytes: bytes, content_type: str) -> None:
    try:
        client.storage.from_(bucket).upload(
            path=path,
            file=image_bytes,
            file_options={
                "cache-control": "3600",
                "content-type": content_type,
                "upsert": "false",
            },
        )
    except Exception as exc:
        raise SupabaseBackendUnavailable("Failed to upload image.") from exc


def _delete_object(*, client, bucket: str, path: str) -> None:
    try:
        client.storage.from_(bucket).remove([path])
    except Exception as exc:
        logger.error(
            "storage_compensation_failed bucket=%s path=%s reason=%s",
            bucket,
            path,
            exc,
        )


def _object_path(client_user_id: str, filename: str) -> str:
    suffix = _safe_suffix(filename)
    safe_user = "".join(ch if ch.isalnum() or ch in {"-", "_"} else "_" for ch in client_user_id)
    return f"{safe_user}/{uuid4().hex}{suffix}"


def _safe_suffix(filename: str) -> str:
    suffix = Path(filename or "").suffix.lower()
    if suffix in {".jpg", ".jpeg", ".png", ".webp", ".bmp"}:
        return suffix
    return ".jpg"


def _public_url(client, bucket: str, path: str) -> str:
    try:
        return str(client.storage.from_(bucket).get_public_url(path))
    except Exception as exc:
        logger.warning(
            "public_url_generation_failed bucket=%s path=%s reason=%s",
            bucket,
            path,
            exc,
        )
        return path


def _signed_url(client, bucket: str, path: str) -> str | None:
    if not path:
        return None
    try:
        response = client.storage.from_(bucket).create_signed_url(
            path,
            SCAN_HISTORY_SIGNED_URL_SECONDS,
        )
    except Exception as exc:
        logger.warning(
            "signed_url_generation_failed bucket=%s path=%s reason=%s",
            bucket,
            path,
            exc,
        )
        return None

    if isinstance(response, str):
        return response
    if isinstance(response, dict):
        value = (
            response.get("signedURL")
            or response.get("signedUrl")
            or response.get("signed_url")
        )
        return str(value) if value else None
    value = getattr(response, "signed_url", None) or getattr(response, "signedURL", None)
    return str(value) if value else None


def _signed_urls(
    client,
    bucket: str,
    paths: list[str],
) -> dict[str, str]:
    non_empty_paths = [path for path in paths if path]
    if not non_empty_paths:
        return {}
    file_api = client.storage.from_(bucket)
    create_many = getattr(file_api, "create_signed_urls", None)
    if not callable(create_many):
        return {
            path: value
            for path in non_empty_paths
            if (value := _signed_url(client, bucket, path)) is not None
        }
    try:
        responses = create_many(
            non_empty_paths,
            SCAN_HISTORY_SIGNED_URL_SECONDS,
        )
    except Exception as exc:
        logger.warning(
            "batch_signed_url_generation_failed bucket=%s count=%s reason=%s",
            bucket,
            len(non_empty_paths),
            exc,
        )
        return {}

    result: dict[str, str] = {}
    for response in responses or []:
        if not isinstance(response, dict):
            continue
        path = str(response.get("path") or "")
        value = response.get("signedURL") or response.get("signedUrl")
        if path and value:
            result[path] = str(value)
    return result


def _scan_history_response(client, row: dict) -> ScanHistoryUploadResponse:
    image_path = str(row.get("image_path", ""))
    return ScanHistoryUploadResponse(
        id=str(row.get("id", "")),
        image_path=image_path,
        image_url=_signed_url(client, SCAN_HISTORY_BUCKET, image_path),
        created_at=str(row.get("created_at", "")),
        detected_product_code=_optional_str(row.get("detected_product_code")),
        detected_product_name=_optional_str(row.get("detected_product_name")),
        detected_product_name_ar=_optional_str(row.get("detected_product_name_ar")),
        detection_confidence=_optional_float(row.get("detection_confidence")),
        detected_price_egp=_optional_float(row.get("detected_price_egp")),
        quoted_total_price_egp=_optional_float(row.get("quoted_total_price_egp")),
        quoted_quantity=_optional_float(row.get("quoted_quantity")),
        quoted_unit=_optional_str(row.get("quoted_unit")),
        quoted_unit_price_egp=_optional_float(row.get("quoted_unit_price_egp")),
    )


def _optional_str(value) -> str | None:
    if value is None:
        return None
    text = str(value)
    return text if text else None


def _optional_float(value) -> float | None:
    if value is None:
        return None
    return float(value)


def _utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


def _rows(response) -> list[dict]:
    data = getattr(response, "data", None)
    if data is None and isinstance(response, dict):
        data = response.get("data")
    if data is None:
        return []
    return list(data)


def _first_row(response) -> dict:
    rows = _rows(response)
    if not rows:
        raise SupabaseBackendUnavailable("Supabase returned no rows.")
    return rows[0]


def _owned_row(response) -> dict:
    rows = _rows(response)
    if not rows:
        raise SupabaseResourceNotFound("Owned resource was not found.")
    return rows[0]


def _execute(query, error_message: str):
    try:
        return query.execute()
    except (
        SupabaseBackendUnavailable,
        SupabaseResourceNotFound,
        SupabaseUnknownProduct,
    ):
        raise
    except Exception as exc:
        raise SupabaseBackendUnavailable(error_message) from exc
