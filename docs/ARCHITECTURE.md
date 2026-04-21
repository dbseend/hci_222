# Architecture (MVP)

## End-to-End Flow
1. Flutter `ScanScreen`에서 이미지 촬영/업로드
2. Backend `POST /scan/detect-object`에서 상품 인식 + OCR 가격 추출
3. Flutter `PriceStatsScreen`에서 지역 통계 조회
4. Flutter `PriceInputScreen`에서 사용자 입력 가격(단위당) 계산
5. Flutter `PriceAnalysisScreen`에서 `safe / negotiable / warning` 판정
6. Flutter `FinalPriceScreen`에서 crowdsource 가격 제출

## Frontend Structure
- 라우팅: `go_router` (`lib/app/router.dart`)
- 핵심 scan route 데이터: `ScanRouteData`
- 상태 처리: scan/price BLoC + repository(mock 기반, API 연결 준비됨)

## Backend/DB Contract
- Detection API: `/scan/detect-object`
- Stats API: `/prices/stats`
- Submit API: `/prices/submit`
- DB는 가격 관측치의 source of truth 역할

## Guiding Principle
- 학습보다 구현, 완벽보다 동작
- API 계약 고정 후 연결(Contract-first)
- MVP 단계에서는 복잡한 추상화보다 흐름 완성 우선
