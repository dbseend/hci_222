from fastapi.testclient import TestClient

from app.api import scan
from app.main import app
from app.models.detection import DetectionResponse
from app.services.object_detector import (
    CLASS_TO_PRODUCT_ID,
    ObjectDetectorUnavailable,
    ObjectNotDetected,
)


client = TestClient(app)


class FakeDetector:
    def __init__(self, response: DetectionResponse | None = None, error: Exception | None = None) -> None:
        self.response = response
        self.error = error

    def detect(self, image_bytes: bytes, filename: str, confidence_threshold: float = 0.25) -> DetectionResponse:
        if self.error is not None:
            raise self.error
        assert image_bytes == b"fake-image"
        assert filename == "scan.jpg"
        return self.response or DetectionResponse(
            product_id="tomato",
            name_kr="Tomato",
            name_ar="طماطم",
            confidence=0.91,
            detected_price=None,
        )


def test_detect_object_returns_detection(monkeypatch) -> None:
    monkeypatch.setattr(scan, "get_detector", lambda: FakeDetector())

    response = client.post(
        "/scan/detect-object",
        files={"image": ("scan.jpg", b"fake-image", "image/jpeg")},
        data={"lat": "30.0444", "lon": "31.2357"},
    )

    assert response.status_code == 200
    assert response.json() == {
        "product_id": "tomato",
        "name_kr": "Tomato",
        "name_ar": "طماطم",
        "confidence": 0.91,
        "detected_price": None,
    }


def test_detect_object_rejects_empty_upload(monkeypatch) -> None:
    monkeypatch.setattr(scan, "get_detector", lambda: FakeDetector())

    response = client.post(
        "/scan/detect-object",
        files={"image": ("scan.jpg", b"", "image/jpeg")},
        data={"lat": "30.0444", "lon": "31.2357"},
    )

    assert response.status_code == 400


def test_detect_object_returns_404_when_no_object(monkeypatch) -> None:
    monkeypatch.setattr(scan, "get_detector", lambda: FakeDetector(error=ObjectNotDetected("No object detected")))

    response = client.post(
        "/scan/detect-object",
        files={"image": ("scan.jpg", b"fake-image", "image/jpeg")},
        data={"lat": "30.0444", "lon": "31.2357"},
    )

    assert response.status_code == 404


def test_detect_object_returns_503_when_detector_unavailable(monkeypatch) -> None:
    monkeypatch.setattr(
        scan,
        "get_detector",
        lambda: FakeDetector(error=ObjectDetectorUnavailable("YOLO model file not found")),
    )

    response = client.post(
        "/scan/detect-object",
        files={"image": ("scan.jpg", b"fake-image", "image/jpeg")},
        data={"lat": "30.0444", "lon": "31.2357"},
    )

    assert response.status_code == 503


def test_legacy_fruit_class_is_not_reported_as_tomato() -> None:
    assert CLASS_TO_PRODUCT_ID["fruit"] == "fruit"
