import tempfile
from functools import lru_cache
from pathlib import Path
from uuid import uuid4

from app.core.env import env_value
from app.models.community import CommunityPostCreate, CommunityPostResponse
from app.models.scan_history import ScanHistoryUploadResponse


SCAN_HISTORY_BUCKET = "scan-history-images"
COMMUNITY_IMAGES_BUCKET = "community-images"


class SupabaseBackendUnavailable(RuntimeError):
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

    response = (
        client.table("scan_histories")
        .insert({"client_user_id": client_user_id, "image_path": object_path})
        .execute()
    )
    row = _first_row(response)
    return ScanHistoryUploadResponse(
        id=str(row.get("id", "")),
        image_path=str(row.get("image_path", object_path)),
        created_at=str(row.get("created_at", "")),
    )


def create_community_post(
    *,
    payload: CommunityPostCreate,
    image_bytes: bytes | None = None,
    filename: str | None = None,
    content_type: str = "image/jpeg",
) -> None:
    client = get_supabase_client()
    product_id = _ensure_product_id(
        client=client,
        product_code=payload.product_code,
        product_name=payload.product_name,
    )
    image_path = None
    if image_bytes:
        image_path = _object_path(payload.client_user_id, filename or "purchase.jpg")
        _upload_bytes(
            client=client,
            bucket=COMMUNITY_IMAGES_BUCKET,
            path=image_path,
            image_bytes=image_bytes,
            content_type=content_type,
        )

    client.table("purchases").insert(
        {
            "client_user_id": payload.client_user_id,
            "product_id": product_id,
            "product_name_override": payload.product_name,
            "store_name_override": payload.store_name,
            "location_override": payload.location_name,
            "unit": "kg",
            "quantity": 1,
            "final_price_egp": payload.price,
            "image_path": image_path,
        }
    ).execute()


def list_community_posts() -> list[CommunityPostResponse]:
    client = get_supabase_client()
    response = (
        client.table("community_feed_v1")
        .select("id, product_name, store_name, location_name, price_egp, image_path, created_at")
        .order("created_at", desc=True)
        .execute()
    )

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


def _ensure_product_id(*, client, product_code: str, product_name: str) -> str:
    response = client.table("products").select("id").eq("code", product_code).limit(1).execute()
    rows = _rows(response)
    if rows:
        return str(rows[0]["id"])

    inserted = (
        client.table("products")
        .insert({"code": product_code, "name": product_name, "default_unit": "kg"})
        .execute()
    )
    return str(_first_row(inserted)["id"])


def _upload_bytes(*, client, bucket: str, path: str, image_bytes: bytes, content_type: str) -> None:
    suffix = Path(path).suffix or ".jpg"
    with tempfile.NamedTemporaryFile(suffix=suffix, delete=True) as tmp:
        tmp.write(image_bytes)
        tmp.flush()
        with open(tmp.name, "rb") as file:
            client.storage.from_(bucket).upload(
                path=path,
                file=file,
                file_options={
                    "cache-control": "3600",
                    "content-type": content_type,
                    "upsert": "false",
                },
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
    except Exception:
        return path


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
