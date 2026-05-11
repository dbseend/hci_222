"""FastAPI entrypoint for the TruePrice MVP backend."""

from fastapi import FastAPI

from app.api import price, products

app = FastAPI(title="TruePrice API", version="0.1.0")

app.include_router(products.router)
app.include_router(price.router)


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}
