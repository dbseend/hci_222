"""FastAPI entrypoint for the TruePrice MVP backend."""

import logging

from fastapi import FastAPI

from app.api import community, price, products, scan

logging.basicConfig(
    level=logging.INFO,
    format="%(levelname)s:%(name)s:%(message)s",
)
logging.getLogger("app").setLevel(logging.INFO)

app = FastAPI(title="TruePrice API", version="0.1.0")

app.include_router(products.router)
app.include_router(price.router)
app.include_router(scan.router)
app.include_router(community.router)


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}
