"""FastAPI entrypoint for the Price Lens MVP backend."""

import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from starlette.concurrency import run_in_threadpool

from app.api import community, price, products, scan
from app.core.auth import get_auth_verifier
from app.core.env import env_value
from app.core.request_limits import RequestBodyLimitMiddleware
from app.core.uploads import ImageUploadError, configured_max_image_upload_bytes
from app.services.object_detector import (
    ObjectDetectorUnavailable,
    ObjectNotDetected,
    warm_up_detector,
)
from app.services.supabase_backend import (
    SupabaseBackendUnavailable,
    SupabaseResourceNotFound,
    SupabaseUnknownProduct,
)

DEFAULT_CORS_ALLOW_ORIGINS = [
    "http://localhost:3000",
    "http://localhost:8000",
    "http://127.0.0.1:3000",
    "http://127.0.0.1:8000",
    "https://web-one-gold-53.vercel.app",
]
MAX_REQUEST_BODY_BYTES = configured_max_image_upload_bytes() + 1024 * 1024

logging.basicConfig(
    level=logging.INFO,
    format="%(levelname)s:%(name)s:%(message)s",
)
logging.getLogger("app").setLevel(logging.INFO)


@asynccontextmanager
async def lifespan(app: FastAPI):
    try:
        if _should_warm_up_detector():
            try:
                await run_in_threadpool(warm_up_detector)
                logging.getLogger("app").info("object_detector_warmed_up")
            except ObjectDetectorUnavailable as exc:
                if _is_production():
                    raise
                logging.getLogger("app").warning(
                    "object_detector_warm_up_skipped reason=%s",
                    exc,
                )
            except Exception:
                logging.getLogger("app").exception("object_detector_warm_up_failed")
                if _is_production():
                    raise
        else:
            logging.getLogger("app").info("object_detector_warm_up_disabled")
        yield
    finally:
        await get_auth_verifier().aclose()
        get_auth_verifier.cache_clear()


def _should_warm_up_detector() -> bool:
    return (env_value("TRUEPRICE_WARM_UP_DETECTOR") or "").strip().lower() == "true"


def _is_production() -> bool:
    return (env_value("TRUEPRICE_APP_ENV", "development") or "development").lower() == "production"


def _env_csv_values(name: str) -> list[str]:
    raw_value = env_value(name) or ""
    return [value.strip() for value in raw_value.split(",") if value.strip()]


def _cors_allow_origins() -> list[str]:
    configured = _env_csv_values("TRUEPRICE_CORS_ALLOW_ORIGINS")
    if configured:
        return configured
    if _is_production():
        raise RuntimeError(
            "TRUEPRICE_CORS_ALLOW_ORIGINS is required in production."
        )
    return DEFAULT_CORS_ALLOW_ORIGINS


def _optional_env_value(name: str) -> str | None:
    value = env_value(name)
    if value is None:
        return None
    value = value.strip()
    return value or None


app = FastAPI(title="Price Lens API", version="0.1.0", lifespan=lifespan)


app.add_middleware(
    RequestBodyLimitMiddleware,
    max_bytes=MAX_REQUEST_BODY_BYTES,
)
app.add_middleware(
    CORSMiddleware,
    allow_origins=_cors_allow_origins(),
    allow_origin_regex=_optional_env_value("TRUEPRICE_CORS_ALLOW_ORIGIN_REGEX"),
    allow_methods=["GET", "POST", "PATCH", "OPTIONS"],
    allow_headers=["Authorization", "Content-Type"],
)

app.include_router(products.router)
app.include_router(price.router)
app.include_router(scan.router)
app.include_router(community.router)


@app.exception_handler(ImageUploadError)
async def image_upload_error_handler(
    _request: Request,
    exc: ImageUploadError,
) -> JSONResponse:
    return JSONResponse(status_code=exc.status_code, content={"detail": str(exc)})


@app.exception_handler(SupabaseUnknownProduct)
async def unknown_product_handler(
    _request: Request,
    exc: SupabaseUnknownProduct,
) -> JSONResponse:
    return JSONResponse(status_code=422, content={"detail": str(exc)})


@app.exception_handler(SupabaseResourceNotFound)
async def resource_not_found_handler(
    _request: Request,
    _exc: SupabaseResourceNotFound,
) -> JSONResponse:
    return JSONResponse(status_code=404, content={"detail": "Resource not found."})


@app.exception_handler(SupabaseBackendUnavailable)
async def data_service_unavailable_handler(
    request: Request,
    exc: SupabaseBackendUnavailable,
) -> JSONResponse:
    logging.getLogger("app").error(
        "data_service_unavailable path=%s reason=%s",
        request.url.path,
        exc,
    )
    return JSONResponse(
        status_code=503,
        content={"detail": "Data service is unavailable."},
    )


@app.exception_handler(ObjectNotDetected)
async def object_not_detected_handler(
    _request: Request,
    exc: ObjectNotDetected,
) -> JSONResponse:
    return JSONResponse(status_code=404, content={"detail": str(exc)})


@app.exception_handler(ObjectDetectorUnavailable)
async def detector_unavailable_handler(
    request: Request,
    exc: ObjectDetectorUnavailable,
) -> JSONResponse:
    logging.getLogger("app").error(
        "object_detector_unavailable path=%s reason=%s",
        request.url.path,
        exc,
    )
    return JSONResponse(
        status_code=503,
        content={"detail": "Object detector is unavailable."},
    )


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}
