"""FastAPI entrypoint for the TruePrice MVP backend."""

import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI

from app.api import community, price, products, scan
from app.services.object_detector import ObjectDetectorUnavailable, warm_up_detector

logging.basicConfig(
    level=logging.INFO,
    format="%(levelname)s:%(name)s:%(message)s",
)
logging.getLogger("app").setLevel(logging.INFO)


@asynccontextmanager
async def lifespan(app: FastAPI):
    try:
        warm_up_detector()
        logging.getLogger("app").info("object_detector_warmed_up")
    except ObjectDetectorUnavailable as exc:
        logging.getLogger("app").warning("object_detector_warm_up_skipped reason=%s", exc)
    yield


app = FastAPI(title="TruePrice API", version="0.1.0", lifespan=lifespan)

app.include_router(products.router)
app.include_router(price.router)
app.include_router(scan.router)
app.include_router(community.router)


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}
