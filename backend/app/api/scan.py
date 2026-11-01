import logging

from fastapi import APIRouter, Depends, File, Form, HTTPException, Query, UploadFile
from starlette.concurrency import run_in_threadpool

from app.core.auth import AuthenticatedUser, get_current_user
from app.core.uploads import configured_max_image_upload_bytes, read_validated_image
from app.models.detection import DetectionResponse
from app.models.scan_history import (
    ScanHistoryDetectionUpdate,
    ScanHistoryPriceUpdate,
    ScanHistoryUploadResponse,
)
from app.services.object_detector import (
    ObjectDetectorUnavailable,
    ObjectNotDetected,
    get_detector,
)
from app.services.supabase_backend import (
    list_scan_history_images,
    save_scan_history_image,
    update_scan_history_detection,
    update_scan_history_price,
)


router = APIRouter(prefix="/scan", tags=["scan"])
logger = logging.getLogger(__name__)
MAX_IMAGE_UPLOAD_BYTES = configured_max_image_upload_bytes()


@router.post("/detect-object", response_model=DetectionResponse)
async def detect_object(
    image: UploadFile = File(...),
    lat: float = Form(..., ge=-90, le=90),
    lon: float = Form(..., ge=-180, le=180),
) -> DetectionResponse:
    image_bytes = await read_validated_image(
        image,
        max_bytes=MAX_IMAGE_UPLOAD_BYTES,
    )

    filename = image.filename or "scan.jpg"

    try:
        detector = get_detector()
        result = await run_in_threadpool(
            detector.detect,
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
        raise
    except ObjectDetectorUnavailable as exc:
        logger.warning(
            "object_detection_unavailable filename=%s lat=%s lon=%s reason=%s",
            filename,
            lat,
            lon,
            exc,
        )
        raise


@router.post(
    "/history",
    response_model=ScanHistoryUploadResponse,
    response_model_exclude_none=True,
)
async def save_history(
    image: UploadFile = File(...),
    current_user: AuthenticatedUser = Depends(get_current_user),
) -> ScanHistoryUploadResponse:
    image_bytes = await read_validated_image(
        image,
        max_bytes=MAX_IMAGE_UPLOAD_BYTES,
    )

    return await run_in_threadpool(
        save_scan_history_image,
        image_bytes=image_bytes,
        filename=image.filename or "scan.jpg",
        content_type=image.content_type or "image/jpeg",
        client_user_id=current_user.id,
    )


@router.get(
    "/history",
    response_model=list[ScanHistoryUploadResponse],
    response_model_exclude_none=True,
)
async def list_history(
    limit: int = Query(default=50, ge=1, le=100),
    current_user: AuthenticatedUser = Depends(get_current_user),
) -> list[ScanHistoryUploadResponse]:
    return await run_in_threadpool(
        list_scan_history_images,
        client_user_id=current_user.id,
        limit=limit,
    )


@router.patch(
    "/history/{history_id}/detection",
    response_model=ScanHistoryUploadResponse,
    response_model_exclude_none=True,
)
async def update_history_detection(
    history_id: str,
    payload: ScanHistoryDetectionUpdate,
    current_user: AuthenticatedUser = Depends(get_current_user),
) -> ScanHistoryUploadResponse:
    if not history_id.strip():
        raise HTTPException(status_code=400, detail="history_id is required")

    return await run_in_threadpool(
        update_scan_history_detection,
        history_id=history_id,
        client_user_id=current_user.id,
        payload=payload,
    )


@router.patch(
    "/history/{history_id}/price",
    response_model=ScanHistoryUploadResponse,
    response_model_exclude_none=True,
)
async def update_history_price(
    history_id: str,
    payload: ScanHistoryPriceUpdate,
    current_user: AuthenticatedUser = Depends(get_current_user),
) -> ScanHistoryUploadResponse:
    if not history_id.strip():
        raise HTTPException(status_code=400, detail="history_id is required")

    return await run_in_threadpool(
        update_scan_history_price,
        history_id=history_id,
        client_user_id=current_user.id,
        payload=payload,
    )
