from pydantic import BaseModel


class ScanHistoryUploadResponse(BaseModel):
    id: str
    image_path: str
    image_url: str | None = None
    created_at: str
