# Next Steps

## 1) iPhone 실기기 QA
- 온보딩 권한 허용/거부/영구 거부 플로우 확인
- Live Scan 탭에서 앱 내부 camera preview가 즉시 뜨는지 확인
- 촬영 버튼 -> mock detection -> stats -> input -> analysis -> final 회귀 테스트
- Gallery fallback 동작 확인
- Camel Ride 탭에서 `분 + 총액` 입력 후 분당 가격 분석 확인

## 2) Frontend API 실연결
- `scan_repository.dart`: mock 제거 후 `/scan/detect-object` 연동
- `price_repository.dart`: `/prices/stats`, `/prices/submit` 연동
- 성공 기준: 스캔 결과/통계/제출이 실데이터로 왕복

## 3) YOLO 추론 파이프라인 고정
- 클래스 목록 확정 및 라벨 정리
- baseline(`yolov8n`) 학습 + latency 측정
- FastAPI inference endpoint 안정화
- 현재 MLKit/OCR은 제거되어 있으므로, 가격표 OCR이 필요하면 backend OCR로 붙이는 방향을 우선 검토

## 4) 데이터 품질 보강
- `db/migrations` 기준 가격 관측치 스키마 점검
- RPC(`get_price_reference.sql`) 결과를 앱 통계 포맷과 일치
- `camel_ride`처럼 상품이 아닌 서비스 가격도 product/category로 저장할지 결정
- fallback 통계(샘플 부족 시) 정책 정의

## 5) MVP 릴리즈 전 정리
- `.DS_Store` gitignore 처리
- 오타 문서 `docs/TruePrice-Guidnlines.md` 삭제 상태 확인
- README와 앱 문구의 언어/타깃(iPhone-first) 일관성 확인
- `flutter analyze`, `flutter test`, `flutter build ios --no-codesign` 통과 확인
