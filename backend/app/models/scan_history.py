from typing import Literal

from pydantic import BaseModel, ConfigDict, Field

from app.models.detection import DetectionResponse


class ScanHistoryUploadResponse(BaseModel):
    id: str
    image_path: str
    image_url: str | None = None
    created_at: str
    detected_product_code: str | None = None
    detected_product_name: str | None = None
    detected_product_name_ar: str | None = None
    detection_confidence: float | None = None
    detected_price_egp: float | None = None
    quoted_total_price_egp: float | None = None
    quoted_quantity: float | None = None
    quoted_unit: str | None = None
    quoted_unit_price_egp: float | None = None


class ScanHistoryDetectionUpdate(DetectionResponse):
    pass


class ScanHistoryPriceUpdate(BaseModel):
    model_config = ConfigDict(allow_inf_nan=False)

    quoted_total_price_egp: float = Field(gt=0, le=1_000_000)
    quoted_quantity: float = Field(gt=0, le=10_000)
    quoted_unit: Literal["kg", "pcs"] = "kg"
    quoted_unit_price_egp: float = Field(gt=0, le=1_000_000)
