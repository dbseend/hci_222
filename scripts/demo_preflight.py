"""Pre-demo checklist for the local backend + iPhone setup.

Prints PASS/FAIL per item with a fix, never prints .env values, exits 1 on any FAIL.

    .venv/bin/python scripts/demo_preflight.py [--image fruit.jpg] [--server http://127.0.0.1:8000]
"""

import argparse
import subprocess
import sys
from io import BytesIO
from pathlib import Path
from typing import Callable, NamedTuple
from urllib.parse import urlparse

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "backend"))

REQUIRED_KEYS = (
    "TRUEPRICE_API_BASE_URL",
    "GOOGLE_MAPS_WEB_API_KEY",
    "SUPABASE_URL",
    "SUPABASE_PUBLISHABLE_KEY",
    "SUPABASE_SERVICE_ROLE_KEY",
)
DEMO_CLASSES = {"apple", "banana", "grape", "mango", "strawberry", "camel_doll"}
SCAN_PATH = "/scan/detect-object"
CAIRO = {"lat": "30.0444", "lon": "31.2357"}

Getter = Callable[[str], str | None]


class Result(NamedTuple):
    name: str
    ok: bool
    detail: str


def check_env_keys(get: Getter) -> Result:
    missing = [key for key in REQUIRED_KEYS if not get(key) or "YOUR_" in (get(key) or "")]
    if missing:
        return Result(".env keys", False, f"Set real values in .env for: {', '.join(missing)}")
    return Result(".env keys", True, f"{len(REQUIRED_KEYS)} required keys set")


def check_detector_flags(get: Getter) -> Result:
    problems = []
    if (get("TRUEPRICE_DETECTOR_MODE") or "yolo").strip().lower() != "yolo":
        problems.append("TRUEPRICE_DETECTOR_MODE=yolo")
    if (get("TRUEPRICE_ALLOW_MOCK_DETECTOR") or "false").strip().lower() != "false":
        problems.append("TRUEPRICE_ALLOW_MOCK_DETECTOR=false")
    if problems:
        return Result("detector flags", False, f"Set in .env: {', '.join(problems)}")
    return Result("detector flags", True, "yolo mode, mock disabled")


def check_model_classes(names) -> Result:
    found = set(names.values() if isinstance(names, dict) else names)
    if found != DEMO_CLASSES:
        return Result(
            "YOLO classes",
            False,
            f"Expected {sorted(DEMO_CLASSES)}, got {sorted(found)}; check TRUEPRICE_YOLO_MODEL_PATH",
        )
    return Result("YOLO classes", True, ", ".join(sorted(found)))


def check_api_base_url(api_base_url: str | None, lan_ip: str | None) -> Result:
    if not lan_ip:
        return Result("LAN IP", False, "No LAN IP; connect this Mac to Wi-Fi or a hotspot")
    host = urlparse(api_base_url or "").hostname
    if host != lan_ip:
        return Result(
            "LAN IP",
            False,
            f"API_BASE_URL host {host} != LAN IP {lan_ip}; run scripts/run_local_server.sh "
            "and rebuild the Flutter app",
        )
    return Result("LAN IP", True, f"API_BASE_URL matches {lan_ip}")


def check_exchange_rate(url: str | None, http_get) -> Result:
    if not url or "YOUR_" in url:
        return Result("exchange rate API", True, "SKIP (optional; TRUEPRICE_EXCHANGE_RATE_API_URL not set)")
    try:
        status = http_get(url, timeout=10).status_code
    except Exception as exc:  # report any network failure as FAIL, not crash
        return Result("exchange rate API", False, f"Request failed: {exc}")
    if status != 200:
        return Result("exchange rate API", False, f"HTTP {status}; check TRUEPRICE_EXCHANGE_RATE_API_URL")
    return Result("exchange rate API", True, "HTTP 200")


def check_supabase(client_factory) -> Result:
    try:
        client_factory().table("price_reference_stats").select("product_id").limit(1).execute()
    except Exception as exc:
        return Result("Supabase", False, f"Read failed ({type(exc).__name__}); check SUPABASE_URL/keys and network")
    return Result("Supabase", True, "read price_reference_stats")


def check_model(loader) -> Result:
    try:
        model = loader()
    except Exception as exc:
        return Result("YOLO classes", False, f"Model load failed: {exc}")
    return check_model_classes(model.names)


def check_scan(client, image_bytes: bytes, require_detection: bool) -> Result:
    try:
        response = client.post(
            SCAN_PATH,
            files={"image": ("scan.jpg", image_bytes, "image/jpeg")},
            data=CAIRO,
        )
    except Exception as exc:
        return Result("/scan", False, f"Request failed: {exc}; is the server running?")
    if response.status_code == 200:
        return Result("/scan", True, f"detected {response.json().get('product_id')}")
    if response.status_code == 404 and not require_detection:
        return Result("/scan", True, "pipeline ran (nothing detected; pass --image for a real fruit)")
    return Result("/scan", False, f"HTTP {response.status_code}: {response.text[:200]}")


def report(results: list[Result]) -> int:
    for result in results:
        print(f"[{'PASS' if result.ok else 'FAIL'}] {result.name}: {result.detail}")
    failed = sum(not result.ok for result in results)
    print(f"\n{len(results) - failed}/{len(results)} passed")
    return 1 if failed else 0


def lan_ip() -> str | None:
    for interface in ("en0", "en1"):
        out = subprocess.run(["ipconfig", "getifaddr", interface], capture_output=True, text=True)
        if out.stdout.strip():
            return out.stdout.strip()
    return None


def placeholder_jpeg() -> bytes:
    from PIL import Image

    output = BytesIO()
    Image.new("RGB", (64, 64), color=(200, 30, 30)).save(output, format="JPEG")
    return output.getvalue()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--image", type=Path, help="Fruit photo; required detection when given")
    parser.add_argument("--server", help="Call a running server instead of the in-process app")
    args = parser.parse_args()

    import httpx

    from app.core.env import env_value
    from app.services.object_detector import YoloObjectDetector
    from app.services.supabase_backend import get_supabase_client

    results = [
        check_env_keys(env_value),
        check_detector_flags(env_value),
        check_model(lambda: YoloObjectDetector(extra_model_paths=())._load_models()[0][1]),
        check_supabase(get_supabase_client),
        check_exchange_rate(env_value("TRUEPRICE_EXCHANGE_RATE_API_URL"), httpx.get),
        check_api_base_url(env_value("TRUEPRICE_API_BASE_URL"), lan_ip()),
    ]

    image = args.image.read_bytes() if args.image else placeholder_jpeg()
    if args.server:
        with httpx.Client(base_url=args.server, timeout=60) as client:
            results.append(check_scan(client, image, require_detection=bool(args.image)))
    else:
        from fastapi.testclient import TestClient

        from app.main import app

        with TestClient(app) as client:
            results.append(check_scan(client, image, require_detection=bool(args.image)))

    return report(results)


if __name__ == "__main__":
    sys.exit(main())
