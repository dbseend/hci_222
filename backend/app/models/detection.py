from pydantic import BaseModel, ConfigDict, Field


class DetectionResponse(BaseModel):
    model_config = ConfigDict(str_strip_whitespace=True, allow_inf_nan=False)

    product_id: str = Field(min_length=1, max_length=64, pattern=r"^[a-z0-9_]+$")
    name_kr: str = Field(min_length=1, max_length=120)
    name_ar: str = Field(min_length=1, max_length=120)
    confidence: float = Field(ge=0, le=1)
    detected_price: float | None = Field(default=None, ge=0, le=1_000_000)
