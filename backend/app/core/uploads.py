from io import BytesIO

from fastapi import UploadFile
from PIL import Image, UnidentifiedImageError
from starlette.concurrency import run_in_threadpool

from app.core.env import env_value


DEFAULT_MAX_IMAGE_UPLOAD_BYTES = 8 * 1024 * 1024
MAX_IMAGE_PIXELS = 25_000_000
ALLOWED_IMAGE_MEDIA_TYPES = frozenset(
    {
        "image/jpeg",
        "image/png",
        "image/webp",
    }
)


class ImageUploadError(RuntimeError):
    status_code = 400


class EmptyImageUpload(ImageUploadError):
    status_code = 400


class ImageTooLarge(ImageUploadError):
    status_code = 413


class UnsupportedImageType(ImageUploadError):
    status_code = 415


def configured_max_image_upload_bytes() -> int:
    raw_value = env_value("TRUEPRICE_MAX_IMAGE_UPLOAD_BYTES")
    if not raw_value:
        return DEFAULT_MAX_IMAGE_UPLOAD_BYTES
    try:
        value = int(raw_value)
    except ValueError as exc:
        raise RuntimeError("TRUEPRICE_MAX_IMAGE_UPLOAD_BYTES must be an integer.") from exc
    if value <= 0:
        raise RuntimeError("TRUEPRICE_MAX_IMAGE_UPLOAD_BYTES must be positive.")
    return value


async def read_validated_image(
    upload: UploadFile,
    *,
    max_bytes: int | None = None,
) -> bytes:
    limit = max_bytes or configured_max_image_upload_bytes()
    declared_media_type = (upload.content_type or "").split(";", 1)[0].strip().lower()
    if declared_media_type not in ALLOWED_IMAGE_MEDIA_TYPES:
        raise UnsupportedImageType("Only JPEG, PNG, and WebP images are supported.")

    payload = await upload.read(limit + 1)
    if not payload:
        raise EmptyImageUpload("Uploaded image is empty.")
    if len(payload) > limit:
        raise ImageTooLarge(f"Image exceeds the {limit}-byte upload limit.")

    detected_media_type = _detect_image_media_type(payload)
    if detected_media_type != declared_media_type:
        raise UnsupportedImageType(
            "Uploaded bytes do not match the declared image content type."
        )
    await run_in_threadpool(
        _verify_decodable_image,
        payload,
        declared_media_type,
    )
    return payload


def _detect_image_media_type(payload: bytes) -> str | None:
    if payload.startswith(b"\xff\xd8\xff"):
        return "image/jpeg"
    if payload.startswith(b"\x89PNG\r\n\x1a\n"):
        return "image/png"
    if (
        len(payload) >= 12
        and payload.startswith(b"RIFF")
        and payload[8:12] == b"WEBP"
    ):
        return "image/webp"
    return None


def _verify_decodable_image(payload: bytes, expected_media_type: str) -> None:
    expected_format = {
        "image/jpeg": "JPEG",
        "image/png": "PNG",
        "image/webp": "WEBP",
    }[expected_media_type]
    try:
        with Image.open(BytesIO(payload)) as image:
            if image.width * image.height > MAX_IMAGE_PIXELS:
                raise ImageTooLarge(
                    f"Image dimensions exceed the {MAX_IMAGE_PIXELS}-pixel limit."
                )
            if image.format != expected_format:
                raise UnsupportedImageType(
                    "Decoded image format does not match its content type."
                )
            image.verify()
    except ImageUploadError:
        raise
    except (OSError, SyntaxError, UnidentifiedImageError) as exc:
        raise UnsupportedImageType("Uploaded image is not decodable.") from exc
