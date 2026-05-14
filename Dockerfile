FROM python:3.11-slim

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    TRUEPRICE_DETECTOR_MODE=yolo \
    TRUEPRICE_YOLO_MODEL_PATH=backend/models/best.pt

WORKDIR /app

COPY backend/requirements.txt ./backend/requirements.txt
RUN pip install --no-cache-dir -r backend/requirements.txt

COPY backend ./backend

WORKDIR /app/backend

CMD uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8000} --proxy-headers
