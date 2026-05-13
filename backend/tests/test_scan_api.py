import logging

from fastapi.testclient import TestClient

from app.api import scan
from app.main import app
from app.models.detection import DetectionResponse
from app.models.scan_history import ScanHistoryUploadResponse
from app.services import object_detector
from app.services.object_detector import (
    CLASS_TO_PRODUCT_ID,
    ObjectDetectorUnavailable,
    ObjectNotDetected,
    ZeroShotObjectDetector,
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


def test_mock_detector_returns_mock_without_model(monkeypatch) -> None:
    monkeypatch.setenv("TRUEPRICE_DETECTOR_MODE", "mock")
    object_detector.get_detector.cache_clear()

    try:
        detector = object_detector.get_detector()
        result = detector.detect(image_bytes=b"fake-image", filename="scan.jpg")
    finally:
        object_detector.get_detector.cache_clear()

    assert result.product_id == "tomato"
    assert result.name_kr == "Tomato"
    assert result.confidence == 0.93


def test_detect_object_logs_detection_result(monkeypatch, caplog) -> None:
    monkeypatch.setattr(scan, "get_detector", lambda: FakeDetector())
    caplog.set_level(logging.INFO, logger="app.api.scan")

    response = client.post(
        "/scan/detect-object",
        files={"image": ("scan.jpg", b"fake-image", "image/jpeg")},
        data={"lat": "30.0444", "lon": "31.2357"},
    )

    assert response.status_code == 200
    assert "object_detection_result" in caplog.text
    assert "product_id=tomato" in caplog.text
    assert "confidence=0.91" in caplog.text
    assert "filename=scan.jpg" in caplog.text
    assert "lat=30.0444" in caplog.text
    assert "lon=31.2357" in caplog.text


def test_detect_object_rejects_empty_upload(monkeypatch) -> None:
    monkeypatch.setattr(scan, "get_detector", lambda: FakeDetector())

    response = client.post(
        "/scan/detect-object",
        files={"image": ("scan.jpg", b"", "image/jpeg")},
        data={"lat": "30.0444", "lon": "31.2357"},
    )

    assert response.status_code == 400


def test_save_scan_history_uploads_image(monkeypatch) -> None:
    calls = {}

    def fake_save_scan_history_image(**kwargs):
        calls.update(kwargs)
        return ScanHistoryUploadResponse(
            id="history-1",
            image_path="client-1/capture.jpg",
            image_url="https://example.test/signed/capture.jpg",
            created_at="2026-05-13T00:00:00Z",
        )

    monkeypatch.setattr(scan, "save_scan_history_image", fake_save_scan_history_image)

    response = client.post(
        "/scan/history",
        files={"image": ("capture.jpg", b"fake-image", "image/jpeg")},
        data={"client_user_id": "client-1"},
    )

    assert response.status_code == 200
    assert response.json()["image_path"] == "client-1/capture.jpg"
    assert response.json()["image_url"] == "https://example.test/signed/capture.jpg"
    assert calls["image_bytes"] == b"fake-image"
    assert calls["filename"] == "capture.jpg"
    assert calls["client_user_id"] == "client-1"


def test_list_scan_history_returns_signed_urls(monkeypatch) -> None:
    calls = {}

    def fake_list_scan_history_images(**kwargs):
        calls.update(kwargs)
        return [
            ScanHistoryUploadResponse(
                id="history-1",
                image_path="client-1/capture.jpg",
                image_url="https://example.test/signed/capture.jpg",
                created_at="2026-05-13T00:00:00Z",
            )
        ]

    monkeypatch.setattr(scan, "list_scan_history_images", fake_list_scan_history_images)

    response = client.get("/scan/history", params={"client_user_id": "client-1"})

    assert response.status_code == 200
    assert response.json() == [
        {
            "id": "history-1",
            "image_path": "client-1/capture.jpg",
            "image_url": "https://example.test/signed/capture.jpg",
            "created_at": "2026-05-13T00:00:00Z",
        }
    ]
    assert calls == {"client_user_id": "client-1", "limit": 50}


def test_update_scan_history_detection(monkeypatch) -> None:
    calls = {}

    def fake_update_scan_history_detection(**kwargs):
        calls.update(kwargs)
        return ScanHistoryUploadResponse(
            id="history-1",
            image_path="client-1/capture.jpg",
            image_url="https://example.test/signed/capture.jpg",
            created_at="2026-05-13T00:00:00Z",
            detected_product_code="tomato",
            detected_product_name="Tomato",
            detected_product_name_ar="طماطم",
            detection_confidence=0.91,
            detected_price_egp=None,
        )

    monkeypatch.setattr(scan, "update_scan_history_detection", fake_update_scan_history_detection)

    response = client.patch(
        "/scan/history/history-1/detection",
        json={
            "product_id": "tomato",
            "name_kr": "Tomato",
            "name_ar": "طماطم",
            "confidence": 0.91,
            "detected_price": None,
        },
    )

    assert response.status_code == 200
    assert response.json()["detected_product_code"] == "tomato"
    assert calls["history_id"] == "history-1"
    assert calls["payload"].product_id == "tomato"


def test_update_scan_history_price(monkeypatch) -> None:
    calls = {}

    def fake_update_scan_history_price(**kwargs):
        calls.update(kwargs)
        return ScanHistoryUploadResponse(
            id="history-1",
            image_path="client-1/capture.jpg",
            image_url="https://example.test/signed/capture.jpg",
            created_at="2026-05-13T00:00:00Z",
            detected_product_code="tomato",
            detected_product_name="Tomato",
            detected_product_name_ar="طماطم",
            detection_confidence=0.91,
            detected_price_egp=None,
            quoted_total_price_egp=130,
            quoted_quantity=2,
            quoted_unit="kg",
            quoted_unit_price_egp=65,
        )

    monkeypatch.setattr(scan, "update_scan_history_price", fake_update_scan_history_price)

    response = client.patch(
        "/scan/history/history-1/price",
        json={
            "quoted_total_price_egp": 130,
            "quoted_quantity": 2,
            "quoted_unit": "kg",
            "quoted_unit_price_egp": 65,
        },
    )

    assert response.status_code == 200
    assert response.json()["quoted_unit_price_egp"] == 65
    assert calls["history_id"] == "history-1"
    assert calls["payload"].quoted_unit_price_egp == 65


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


def test_zero_shot_detector_maps_specific_fruit_label_to_specific_product() -> None:
    calls = {}

    def fake_pipeline(image, candidate_labels):
        calls["candidate_labels"] = candidate_labels
        return [
            {"label": "apple", "score": 0.74},
            {"label": "orange", "score": 0.42},
        ]

    detector = ZeroShotObjectDetector(
        inference_pipeline=fake_pipeline,
        image_loader=lambda image_bytes: object(),
    )

    result = detector.detect(image_bytes=b"fake-image", filename="apple.jpg")

    assert result.product_id == "apple"
    assert result.name_kr == "Apple"
    assert result.confidence == 0.74
    assert "fruit" not in calls["candidate_labels"]


def test_zero_shot_detector_maps_banana_to_catalog_product() -> None:
    detector = ZeroShotObjectDetector(
        inference_pipeline=lambda image, candidate_labels: [{"label": "banana", "score": 0.81}],
        image_loader=lambda image_bytes: object(),
    )

    result = detector.detect(image_bytes=b"fake-image", filename="banana.jpg")

    assert result.product_id == "banana"
    assert result.name_kr == "Banana"
    assert result.detected_price is None


def test_zero_shot_detector_maps_cherry_tomato_to_catalog_product() -> None:
    detector = ZeroShotObjectDetector(
        inference_pipeline=lambda image, candidate_labels: [{"label": "cherry tomatoes", "score": 0.79}],
        image_loader=lambda image_bytes: object(),
    )

    result = detector.detect(image_bytes=b"fake-image", filename="cherry_tomato.jpg")

    assert result.product_id == "cherry_tomato"
    assert result.name_kr == "Cherry Tomato"
    assert result.detected_price is None


def test_zero_shot_detector_maps_camel_toy_label_to_camel_doll() -> None:
    calls = {}

    def fake_pipeline(image, candidate_labels):
        calls["image"] = image
        calls["candidate_labels"] = candidate_labels
        return [
            {"label": "fruit", "score": 0.41},
            {"label": "stuffed camel toy", "score": 0.82},
        ]

    detector = ZeroShotObjectDetector(
        inference_pipeline=fake_pipeline,
        image_loader=lambda image_bytes: f"image:{len(image_bytes)}",
    )

    result = detector.detect(image_bytes=b"fake-image", filename="camel.jpg")

    assert result.product_id == "camel_doll"
    assert result.name_kr == "Camel Doll"
    assert result.confidence == 0.82
    assert result.detected_price is None
    assert calls["image"] == "image:10"
    assert "stuffed camel toy" in calls["candidate_labels"]


def test_zero_shot_detector_rejects_low_confidence_prediction() -> None:
    detector = ZeroShotObjectDetector(
        inference_pipeline=lambda image, candidate_labels: [{"label": "camel doll", "score": 0.12}],
        image_loader=lambda image_bytes: object(),
    )

    try:
        detector.detect(
            image_bytes=b"fake-image",
            filename="camel.jpg",
            confidence_threshold=0.25,
        )
    except ObjectNotDetected as exc:
        assert "below threshold" in str(exc)
    else:
        raise AssertionError("Expected ObjectNotDetected")


def test_get_detector_supports_zero_shot_mode(monkeypatch) -> None:
    monkeypatch.setenv("TRUEPRICE_DETECTOR_MODE", "zero_shot")
    object_detector.get_detector.cache_clear()

    try:
        detector = object_detector.get_detector()
    finally:
        object_detector.get_detector.cache_clear()

    assert isinstance(detector, ZeroShotObjectDetector)
