"""FastAPI entrypoint for the TruePrice MVP backend."""

import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api import community, price, products, scan
from app.core.env import env_value
from app.services.object_detector import ObjectDetectorUnavailable, warm_up_detector

logging.basicConfig(
    level=logging.INFO,
    format="%(levelname)s:%(name)s:%(message)s",
)
logging.getLogger("app").setLevel(logging.INFO)


@asynccontextmanager
async def lifespan(app: FastAPI):
    if _should_warm_up_detector():
        try:
            warm_up_detector()
            logging.getLogger("app").info("object_detector_warmed_up")
        except ObjectDetectorUnavailable as exc:
            logging.getLogger("app").warning(
                "object_detector_warm_up_skipped reason=%s",
                exc,
            )
        except Exception:
            logging.getLogger("app").exception("object_detector_warm_up_failed")
    else:
        logging.getLogger("app").info("object_detector_warm_up_disabled")
    yield


def _should_warm_up_detector() -> bool:
    return (env_value("TRUEPRICE_WARM_UP_DETECTOR") or "").strip().lower() == "true"


def _env_csv_values(name: str) -> list[str]:
    raw_value = env_value(name) or ""
    return [value.strip() for value in raw_value.split(",") if value.strip()]


def _optional_env_value(name: str) -> str | None:
    value = env_value(name)
    if value is None:
        return None
    value = value.strip()
    return value or None


app = FastAPI(title="TruePrice API", version="0.1.0", lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=_env_csv_values("TRUEPRICE_CORS_ALLOW_ORIGINS"),
    allow_origin_regex=_optional_env_value("TRUEPRICE_CORS_ALLOW_ORIGIN_REGEX"),
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(products.router)
app.include_router(price.router)
app.include_router(scan.router)
app.include_router(community.router)


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}
