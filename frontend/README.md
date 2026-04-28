# Frontend (Flutter)

## Status
- Flutter 앱 위치: `frontend/flutter_app`
- iPhone-first MVP로 개발 중입니다.
- 주요 흐름: 온보딩 권한 요청 -> 홈 -> 기능 선택 -> 가격 확인/지도/phrases/커뮤니티

## Implemented Flow
- `PermissionScreen`: 카메라, 위치, 사진 권한을 온보딩에서 최초 요청
- `HomeScreen`: Scan, Map, Phrases, Community 진입 카드 제공
- `ScanMenuScreen`: 가격 확인 메뉴를 `Live Scan` / `Camel Ride` 탭으로 분리
- `ScanScreen`: `camera` 패키지 기반 앱 내부 `CameraPreview` + 촬영 버튼
- `CamelPriceInputScreen`: 카메라 없이 `분 + 총 제안가`를 입력해 분당 가격 분석
- 기존 가격 분석 화면은 `ScanRouteData`로 값을 받아 동일하게 재사용

## Key Packages
- `camera`: iPhone 실기기 카메라 preview 및 촬영
- `image_picker`: 갤러리 fallback
- `permission_handler`: 온보딩 권한 요청 및 설정 앱 이동
- `go_router`: ShellRoute + nested scan routes
- `flutter_bloc`: scan/price state machine
- `fl_chart`: 가격 분포 histogram

## Removed
- `google_mlkit_text_recognition`: 현재 MVP에서 OCR/MLKit을 쓰지 않아 제거

## Run
```bash
cd frontend/flutter_app
flutter pub get
cd ios && pod install && cd ..
open ios/Runner.xcworkspace
```

## Verify
```bash
flutter analyze
flutter test
flutter build ios --no-codesign
```
