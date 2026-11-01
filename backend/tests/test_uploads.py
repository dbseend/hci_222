import pytest
from fastapi import UploadFile

from app.core.uploads import (
    ImageTooLarge,
    UnsupportedImageType,
    read_validated_image,
)
from tests.image_fixtures import jpeg_bytes


@pytest.mark.anyio
async def test_read_validated_image_rejects_payload_over_limit() -> None:
    upload = UploadFile(
        filename="photo.jpg",
        file=_bytes_file(b"\xff\xd8\xff\xe0too-large"),
        headers={"content-type": "image/jpeg"},
    )

    with pytest.raises(ImageTooLarge):
        await read_validated_image(upload, max_bytes=8)


@pytest.mark.anyio
async def test_read_validated_image_rejects_non_image_content_type() -> None:
    upload = UploadFile(
        filename="payload.txt",
        file=_bytes_file(b"not-an-image"),
        headers={"content-type": "text/plain"},
    )

    with pytest.raises(UnsupportedImageType):
        await read_validated_image(upload)


@pytest.mark.anyio
async def test_read_validated_image_rejects_spoofed_image_content_type() -> None:
    upload = UploadFile(
        filename="payload.jpg",
        file=_bytes_file(b"not-an-image"),
        headers={"content-type": "image/jpeg"},
    )

    with pytest.raises(UnsupportedImageType):
        await read_validated_image(upload)


@pytest.mark.anyio
async def test_read_validated_image_accepts_matching_jpeg_signature() -> None:
    payload = jpeg_bytes()
    upload = UploadFile(
        filename="photo.jpg",
        file=_bytes_file(payload),
        headers={"content-type": "image/jpeg"},
    )

    assert await read_validated_image(upload) == payload


@pytest.mark.anyio
async def test_read_validated_image_rejects_truncated_jpeg() -> None:
    upload = UploadFile(
        filename="broken.jpg",
        file=_bytes_file(b"\xff\xd8\xff\xe0not-a-complete-image"),
        headers={"content-type": "image/jpeg"},
    )

    with pytest.raises(UnsupportedImageType):
        await read_validated_image(upload)


def _bytes_file(payload: bytes):
    from io import BytesIO

    return BytesIO(payload)
