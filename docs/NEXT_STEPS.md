# Next Steps

## 1) Frontend API 실연결
- `scan_repository.dart`: mock 제거 후 `/scan/detect-object` 연동
- `price_repository.dart`: `/prices/stats`, `/prices/submit` 연동
- 성공 기준: 스캔 결과/통계/제출이 실데이터로 왕복

## 2) YOLO 추론 파이프라인 고정
- 클래스 목록 확정 및 라벨 정리
- baseline(`yolov8n`) 학습 + latency 측정
- FastAPI inference endpoint 안정화

## 3) 데이터 품질 보강
- `db/migrations` 기준 가격 관측치 스키마 점검
- RPC(`get_price_reference.sql`) 결과를 앱 통계 포맷과 일치
- fallback 통계(샘플 부족 시) 정책 정의

## 4) QA (MVP 릴리즈 전)
- 실제 디바이스(Android/iOS) 카메라/권한 테스트
- 주요 시나리오 회귀:
  - scan → stats → input → analysis → final
  - 네트워크 실패/권한 거부/빈 응답
