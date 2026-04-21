"""FastAPI entrypoint placeholder for MVP backend."""

from fastapi import FastAPI

app = FastAPI(title="TruePrice API", version="0.1.0")


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}
