import logging

import pytest
from fastapi.testclient import TestClient

from app.api import scan
from app.core.auth import get_current_user
from app.core.env import load_env_file
from app.main import app
from app.models.detection import DetectionResponse
from app.models.scan_history import ScanHistoryUploadResponse
from app.services import object_detector
from app.services.object_detector import (
    CLASS_TO_PRODUCT_ID,
    MockObjectDetector,
    ObjectDetectorUnavailable,
    ObjectNotDetected,
    YoloObjectDetector,
    ZeroShotObjectDetector,
)
from app.services.supabase_backend import SupabaseBackendUnavailable
from tests.image_fixtures import jpeg_bytes


client = TestClient(app)
TEST_USER_ID = "11111111-1111-4111-8111-111111111111"
FAKE_JPEG = jpeg_bytes()


class FakeDetector:
    def __init__(self, response: DetectionResponse | None = None, error: Exception | None = None) -> None:
        self.response = response
        self.error = error

    def detect(self, image_bytes: bytes, filename: str, confidence_threshold: float = 0.25) -> DetectionResponse:
        if self.error is not None:
            raise self.error
        assert image_bytes == FAKE_JPEG
        assert filename == "scan.jpg"
        return self.response or DetectionResponse(
            product_id="tomato",
            name_kr="Tomato",
            name_ar="طماطم",
            confidence=0.91,
            detected_price=None,
        )


class FakeScalar:
    def __init__(self, value):
        self.value = value

    def item(self):
        return self.value


class FakeTensor:
    def __init__(self, values):
        self.values = values

    def __getitem__(self, index):
        return FakeScalar(self.values[index])

    def argmax(self):
        return FakeScalar(max(range(len(self.values)), key=self.values.__getitem__))


class FakeBoxes:
    def __init__(self, classes, confidences):
        self.cls = FakeTensor(classes)
        self.conf = FakeTensor(confidences)

    def __len__(self):
        return len(self.conf.values)


class FakeYoloResult:
    def __init__(self, names, boxes):
        self.names = names
        self.boxes = boxes


class FakeYoloModel:
    def __init__(self, names, classes, confidences):
        self.names = names
        self.boxes = FakeBoxes(classes, confidences)

    def __call__(self, image_path, conf, verbose):
        return [FakeYoloResult(self.names, self.boxes)]


def test_detect_object_returns_detection(monkeypatch) -> None:
    monkeypatch.setattr(scan, "get_detector", lambda: FakeDetector())

    response = client.post(
        "/scan/detect-object",
        files={"image": ("scan.jpg", FAKE_JPEG, "image/jpeg")},
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


def test_detect_object_runs_in_worker_thread(monkeypatch) -> None:
    calls = []
    detector = FakeDetector()

    async def fake_run_in_threadpool(function, *args, **kwargs):
        calls.append(function)
        return function(*args, **kwargs)

    monkeypatch.setattr(scan, "get_detector", lambda: detector)
    monkeypatch.setattr(scan, "run_in_threadpool", fake_run_in_threadpool)

    response = client.post(
        "/scan/detect-object",
        files={"image": ("scan.jpg", FAKE_JPEG, "image/jpeg")},
        data={"lat": "30.0444", "lon": "31.2357"},
    )

    assert response.status_code == 200
    assert calls == [detector.detect]


def test_detect_object_allows_web_cors_preflight() -> None:
    response = client.options(
        "/scan/detect-object",
        headers={
            "Origin": "https://web-one-gold-53.vercel.app",
            "Access-Control-Request-Method": "POST",
            "Access-Control-Request-Headers": "content-type",
        },
    )

    assert response.status_code == 200
    assert (
        response.headers["access-control-allow-origin"]
        == "https://web-one-gold-53.vercel.app"
    )
    assert "POST" in response.headers["access-control-allow-methods"]


def test_mock_detector_returns_mock_without_model(monkeypatch) -> None:
    monkeypatch.setenv("TRUEPRICE_DETECTOR_MODE", "mock")
    monkeypatch.setenv("TRUEPRICE_ALLOW_MOCK_DETECTOR", "true")
    object_detector.get_detector.cache_clear()

    try:
        detector = object_detector.get_detector()
        result = detector.detect(image_bytes=b"fake-image", filename="scan.jpg")
    finally:
        object_detector.get_detector.cache_clear()

    assert result.product_id == "tomato"
    assert result.name_kr == "Tomato"
    assert result.confidence == 0.93


def test_force_mock_detector_overrides_yolo_mode(monkeypatch) -> None:
    monkeypatch.setenv("TRUEPRICE_FORCE_MOCK_DETECTOR", "true")
    monkeypatch.setenv("TRUEPRICE_ALLOW_MOCK_DETECTOR", "true")
    monkeypatch.setenv("TRUEPRICE_DETECTOR_MODE", "yolo")
    object_detector.get_detector.cache_clear()

    try:
        detector = object_detector.get_detector()
    finally:
        object_detector.get_detector.cache_clear()

    assert isinstance(detector, MockObjectDetector)


def test_mock_mode_requires_explicit_allowance(monkeypatch, tmp_path) -> None:
    monkeypatch.setenv("TRUEPRICE_DETECTOR_MODE", "mock")
    monkeypatch.delenv("TRUEPRICE_ALLOW_MOCK_DETECTOR", raising=False)
    monkeypatch.setenv("TRUEPRICE_ENV_FILE", str(tmp_path / "missing.env"))
    load_env_file.cache_clear()
    object_detector.get_detector.cache_clear()

    try:
        with pytest.raises(ObjectDetectorUnavailable):
            object_detector.get_detector()
    finally:
        load_env_file.cache_clear()
        object_detector.get_detector.cache_clear()



def test_production_rejects_mock_detector_even_when_allowed(monkeypatch) -> None:
    monkeypatch.setenv("TRUEPRICE_APP_ENV", "production")
    monkeypatch.setenv("TRUEPRICE_DETECTOR_MODE", "mock")
    monkeypatch.setenv("TRUEPRICE_ALLOW_MOCK_DETECTOR", "true")
    object_detector.get_detector.cache_clear()

    try:
        with pytest.raises(ObjectDetectorUnavailable):
            object_detector.get_detector()
    finally:
        object_detector.get_detector.cache_clear()


def test_detector_defaults_to_yolo(monkeypatch, tmp_path) -> None:
    monkeypatch.delenv("TRUEPRICE_DETECTOR_MODE", raising=False)
    monkeypatch.delenv("TRUEPRICE_ENABLE_REAL_DETECTOR", raising=False)
    monkeypatch.delenv("TRUEPRICE_FORCE_MOCK_DETECTOR", raising=False)
    monkeypatch.setenv("TRUEPRICE_ENV_FILE", str(tmp_path / "missing.env"))
    load_env_file.cache_clear()
    object_detector.get_detector.cache_clear()

    try:
        detector = object_detector.get_detector()
    finally:
        load_env_file.cache_clear()
        object_detector.get_detector.cache_clear()

    assert isinstance(detector, YoloObjectDetector)


def test_detect_object_logs_detection_result(monkeypatch, caplog) -> None:
    monkeypatch.setattr(scan, "get_detector", lambda: FakeDetector())
    caplog.set_level(logging.INFO, logger="app.api.scan")

    response = client.post(
        "/scan/detect-object",
        files={"image": ("scan.jpg", FAKE_JPEG, "image/jpeg")},
        data={"lat": "30.0444", "lon": "31.2357"},
    )

    assert response.status_code == 200
    assert "object_detection_result" in caplog.text
    assert "product_id=tomato" in caplog.text
    assert "confidence=0.91" in caplog.text
    assert "filename=scan.jpg" in caplog.text
    assert "lat=30.0444" in caplog.text
    assert "lon=31.2357" in caplog.text
    assert "elapsed_ms=" in caplog.text


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
            image_path=f"{TEST_USER_ID}/capture.jpg",
            image_url="https://example.test/signed/capture.jpg",
            created_at="2026-05-13T00:00:00Z",
        )

    monkeypatch.setattr(scan, "save_scan_history_image", fake_save_scan_history_image)

    response = client.post(
        "/scan/history",
        files={"image": ("capture.jpg", FAKE_JPEG, "image/jpeg")},
    )

    assert response.status_code == 200
    assert response.json()["image_path"] == f"{TEST_USER_ID}/capture.jpg"
    assert response.json()["image_url"] == "https://example.test/signed/capture.jpg"
    assert calls["image_bytes"] == FAKE_JPEG
    assert calls["filename"] == "capture.jpg"
    assert calls["client_user_id"] == TEST_USER_ID


def test_supabase_failure_returns_sanitized_service_error(monkeypatch) -> None:
    def fake_save_scan_history_image(**_kwargs):
        raise SupabaseBackendUnavailable(
            "SUPABASE_SERVICE_ROLE_KEY=secret must never reach clients"
        )

    monkeypatch.setattr(scan, "save_scan_history_image", fake_save_scan_history_image)

    response = client.post(
        "/scan/history",
        files={"image": ("capture.jpg", FAKE_JPEG, "image/jpeg")},
    )

    assert response.status_code == 503
    assert response.json() == {"detail": "Data service is unavailable."}
    assert "secret" not in response.text


def test_scan_history_requires_authentication() -> None:
    override = app.dependency_overrides.pop(get_current_user)
    try:
        response = client.get("/scan/history")
    finally:
        app.dependency_overrides[get_current_user] = override

    assert response.status_code == 401


def test_detect_object_rejects_oversized_image(monkeypatch) -> None:
    monkeypatch.setattr(scan, "MAX_IMAGE_UPLOAD_BYTES", 8)

    response = client.post(
        "/scan/detect-object",
        files={"image": ("large.jpg", FAKE_JPEG, "image/jpeg")},
        data={"lat": "30.0444", "lon": "31.2357"},
    )

    assert response.status_code == 413


def test_detect_object_rejects_spoofed_image_content_type() -> None:
    response = client.post(
        "/scan/detect-object",
        files={"image": ("payload.jpg", b"not-an-image", "image/jpeg")},
        data={"lat": "30.0444", "lon": "31.2357"},
    )

    assert response.status_code == 415


def test_list_scan_history_returns_signed_urls(monkeypatch) -> None:
    calls = {}

    def fake_list_scan_history_images(**kwargs):
        calls.update(kwargs)
        return [
            ScanHistoryUploadResponse(
                id="history-1",
                image_path=f"{TEST_USER_ID}/capture.jpg",
                image_url="https://example.test/signed/capture.jpg",
                created_at="2026-05-13T00:00:00Z",
            )
        ]

    monkeypatch.setattr(scan, "list_scan_history_images", fake_list_scan_history_images)

    response = client.get("/scan/history")

    assert response.status_code == 200
    assert response.json() == [
        {
            "id": "history-1",
            "image_path": f"{TEST_USER_ID}/capture.jpg",
            "image_url": "https://example.test/signed/capture.jpg",
            "created_at": "2026-05-13T00:00:00Z",
        }
    ]
    assert calls == {"client_user_id": TEST_USER_ID, "limit": 50}


def test_list_scan_history_rejects_excessive_limit() -> None:
    response = client.get("/scan/history?limit=101")

    assert response.status_code == 422


def test_update_scan_history_detection(monkeypatch) -> None:
    calls = {}

    def fake_update_scan_history_detection(**kwargs):
        calls.update(kwargs)
        return ScanHistoryUploadResponse(
            id="history-1",
            image_path=f"{TEST_USER_ID}/capture.jpg",
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
    assert calls["client_user_id"] == TEST_USER_ID
    assert calls["payload"].product_id == "tomato"


def test_update_scan_history_price(monkeypatch) -> None:
    calls = {}

    def fake_update_scan_history_price(**kwargs):
        calls.update(kwargs)
        return ScanHistoryUploadResponse(
            id="history-1",
            image_path=f"{TEST_USER_ID}/capture.jpg",
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
    assert calls["client_user_id"] == TEST_USER_ID
    assert calls["payload"].quoted_unit_price_egp == 65


def test_detect_object_returns_404_when_no_object(monkeypatch) -> None:
    monkeypatch.setattr(scan, "get_detector", lambda: FakeDetector(error=ObjectNotDetected("No object detected")))

    response = client.post(
        "/scan/detect-object",
        files={"image": ("scan.jpg", FAKE_JPEG, "image/jpeg")},
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
        files={"image": ("scan.jpg", FAKE_JPEG, "image/jpeg")},
        data={"lat": "30.0444", "lon": "31.2357"},
    )

    assert response.status_code == 503


def test_legacy_fruit_class_is_not_reported_as_tomato() -> None:
    assert CLASS_TO_PRODUCT_ID["fruit"] == "fruit"


def test_yolo_detector_uses_extra_model_when_it_has_best_detection(tmp_path) -> None:
    fruit_model_path = tmp_path / "fruit.pt"
    camel_model_path = tmp_path / "camel.pt"
    fruit_model_path.write_bytes(b"fruit-model")
    camel_model_path.write_bytes(b"camel-model")
    models = {
        fruit_model_path: FakeYoloModel(
            names={0: "tomato"},
            classes=[0],
            confidences=[0.51],
        ),
        camel_model_path: FakeYoloModel(
            names={0: "camel_doll"},
            classes=[0],
            confidences=[0.89],
        ),
    }

    detector = YoloObjectDetector(
        model_path=fruit_model_path,
        extra_model_paths=[camel_model_path],
        model_loader=lambda path: models[path],
        image_loader=lambda image_bytes: "decoded-image",
    )

    result = detector.detect(
        image_bytes=b"fake-image",
        filename="scan.jpg",
    )

    assert result.product_id == "camel_doll"
    assert result.name_kr == "Camel Doll"
    assert result.confidence == 0.89


def test_yolo_detector_loads_image_once_and_reuses_it_for_all_models(tmp_path) -> None:
    first_model_path = tmp_path / "first.pt"
    second_model_path = tmp_path / "second.pt"
    first_model_path.write_bytes(b"first-model")
    second_model_path.write_bytes(b"second-model")
    calls = []

    def fake_image_loader(image_bytes):
        calls.append(("load", image_bytes))
        return "decoded-image"

    first_model = FakeYoloModel(
        names={0: "tomato"},
        classes=[0],
        confidences=[0.51],
    )
    second_model = FakeYoloModel(
        names={0: "mango"},
        classes=[0],
        confidences=[0.77],
    )

    def fake_model_loader(path):
        return {
            first_model_path: first_model,
            second_model_path: second_model,
        }[path]

    detector = YoloObjectDetector(
        model_path=first_model_path,
        extra_model_paths=[second_model_path],
        model_loader=fake_model_loader,
        image_loader=fake_image_loader,
    )

    result = detector.detect(image_bytes=b"fake-image", filename="scan.jpg")

    assert result.product_id == "mango"
    assert calls == [("load", b"fake-image")]


def test_yolo_detector_does_not_load_extra_models_by_default(monkeypatch) -> None:
    monkeypatch.delenv("TRUEPRICE_YOLO_EXTRA_MODEL_PATHS", raising=False)
    monkeypatch.setenv("TRUEPRICE_ENV_FILE", "/tmp/trueprice_missing_test.env")
    load_env_file.cache_clear()

    try:
        detector = YoloObjectDetector()
    finally:
        load_env_file.cache_clear()

    assert detector.extra_model_paths == ()


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


def test_zero_shot_detector_maps_avocado_to_catalog_product() -> None:
    detector = ZeroShotObjectDetector(
        inference_pipeline=lambda image, candidate_labels: [{"label": "avocado", "score": 0.81}],
        image_loader=lambda image_bytes: object(),
    )

    result = detector.detect(image_bytes=b"fake-image", filename="avocado.jpg")

    assert result.product_id == "avocado"
    assert result.name_kr == "Avocado"
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


def test_get_detector_uses_zero_shot_mode(monkeypatch) -> None:
    monkeypatch.setenv("TRUEPRICE_DETECTOR_MODE", "zero_shot")
    monkeypatch.delenv("TRUEPRICE_FORCE_MOCK_DETECTOR", raising=False)
    object_detector.get_detector.cache_clear()

    try:
        detector = object_detector.get_detector()
    finally:
        object_detector.get_detector.cache_clear()

    assert isinstance(detector, ZeroShotObjectDetector)
