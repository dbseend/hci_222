import json

from fastapi import APIRouter, File, Form, HTTPException, UploadFile

from app.models.community import CommunityPostCreate, CommunityPostResponse
from app.services.supabase_backend import (
    SupabaseBackendUnavailable,
    create_community_post,
    list_community_posts,
)


router = APIRouter(prefix="/api/v1/community", tags=["community"])


@router.get("/feed", response_model=list[CommunityPostResponse])
def read_feed() -> list[CommunityPostResponse]:
    try:
        return list_community_posts()
    except SupabaseBackendUnavailable as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc


@router.post("/posts", status_code=201)
async def create_post(
    payload: str = Form(...),
    image: UploadFile | None = File(default=None),
) -> dict[str, str]:
    try:
        parsed = CommunityPostCreate.model_validate(json.loads(payload))
    except Exception as exc:
        raise HTTPException(status_code=400, detail="Invalid community post payload") from exc

    image_bytes = await image.read() if image is not None else None
    try:
        create_community_post(
            payload=parsed,
            image_bytes=image_bytes,
            filename=image.filename if image is not None else None,
            content_type=(image.content_type or "image/jpeg") if image is not None else "image/jpeg",
        )
    except SupabaseBackendUnavailable as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc

    return {"status": "ok"}
