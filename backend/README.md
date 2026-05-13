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

## Object Detection

`POST /scan/detect-object` supports `mock`, `zero_shot`, and `yolo` detector
modes. Use `zero_shot` for the current MVP: Flutter uploads the image, FastAPI
classifies it with text prompts, and the response returns only the product
identity. OCR is intentionally not part of this flow.

```bash
# ../.env
TRUEPRICE_DETECTOR_MODE=zero_shot
TRUEPRICE_ZERO_SHOT_MODEL=google/owlvit-base-patch32
```

The current zero-shot product prompts map to:

```text
fruit, camel_doll
```

`mock` mode remains available for offline UI demos. It returns a catalog product
using filename hints when available, otherwise it returns `tomato`.

```bash
# ../.env
TRUEPRICE_DETECTOR_MODE=mock
```

Optional YOLO mode is still available for local experiments, but it is no longer
required for normal app execution. Keep trained model artifacts local-only under:

```text
backend/models/best.pt
backend/models/best_float32.tflite
backend/models/results.csv
```

To run YOLO mode, install `ultralytics` manually and set:

```bash
# ../.env
TRUEPRICE_DETECTOR_MODE=yolo
TRUEPRICE_YOLO_MODEL_PATH=/path/to/best.pt
```

The currently supported YOLO product classes are:

```text
tomato, apple, avocado, blueberry, cherry, kiwi, mango, orange, rockmelon, strawberry, camel_doll
```

For physical phone testing, run the API on the Mac's LAN interface:

```bash
uvicorn app.main:app --host 0.0.0.0 --port 8000
```

Then run Flutter with the Mac's local IP address:

```bash
# Edit ../.env:
# TRUEPRICE_API_BASE_URL=http://<mac-lan-ip>:8000
python3 ../scripts/generate_flutter_defines.py
cd ../frontend/flutter_app
flutter run --dart-define-from-file=.dart_tool/trueprice_dart_defines.json
```

## Supabase Server-Side Integration

Flutter no longer connects to Supabase directly. Database and Storage writes
are handled by FastAPI. Set backend-only Supabase credentials in the single
local env file before running endpoints that write scan history or community
posts:

```bash
# ../.env
TRUEPRICE_API_BASE_URL=http://YOUR_BACKEND_HOST:8000
SUPABASE_URL=https://YOUR_PROJECT_REF.supabase.co
SUPABASE_SERVICE_ROLE_KEY=YOUR_BACKEND_ONLY_SERVICE_ROLE_KEY
TRUEPRICE_DETECTOR_MODE=mock
```

Never place `SUPABASE_SERVICE_ROLE_KEY` in Flutter or any client-side config.
`scripts/generate_flutter_defines.py` only copies `TRUEPRICE_API_BASE_URL` into
Flutter's generated `.dart_tool/trueprice_dart_defines.json`.

Server-owned Supabase endpoints:

```text
POST /scan/history
GET  /scan/history?client_user_id=<anonymous-id>
GET  /api/v1/community/feed
POST /api/v1/community/posts
```

## Example

```bash
curl -X POST http://127.0.0.1:8000/api/v1/price/compare \
  -H 'Content-Type: application/json' \
  -d '{"product_id":"tomato","region":"cairo","user_price":25,"currency":"EGP"}'
```
