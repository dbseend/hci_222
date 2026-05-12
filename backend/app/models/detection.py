from pydantic import BaseModel, Field


class DetectionResponse(BaseModel):
    product_id: str
    name_kr: str
    name_ar: str
    confidence: float = Field(ge=0, le=1)
    detected_price: float | None = None
