from fastapi import APIRouter, File, Form, HTTPException, UploadFile

from app.models.detection import DetectionResponse
from app.services.object_detector import (
    ObjectDetectorUnavailable,
    ObjectNotDetected,
    get_detector,
)


router = APIRouter(prefix="/scan", tags=["scan"])


@router.post("/detect-object", response_model=DetectionResponse)
async def detect_object(
    image: UploadFile = File(...),
    lat: float = Form(...),
    lon: float = Form(...),
) -> DetectionResponse:
    image_bytes = await image.read()
    if not image_bytes:
        raise HTTPException(status_code=400, detail="Uploaded image is empty")

    try:
        return get_detector().detect(
            image_bytes=image_bytes,
            filename=image.filename or "scan.jpg",
        )
    except ObjectNotDetected as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    except ObjectDetectorUnavailable as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc
