# Architecture (MVP)

## Current App Flow
1. `/` SplashScreen -> `/permission`
2. `PermissionScreen`에서 iPhone 권한 요청: camera, location, photos
3. `/intro` 온보딩 설명
4. `/home` 홈 화면에서 Scan, Map, Phrases, Community 선택
5. `/scan` ScanMenuScreen에서 두 탭 제공
   - `Live Scan`: 앱 내부 `CameraPreview`로 촬영 후 기존 scan pipeline 실행
   - `Camel Ride`: `분 + 제안 총액` 입력 후 분당 가격으로 분석
6. `/scan/stats`, `/scan/input`, `/scan/analysis`, `/scan/final` 가격 분석/제출 흐름

## Frontend Structure
- 라우팅: `go_router` (`lib/app/router.dart`)
- 메인 Shell: `AppBottomNavBar` + `/home`, `/scan`, `/map`, `/language`, `/community`
- 핵심 scan route 데이터: `ScanRouteData`
- 상태 처리: scan/price BLoC + repository(mock 기반, API 연결 준비됨)
- 카메라: `camera` 패키지의 `CameraController` + `CameraPreview`
- 권한: `permission_handler`, 온보딩에서 최초 요청

## Price Analysis Model
- 상품 scan 결과와 수동 입력 가격은 모두 `PriceAnalysisScreen`으로 전달됩니다.
- 낙타 가격은 `totalPrice / minutes = EGP per minute`로 변환합니다.
- `RegionStats.mock('camel_ride')`는 낙타 탑승 분당 가격 mock baseline을 제공합니다.

## Backend/DB Contract
- Detection API: `/scan/detect-object`
- Stats API: `/prices/stats`
- Submit API: `/prices/submit`
- 현재 Flutter MVP는 mock repository로 동작합니다.
- MLKit/OCR은 현재 앱에서 제거되었습니다. 가격 OCR이 필요해지면 backend OCR 또는 별도 on-device OCR 전략을 다시 선택해야 합니다.

## Guiding Principle
- 학습보다 구현, 완벽보다 동작
- iPhone 실기기 데모 우선
- API 계약 고정 후 연결(Contract-first)
- MVP 단계에서는 복잡한 추상화보다 흐름 완성 우선
