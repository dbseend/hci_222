from pydantic import BaseModel, Field


class CommunityPostCreate(BaseModel):
    product_name: str = Field(min_length=1)
    price: float = Field(gt=0)
    product_code: str = "p001"
    store_name: str = "Traveler Report"
    location_name: str = "Unknown"
    client_user_id: str = Field(min_length=1)


class CommunityPostResponse(BaseModel):
    id: str
    product_name: str
    price: float
    store_name: str
    location_name: str
    image_path: str | None = None
    created_at: str
