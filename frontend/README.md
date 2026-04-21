# Frontend (Flutter)

## Status
- `frontend/flutter_app`로 TruePrice Flutter 앱 마이그레이션 완료
- 스캔 → 통계 → 가격 입력 → 분석 → 제출 플로우 구현

## Refactoring Applied
- `GoRouter extra` 전달값을 `ScanRouteData` 타입으로 통합 (맵 캐스팅 제거)
- `withValues` 사용 구문을 `withOpacity`로 정리해 Flutter SDK 호환성 개선

## Guideline
- 요청 문서 반영:
  - `docs/TruePrice-Guidnlines.md`
  - `docs/TruePrice-Guidelines.md`
