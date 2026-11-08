import importlib.util
from pathlib import Path

from fastapi.testclient import TestClient

from app.api import scan
from app.main import app
from app.services.object_detector import MockObjectDetector, ObjectNotDetected
from tests.image_fixtures import jpeg_bytes


ROOT = Path(__file__).resolve().parents[2]


def _load_preflight():
    spec = importlib.util.spec_from_file_location(
        "demo_preflight", ROOT / "scripts" / "demo_preflight.py"
    )
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


preflight = _load_preflight()

GOOD_ENV = {
    "TRUEPRICE_API_BASE_URL": "http://192.168.0.10:8000",
    "TRUEPRICE_EXCHANGE_RATE_API_URL": "https://rates.example/v1/latest",
    "GOOGLE_MAPS_WEB_API_KEY": "maps-secret",
    "SUPABASE_URL": "https://abc.supabase.co",
    "SUPABASE_PUBLISHABLE_KEY": "pub-secret",
    "SUPABASE_SERVICE_ROLE_KEY": "service-secret",
    "TRUEPRICE_DETECTOR_MODE": "yolo",
    "TRUEPRICE_ALLOW_MOCK_DETECTOR": "false",
}


def test_env_keys_pass_without_leaking_values() -> None:
    result = preflight.check_env_keys(GOOD_ENV.get)

    assert result.ok
    assert "secret" not in result.detail


def test_env_keys_fail_on_missing_and_placeholder_values() -> None:
    env = {**GOOD_ENV, "SUPABASE_URL": "https://YOUR_PROJECT_REF.supabase.co"}
    env.pop("GOOGLE_MAPS_WEB_API_KEY")

    result = preflight.check_env_keys(env.get)

    assert not result.ok
    assert "SUPABASE_URL" in result.detail
    assert "GOOGLE_MAPS_WEB_API_KEY" in result.detail
    assert "supabase.co" not in result.detail


def test_detector_flags_require_yolo_and_no_mock() -> None:
    assert preflight.check_detector_flags(GOOD_ENV.get).ok
    mock_env = {**GOOD_ENV, "TRUEPRICE_DETECTOR_MODE": "mock", "TRUEPRICE_ALLOW_MOCK_DETECTOR": "true"}
    result = preflight.check_detector_flags(mock_env.get)
    assert not result.ok
    assert "TRUEPRICE_DETECTOR_MODE" in result.detail


def test_model_classes_must_match_demo_set() -> None:
    names = {0: "apple", 1: "banana", 2: "grape", 3: "mango", 4: "strawberry", 5: "camel_doll"}
    assert preflight.check_model_classes(names).ok
    assert not preflight.check_model_classes({0: "apple", 1: "banana"}).ok


def test_api_base_url_must_point_at_lan_ip() -> None:
    assert preflight.check_api_base_url("http://192.168.0.10:8000", "192.168.0.10").ok
    assert not preflight.check_api_base_url("http://192.168.0.99:8000", "192.168.0.10").ok
    assert not preflight.check_api_base_url("http://192.168.0.10:8000", None).ok


def test_exchange_rate_checks_status() -> None:
    class Response:
        def __init__(self, code):
            self.status_code = code

    assert preflight.check_exchange_rate("https://x", lambda url, timeout: Response(200)).ok
    assert not preflight.check_exchange_rate("https://x", lambda url, timeout: Response(500)).ok

    def boom(url, timeout):
        raise OSError("offline")

    result = preflight.check_exchange_rate("https://x", boom)
    assert not result.ok
    assert "offline" in result.detail


def test_exchange_rate_is_optional_when_unset_or_placeholder() -> None:
    def never_called(url, timeout):
        raise AssertionError("should not call the network")

    for url in (None, "", "https://YOUR_EXCHANGE_RATE_HOST/v1/latest"):
        result = preflight.check_exchange_rate(url, never_called)
        assert result.ok
        assert "optional" in result.detail
    env = {k: v for k, v in GOOD_ENV.items() if k != "TRUEPRICE_EXCHANGE_RATE_API_URL"}
    assert preflight.check_env_keys(env.get).ok


def test_scan_check_with_mock_detector(monkeypatch) -> None:
    monkeypatch.setattr(scan, "get_detector", lambda: MockObjectDetector())

    result = preflight.check_scan(TestClient(app), jpeg_bytes(), require_detection=False)

    assert result.ok


def test_scan_check_fails_when_detection_required_but_missing(monkeypatch) -> None:
    class NothingDetector:
        def detect(self, **_kwargs):
            raise ObjectNotDetected("No object detected")

    monkeypatch.setattr(scan, "get_detector", lambda: NothingDetector())
    client = TestClient(app)

    assert not preflight.check_scan(client, jpeg_bytes(), require_detection=True).ok
    assert preflight.check_scan(client, jpeg_bytes(), require_detection=False).ok


def test_exit_code_is_one_when_any_check_fails() -> None:
    ok = preflight.Result("a", True, "")
    bad = preflight.Result("b", False, "fix it")

    assert preflight.report([ok]) == 0
    assert preflight.report([ok, bad]) == 1
