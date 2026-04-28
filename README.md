# hci_222

Object Detection 기반 상품 인식 + 가격 비교 MVP 저장소입니다.

## Project Layout
- `frontend/flutter_app`: Flutter iPhone-first 앱 (온보딩 권한, 홈, 스캔/낙타 가격 분석, 지도, phrases, 커뮤니티)
- `backend`: FastAPI API 서버 초안 (`/scan/detect-object`, 가격 분석 API)
- `db`: PostgreSQL(Supabase) 스키마, 마이그레이션, RPC
- `docs`: 아키텍처/가이드/실행 우선순위 문서

## Current Status
- Flutter 앱은 `frontend/flutter_app` 기준으로 동작합니다.
- 온보딩에서 카메라/위치/사진 권한을 최초 요청합니다.
- 온보딩 후 `/home`에서 Scan, Map, Phrases, Community를 선택합니다.
- Scan 메뉴는 `Live Scan`과 `Camel Ride` 탭으로 분리되어 있습니다.
- `Live Scan`은 iPhone 실기기에서 앱 내부 `CameraPreview`로 촬영합니다.
- `Camel Ride`는 카메라 없이 `분 + 제안 총액`을 입력해 분당 가격으로 분석합니다.
- 가격 통계/커뮤니티/지도 데이터는 MVP mock 데이터입니다.
- MLKit/OCR 의존성은 현재 필요하지 않아 제거했습니다.

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

### Verification
```bash
cd frontend/flutter_app
flutter analyze
flutter test
flutter build ios --no-codesign
```

## Important Notes
- iOS 실기기 카메라 사용을 전제로 합니다. iOS Simulator는 실제 카메라 preview 테스트에 적합하지 않습니다.
- MLKit 관련 Xcode 경고를 제거하기 위해 `google_mlkit_text_recognition`을 제거했습니다.
- 문서 기준 파일은 `docs/TruePrice-Guidelines.md`입니다. 오타 파일 `docs/TruePrice-Guidnlines.md`는 삭제 대상입니다.
