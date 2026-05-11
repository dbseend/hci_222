# hci_222

Object Detection 기반 상품 인식 + 가격 비교 MVP 저장소입니다.

## Project Layout

```text
hci_222/
├── frontend/flutter_app/  # Flutter iPhone-first MVP app
├── backend/               # FastAPI price/catalog API
├── db/                    # SQL migrations, seeds, views, RPC
├── supabase/              # Supabase local/linked project config
├── ml/                    # Dataset scripts, audit tools, Colab notebooks
└── docs/                  # Architecture, guidelines, project notes
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
- 가격 통계/커뮤니티/지도 데이터는 MVP mock 데이터입니다.
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

```bash
cd backend
python3 -m pip install -r requirements.txt
uvicorn app.main:app --host 0.0.0.0 --port 8000
```

Open:

```text
http://127.0.0.1:8000/docs
```

### ML / Colab

```bash
python3 ml/scripts/build_open_fruit_camel_dataset.py
```

Colab 학습 노트북:

```text
ml/notebooks/train_trueprice_yolo_colab.ipynb
```

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
python3 -m pytest
```

## Important Notes

- iOS 실기기 카메라 사용을 전제로 합니다. iOS Simulator는 실제 카메라 preview 테스트에 적합하지 않습니다.
- MLKit 관련 Xcode 경고를 제거하기 위해 `google_mlkit_text_recognition`을 제거했습니다.
- 문서 기준 파일은 `docs/TruePrice-Guidelines.md`입니다.
- GitHub 업로드/제외 기준은 `docs/GITHUB_REPOSITORY_GUIDE.md`입니다.
- 데이터/모델 산출물은 로컬 재생성 대상으로 관리하고 Git에는 코드, 설정, 문서만 올립니다.
