import importlib.util
from pathlib import Path

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
        {"TRUEPRICE_API_BASE_URL": "https://hci-222.onrender.com"},
    )

    assert "https://hci-222.onrender.com" in rendered
    assert "192.168.0.24" not in rendered


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
