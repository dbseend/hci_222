from pydantic import BaseModel, ConfigDict, Field


class CommunityPostCreate(BaseModel):
    model_config = ConfigDict(str_strip_whitespace=True, allow_inf_nan=False)

    product_name: str = Field(min_length=1, max_length=120)
    price: float = Field(gt=0, le=1_000_000)
    product_code: str = Field(
        default="tomato",
        min_length=1,
        max_length=64,
        pattern=r"^[a-z0-9_]+$",
    )
    store_name: str = Field(default="Traveler Report", min_length=1, max_length=120)
    location_name: str = Field(default="Unknown", min_length=1, max_length=120)


class CommunityPostResponse(BaseModel):
    id: str
    product_name: str
    price: float
    store_name: str
    location_name: str
    image_path: str | None = None
    created_at: str
