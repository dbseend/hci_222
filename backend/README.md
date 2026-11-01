# Backend (FastAPI Price API)

## Scope

The backend owns object detection, product metadata, regional price references,
and price comparison verdicts.

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

Python 3.11 or newer is required.

```bash
cd backend
python3 -m pip install -r requirements-dev.txt
uvicorn app.main:app --reload
```

Open:

```text
http://127.0.0.1:8000/docs
```

## Object Detection

`POST /scan/detect-object` supports `mock`, `zero_shot`, and `yolo` detector
modes. Use `yolo` for the current MVP when the unified local YOLO model is
present: Flutter uploads the image, FastAPI runs YOLO inference, and the
response returns only the product identity. OCR is intentionally not part of
this flow.

```bash
# ../.env
TRUEPRICE_DETECTOR_MODE=yolo
TRUEPRICE_YOLO_MODEL_PATH=backend/models/best.pt
TRUEPRICE_WARM_UP_DETECTOR=true
# Optional only when running separate fallback models.
TRUEPRICE_YOLO_EXTRA_MODEL_PATHS=
```

Current `backend/models/best.pt` classes:

```text
tomato, apple, avocado, blueberry, cherry, kiwi, mango, orange, rockmelon, strawberry, cherry_tomato, camel_doll
```

When `TRUEPRICE_YOLO_EXTRA_MODEL_PATHS` is set, the backend runs all configured
YOLO models and returns the highest-confidence supported product detection.

`mock` mode is restricted to explicit local UI demos. It returns a catalog
product using filename hints when available, otherwise it returns `tomato`.
Production startup rejects this mode even when the allow flag is accidentally
set.

```bash
# ../.env
TRUEPRICE_DETECTOR_MODE=mock
TRUEPRICE_ALLOW_MOCK_DETECTOR=true
TRUEPRICE_APP_ENV=development
```

Keep trained model artifacts local-only under:

```text
backend/models/best.pt
backend/models/best_camel_doll_only.pt
backend/models/best_float32.tflite
backend/models/results.csv
```

To run zero-shot fallback instead, install `transformers`, `torch`, and `pillow`,
then set:

```bash
# ../.env
TRUEPRICE_DETECTOR_MODE=zero_shot
TRUEPRICE_ZERO_SHOT_MODEL=google/owlvit-base-patch32
```

The API catalog supports:

```text
tomato, cherry_tomato, apple, avocado, banana, blueberry, cherry, kiwi, mango, orange, rockmelon, strawberry, camel_doll
```

For physical phone testing, run the API on the Mac's LAN interface:

```bash
uvicorn app.main:app --host 0.0.0.0 --port 8000
```

Then run Flutter with the Mac's local IP address:

```bash
# Edit .env at the repository root:
# TRUEPRICE_API_BASE_URL=http://<mac-lan-ip>:8000
python3 scripts/generate_flutter_defines.py
cd frontend/flutter_app
flutter run
```

Or override only the Flutter API URL for a one-off run:

```bash
cd frontend/flutter_app
flutter run --dart-define=TRUEPRICE_API_BASE_URL=http://<mac-lan-ip>:8000
```

## Supabase Server-Side Integration

Flutter no longer connects to Supabase directly. Database and Storage writes
are handled by FastAPI. Flutter only uses Supabase Auth to obtain an anonymous
user access token; FastAPI verifies that token and derives record ownership from
the verified user ID. Set both the public Auth credentials and the backend-only
service role credential in the single local env file:

```bash
# ../.env
TRUEPRICE_API_BASE_URL=http://YOUR_BACKEND_HOST:8000
SUPABASE_URL=https://YOUR_PROJECT_REF.supabase.co
SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLIC_SUPABASE_PUBLISHABLE_KEY
SUPABASE_SERVICE_ROLE_KEY=YOUR_BACKEND_ONLY_SERVICE_ROLE_KEY
TRUEPRICE_APP_ENV=development
TRUEPRICE_DETECTOR_MODE=yolo
TRUEPRICE_ALLOW_MOCK_DETECTOR=false
TRUEPRICE_ENABLE_DEMO_FALLBACKS=false
```

Never place `SUPABASE_SERVICE_ROLE_KEY` in Flutter or any client-side config.
`scripts/generate_flutter_defines.py` copies the API URLs plus the public
`SUPABASE_URL` and `SUPABASE_PUBLISHABLE_KEY`; it never copies the service role
key. Enable anonymous sign-ins in Supabase Auth before running the app.

Server-owned Supabase endpoints:

```text
POST /scan/history
GET  /scan/history
PATCH /scan/history/{history_id}/detection
PATCH /scan/history/{history_id}/price
GET  /api/v1/community/feed
POST /api/v1/community/posts
```

All history mutations and community post creation require
`Authorization: Bearer <user-access-token>`. The API ignores client-provided
owner IDs and always uses the verified token subject.

Product and price endpoints now prefer Supabase as the source of truth:

```text
GET /api/v1/products
GET /api/v1/products/{product_id}/price-stats
POST /api/v1/price/compare
```

If Supabase is unavailable in local development, the backend falls back to
`backend/app/data/product_catalog.json` and `backend/app/data/price_stats.json`
only when `TRUEPRICE_ALLOW_LOCAL_DATA_FALLBACK=true`. Production disables this
fallback and returns a sanitized 503 instead of serving stale demo data.

Before using authenticated history/community writes, apply both migrations:

```sql
-- backend/supabase/scan_history_cache.sql
-- backend/supabase/auth_ownership_hardening.sql
```

The ownership migration enables RLS, revokes direct `anon`/`authenticated`
table access, and adds owner/timestamp indexes. Data access remains server-only;
FastAPI uses the service role and therefore must keep its explicit owner filters.

## Production configuration

The container defaults to fail-closed behavior:

```bash
TRUEPRICE_APP_ENV=production
TRUEPRICE_DETECTOR_MODE=yolo
TRUEPRICE_ALLOW_MOCK_DETECTOR=false
TRUEPRICE_ALLOW_LOCAL_DATA_FALLBACK=false
TRUEPRICE_WARM_UP_DETECTOR=true
TRUEPRICE_CORS_ALLOW_ORIGINS=https://YOUR_APP_ORIGIN
```

The deployment must inject `backend/models/best.pt`; model files are excluded
from Git intentionally. A missing or unloadable model aborts production startup.
Use `requirements-dev.txt` for local tests and `requirements-ml.txt` for a
runtime that performs YOLO inference.

Before release, apply both Supabase migrations, enable anonymous sign-in, and
provide real public/client and service-role credentials. Never use the service
role credential in Flutter.

Verification:

```bash
python3 -m compileall -q app tests
python3 -m pytest -q
```

## Example

```bash
curl -X POST http://127.0.0.1:8000/api/v1/price/compare \
  -H 'Content-Type: application/json' \
  -d '{"product_id":"tomato","region":"cairo","user_price":25,"currency":"EGP"}'
```
