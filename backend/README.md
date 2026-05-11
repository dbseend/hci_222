# Backend (FastAPI Price API)

## Scope

YOLO inference runs on-device in the Flutter app. The backend owns product
metadata, regional price references, and price comparison verdicts.

- `GET /api/v1/products`
- `GET /api/v1/products/{product_id}`
- `GET /api/v1/products/{product_id}/price-stats?region=cairo`
- `POST /api/v1/price/compare`

## Folder Guide
- `app/api`: route handlers
- `app/services`: catalog and price comparison business logic
- `app/models`: request/response models
- `app/core`: config and shared utils

## Local Run

```bash
cd backend
python3 -m pip install -r requirements.txt
uvicorn app.main:app --reload
```

Open:

```text
http://127.0.0.1:8000/docs
```

For physical phone testing, run the API on the Mac's LAN interface:

```bash
uvicorn app.main:app --host 0.0.0.0 --port 8000
```

Then run Flutter with the Mac's local IP address:

```bash
flutter run \
  --dart-define=TRUEPRICE_API_BASE_URL=http://<mac-lan-ip>:8000
```

## Example

```bash
curl -X POST http://127.0.0.1:8000/api/v1/price/compare \
  -H 'Content-Type: application/json' \
  -d '{"product_id":"tomato","region":"cairo","user_price":25,"currency":"EGP"}'
```
