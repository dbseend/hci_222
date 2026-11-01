import json

from fastapi import APIRouter, Depends, File, Form, HTTPException, Query, UploadFile
from pydantic import ValidationError
from starlette.concurrency import run_in_threadpool

from app.core.auth import AuthenticatedUser, get_current_user
from app.core.uploads import configured_max_image_upload_bytes, read_validated_image
from app.models.community import CommunityPostCreate, CommunityPostResponse
from app.services.supabase_backend import create_community_post, list_community_posts


router = APIRouter(prefix="/api/v1/community", tags=["community"])
MAX_IMAGE_UPLOAD_BYTES = configured_max_image_upload_bytes()


@router.get("/feed", response_model=list[CommunityPostResponse])
def read_feed(limit: int = Query(default=50, ge=1, le=100)) -> list[CommunityPostResponse]:
    return list_community_posts(limit=limit)


@router.post("/posts", status_code=201)
async def create_post(
    payload: str = Form(...),
    image: UploadFile | None = File(default=None),
    current_user: AuthenticatedUser = Depends(get_current_user),
) -> dict[str, str]:
    try:
        decoded = json.loads(payload)
    except json.JSONDecodeError as exc:
        raise HTTPException(status_code=400, detail="Invalid community post payload") from exc
    try:
        parsed = CommunityPostCreate.model_validate(decoded)
    except ValidationError as exc:
        raise HTTPException(status_code=422, detail="Invalid community post fields") from exc

    image_bytes = (
        await read_validated_image(image, max_bytes=MAX_IMAGE_UPLOAD_BYTES)
        if image is not None
        else None
    )
    await run_in_threadpool(
        create_community_post,
        payload=parsed,
        client_user_id=current_user.id,
        image_bytes=image_bytes,
        filename=image.filename if image is not None else None,
        content_type=(image.content_type or "image/jpeg") if image is not None else "image/jpeg",
    )

    return {"status": "ok"}
