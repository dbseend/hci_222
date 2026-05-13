from pydantic import BaseModel


class ScanHistoryUploadResponse(BaseModel):
    id: str
    image_path: str
    created_at: str
