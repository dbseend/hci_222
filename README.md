# hci_222

## 로컬 데모 (발표용)

시연은 맥북 로컬 백엔드 + iPhone 실기기 앱으로 합니다. 맥북과 iPhone은 같은
Wi-Fi/핫스팟에 연결하고, Supabase·Google Maps(·선택: 환율 API)는 인터넷으로 사용합니다.

1. **Setup** (최초 1회): `scripts/setup_local_demo.sh` — Python 3.11+ 확인, `.venv` 생성, 의존성 설치.
   `.env`가 없으면 `cp .env.example .env` 후 실제 값을 채웁니다.
2. **Preflight**: `.venv/bin/python scripts/demo_preflight.py --image <과일 사진.jpg>` —
   `.env` 키, Supabase, YOLO 모델(6종), 탐지 플래그, 환율 API(설정 시), LAN IP, `/scan`을 점검합니다.
   하나라도 FAIL이면 표시된 조치 후 다시 실행합니다.
3. **Server**: `scripts/run_local_server.sh` — 현재 LAN IP로 `TRUEPRICE_API_BASE_URL`을 맞추고 서버를 띄웁니다.
   IP가 바뀌었다는 경고가 나오면 4단계를 다시 해야 합니다.
4. **Flutter 실기기 빌드**: `cd frontend/flutter_app && flutter run --release` (또는 Xcode에서
   `ios/Runner.xcworkspace`를 열고 iPhone 선택 후 실행).

지연시간 측정(서버 실행 중): `.venv/bin/python scripts/measure_latency.py --image <과일 사진.jpg>`

> Vercel 웹 배포본은 **카메라 인식이 제한된 미리보기**입니다. 실제 인식 시연은 위 로컬 데모로 합니다.

Object Detection 기반 상품 인식 + 가격 비교 MVP 저장소입니다.

## Project Layout

```text
hci_222/
├── frontend/flutter_app/  # Flutter iPhone-first MVP app
├── backend/               # FastAPI API, tests, Supabase SQL
├── ml/                    # YOLO dataset build / evaluation scripts
├── scripts/               # Local demo, config generation, price seed helpers
└── docs/                  # Model report, price stats report, UT scenarios
```

Local-only data and generated artifacts are intentionally ignored:

- `dataset_open_v1/`
- `dataset_sources/`
- `datasets/`
- `outputs/`, `runs/`, `wandb/`
- model/archive artifacts such as `*.zip`, `*.pt`, `*.onnx`, `*.tflite`

## Current Status

- Flutter 앱은 `frontend/flutter_app` 기준으로 동작합니다.
- 온보딩에서 카메라/위치/사진 권한을 최초 요청합니다.
- 온보딩 후 `/home`에서 Scan, Map, Phrases, Community를 선택합니다.
- Scan 메뉴는 `Live Scan`과 `Camel Ride` 탭으로 분리되어 있습니다.
- `Live Scan`은 iPhone 실기기에서 앱 내부 `CameraPreview`로 촬영합니다.
- `Camel Ride`는 카메라 없이 `분 + 제안 총액`을 입력해 분당 가격으로 분석합니다.
- 상품 인식은 FastAPI의 YOLO, 가격/히스토리/커뮤니티는 FastAPI를 통한
  Supabase 연동이 기본입니다. 로컬 데모 fallback은 명시적으로 켠 경우에만
  동작합니다.
- ML 학습/데이터 준비 코드는 `ml/` 아래로 분리했고, 실제 데이터셋은 Git에 올리지 않습니다.

## Quick Start

### Flutter iPhone

```bash
cd frontend/flutter_app
flutter clean
flutter pub get
cd ios && pod install && cd ..
open ios/Runner.xcworkspace
```

Xcode에서는 `Runner.xcworkspace`를 열고 실제 iPhone을 선택해 실행합니다.

### Backend

Python 3.11 이상을 사용합니다.

```bash
cp .env.example .env  # 실제 개발 값으로 교체
cd backend
python3 -m pip install -r requirements-dev.txt
uvicorn app.main:app --host 0.0.0.0 --port 8000
```

Open:

```text
http://127.0.0.1:8000/docs
```

### ML

데이터셋 생성·학습·평가 재현 방법은 [`ml/README.md`](ml/README.md),
모델 성능과 한계는 [`docs/model_v2_report.md`](docs/model_v2_report.md)를 참고합니다.

## Verification

```bash
cd frontend/flutter_app
flutter analyze
flutter test
flutter build ios --no-codesign
```

Backend:

```bash
cd backend
python3 -m compileall -q app tests
python3 -m pytest
```

ML utility tests:

```bash
python3 -m pytest -q ml/tests
```

## Important Notes

- iOS 실기기 카메라 사용을 전제로 합니다. iOS Simulator는 실제 카메라 preview 테스트에 적합하지 않습니다.
- MLKit 관련 Xcode 경고를 제거하기 위해 `google_mlkit_text_recognition`을 제거했습니다.
- 데이터/학습 산출물은 로컬 재생성 대상으로 관리하고 Git에는 코드, 설정, 문서와 시연용 `backend/models/best.pt`만 올립니다.
- 프로덕션 배포 전 필수 환경 변수, Supabase migration, YOLO artifact 및
  fail-closed 설정은
  [`docs/refactoring_backlog.md`](docs/refactoring_backlog.md)의
  `Required deployment gates`를 따릅니다.
