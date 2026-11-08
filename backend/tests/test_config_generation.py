import importlib.util
from pathlib import Path

import pytest
from fastapi.testclient import TestClient

from app import main as app_main
from app.core.env import load_env_file


ROOT = Path(__file__).resolve().parents[2]


def _load_generate_flutter_defines_module():
    module_path = ROOT / "scripts" / "generate_flutter_defines.py"
    spec = importlib.util.spec_from_file_location(
        "generate_flutter_defines",
        module_path,
    )
    assert spec is not None
    assert spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def test_render_dart_env_uses_configured_api_base_url() -> None:
    module = _load_generate_flutter_defines_module()

    rendered = module._render_dart_env(
        {
            "TRUEPRICE_API_BASE_URL": "api-base-from-env",
            "TRUEPRICE_EXCHANGE_RATE_API_URL": "exchange-rate-url-from-env",
        },
    )

    assert "api-base-from-env" in rendered
    assert "exchange-rate-url-from-env" in rendered
    assert "String.fromEnvironment(" in rendered
    assert "'TRUEPRICE_API_BASE_URL'" in rendered
    assert "defaultValue: 'api-base-from-env'" in rendered
    assert "192.168.0.24" not in rendered


def test_render_dart_env_includes_only_public_supabase_credentials() -> None:
    module = _load_generate_flutter_defines_module()

    rendered = module._render_dart_env(
        {
            "TRUEPRICE_API_BASE_URL": "https://api.example.test",
            "TRUEPRICE_EXCHANGE_RATE_API_URL": "https://rates.example.test",
            "SUPABASE_URL": "https://project.supabase.co",
            "SUPABASE_PUBLISHABLE_KEY": "public-client-key",
            "SUPABASE_SERVICE_ROLE_KEY": "must-never-reach-flutter",
            "TRUEPRICE_ENABLE_DEMO_FALLBACKS": "true",
            "TRUEPRICE_DEFAULT_REGION": "alexandria",
        },
    )

    assert "https://project.supabase.co" in rendered
    assert "public-client-key" in rendered
    assert "must-never-reach-flutter" not in rendered
    assert "SUPABASE_SERVICE_ROLE_KEY" not in rendered
    assert "enableDemoFallbacks" in rendered
    assert "defaultValue: true" in rendered
    assert "defaultRegion" in rendered
    assert "defaultValue: 'alexandria'" in rendered


def test_render_ios_maps_secrets_sets_gms_api_key() -> None:
    module = _load_generate_flutter_defines_module()

    rendered = module._render_ios_maps_secrets("ios-key-from-env")

    assert "GMS_API_KEY=ios-key-from-env\n" in rendered
    assert "Do not edit" in rendered


def test_detector_warm_up_disabled_by_default(monkeypatch, tmp_path) -> None:
    monkeypatch.delenv("TRUEPRICE_WARM_UP_DETECTOR", raising=False)
    monkeypatch.setenv("TRUEPRICE_ENV_FILE", str(tmp_path / "missing.env"))
    load_env_file.cache_clear()

    try:
        assert app_main._should_warm_up_detector() is False
    finally:
        load_env_file.cache_clear()


def test_detector_warm_up_can_be_enabled(monkeypatch, tmp_path) -> None:
    env_file = tmp_path / ".env"
    env_file.write_text("TRUEPRICE_WARM_UP_DETECTOR=true\n", encoding="utf-8")
    monkeypatch.delenv("TRUEPRICE_WARM_UP_DETECTOR", raising=False)
    monkeypatch.setenv("TRUEPRICE_ENV_FILE", str(env_file))
    load_env_file.cache_clear()

    try:
        assert app_main._should_warm_up_detector() is True
    finally:
        load_env_file.cache_clear()


def test_production_detector_warm_up_failure_aborts_startup(monkeypatch) -> None:
    monkeypatch.setenv("TRUEPRICE_APP_ENV", "production")
    monkeypatch.setattr(app_main, "_should_warm_up_detector", lambda: True)
    monkeypatch.setattr(
        app_main,
        "warm_up_detector",
        lambda: (_ for _ in ()).throw(
            app_main.ObjectDetectorUnavailable("model missing")
        ),
    )

    with pytest.raises(app_main.ObjectDetectorUnavailable):
        with TestClient(app_main.app):
            pass


def test_production_requires_explicit_cors_origins(monkeypatch, tmp_path) -> None:
    monkeypatch.setenv("TRUEPRICE_APP_ENV", "production")
    monkeypatch.delenv("TRUEPRICE_CORS_ALLOW_ORIGINS", raising=False)
    monkeypatch.setenv("TRUEPRICE_ENV_FILE", str(tmp_path / "missing.env"))
    load_env_file.cache_clear()

    try:
        with pytest.raises(RuntimeError, match="CORS"):
            app_main._cors_allow_origins()
    finally:
        load_env_file.cache_clear()
