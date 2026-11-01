from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]


def test_docker_defaults_fail_closed_without_real_detector() -> None:
    dockerfile = (ROOT / "Dockerfile").read_text(encoding="utf-8")

    assert "TRUEPRICE_APP_ENV=production" in dockerfile
    assert "TRUEPRICE_DETECTOR_MODE=yolo" in dockerfile
    assert "TRUEPRICE_ALLOW_MOCK_DETECTOR=false" in dockerfile
    assert "TRUEPRICE_FORCE_MOCK_DETECTOR=false" in dockerfile
    assert "requirements-ml.txt" in dockerfile


def test_runtime_dependencies_are_version_pinned() -> None:
    requirements = (ROOT / "backend" / "requirements.txt").read_text(
        encoding="utf-8"
    )
    runtime_lines = [
        line.strip()
        for line in requirements.splitlines()
        if line.strip() and not line.startswith("#")
    ]

    assert runtime_lines
    assert all("==" in line for line in runtime_lines)
    assert "pytest" not in requirements
