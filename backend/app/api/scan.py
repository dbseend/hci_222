import logging

from fastapi import APIRouter, File, Form, HTTPException, UploadFile

from app.models.detection import DetectionResponse
from app.models.scan_history import ScanHistoryUploadResponse
from app.services.object_detector import (
    ObjectDetectorUnavailable,
    ObjectNotDetected,
    get_detector,
)
from app.services.supabase_backend import (
    SupabaseBackendUnavailable,
    list_scan_history_images,
    save_scan_history_image,
)


router = APIRouter(prefix="/scan", tags=["scan"])
logger = logging.getLogger(__name__)


@router.post("/detect-object", response_model=DetectionResponse)
async def detect_object(
    image: UploadFile = File(...),
    lat: float = Form(...),
    lon: float = Form(...),
) -> DetectionResponse:
    image_bytes = await image.read()
    if not image_bytes:
        raise HTTPException(status_code=400, detail="Uploaded image is empty")

    filename = image.filename or "scan.jpg"

    try:
        result = get_detector().detect(
            image_bytes=image_bytes,
            filename=filename,
        )
        logger.info(
            "object_detection_result product_id=%s name_kr=%s confidence=%s filename=%s lat=%s lon=%s",
            result.product_id,
            result.name_kr,
            result.confidence,
            filename,
            lat,
            lon,
        )
        return result
    except ObjectNotDetected as exc:
        logger.warning(
            "object_detection_not_found filename=%s lat=%s lon=%s reason=%s",
            filename,
            lat,
            lon,
            exc,
        )
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    except ObjectDetectorUnavailable as exc:
        logger.warning(
            "object_detection_unavailable filename=%s lat=%s lon=%s reason=%s",
            filename,
            lat,
            lon,
            exc,
        )
        raise HTTPException(status_code=503, detail=str(exc)) from exc


@router.post("/history", response_model=ScanHistoryUploadResponse)
async def save_history(
    image: UploadFile = File(...),
    client_user_id: str = Form(...),
) -> ScanHistoryUploadResponse:
    image_bytes = await image.read()
    if not image_bytes:
        raise HTTPException(status_code=400, detail="Uploaded image is empty")

    try:
        return save_scan_history_image(
            image_bytes=image_bytes,
            filename=image.filename or "scan.jpg",
            content_type=image.content_type or "image/jpeg",
            client_user_id=client_user_id,
        )
    except SupabaseBackendUnavailable as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc


@router.get("/history", response_model=list[ScanHistoryUploadResponse])
async def list_history(
    client_user_id: str,
    limit: int = 50,
) -> list[ScanHistoryUploadResponse]:
    if not client_user_id.strip():
        raise HTTPException(status_code=400, detail="client_user_id is required")

    try:
        return list_scan_history_images(
            client_user_id=client_user_id,
            limit=max(1, min(limit, 100)),
        )
    except SupabaseBackendUnavailable as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc
