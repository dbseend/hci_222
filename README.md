# hci_222

Object Detection 기반 상품 인식 + 가격 비교 MVP 저장소입니다.

## Project Layout
- `frontend/flutter_app`: Flutter 앱 (스캔/가격 입력/분석/제출 플로우)
- `backend`: FastAPI API 서버 (`/scan/detect-object`, 가격 분석 API)
- `db`: PostgreSQL(Supabase) 스키마, 마이그레이션, RPC
- `docs`: 아키텍처/가이드/실행 우선순위 문서

## Current Status
- TruePrice 기반 Flutter 코드가 `frontend/flutter_app`로 마이그레이션 완료
- 스캔 플로우 라우팅 인자 타입 리팩토링 완료 (`ScanRouteData`)
- UX 가이드 문서 정리 완료:
  - `docs/TruePrice-Guidnlines.md`
  - `docs/TruePrice-Guidelines.md`

## Quick Start
1. Backend: `backend/app/main.py` 기준 FastAPI 실행
2. Frontend:
   - `cd frontend/flutter_app`
   - `flutter pub get`
   - `flutter run`
