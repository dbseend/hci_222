# TruePrice UT Scenarios

## 핵심 판단

MVP 기준 UT 우선순위는 `가격 판정 로직`, `객체 인식 API 계약`, `Flutter repository fallback`, `스캔 히스토리 캐시`, `커뮤니티 공유` 순서입니다. 카메라 preview, 실제 YOLO 모델 추론, 지도 렌더링은 기기/통합 테스트 성격이 강하므로 UT에서는 mock/fake로 경계만 검증합니다.

## 테스트 범위

| 구분 | 포함 | 제외 |
|---|---|---|
| Flutter UT | repository, bloc, pure utility, local cache, model parsing | 실제 카메라, 실제 위치 권한, 실제 네트워크 |
| Backend UT | FastAPI route contract, service logic, Supabase adapter mapping, detector mode selection | 실제 Supabase, 실제 YOLO weight 로딩 |
| ML UT | 데이터셋 생성/검증 script 단위 동작 | 모델 학습 품질, GPU 학습 시간 |

## P0: 데모 실패를 막는 필수 시나리오

### 1. 상품 인식 성공 응답을 앱 모델로 변환한다

- 대상: `frontend/flutter_app/lib/features/scan/data/repositories/scan_repository.dart`
- 추천 테스트 파일: `frontend/flutter_app/test/scan_repository_test.dart`
- 현재 상태: 보강 필요
- Given: fake Dio가 `/scan/detect-object`에 `tomato`, Arabic name, confidence를 반환한다.
- When: `detectObjectBytes()`를 호출한다.
- Then: `DetectionResult.productId == tomato`, `productNameAr == طماطم`, `confidence == 0.91`로 파싱된다.

### 2. 객체 인식 API가 빈 이미지 업로드를 거절한다

- 대상: `backend/app/api/scan.py`
- 추천 테스트 파일: `backend/tests/test_scan_api.py`
- 현재 상태: 존재
- Given: 빈 파일이 multipart로 업로드된다.
- When: `POST /scan/detect-object`를 호출한다.
- Then: `400`을 반환하고 detector를 실제 호출하지 않는다.

### 3. YOLO/mock detector가 가격 기준이 없는 상품을 결과로 내지 않는다

- 대상: `backend/app/services/object_detector.py`
- 추천 테스트 파일: `backend/tests/test_scan_api.py`
- 현재 상태: 부분 보강 필요
- Given: fake YOLO가 `banana`처럼 catalog에는 있을 수 있지만 현재 price reference가 없는 class를 반환한다.
- When: `YoloObjectDetector.detect()`를 호출한다.
- Then: `ObjectNotDetected`가 발생한다.

### 4. 가격 판정 threshold가 Flutter와 Backend에서 같은 의미를 유지한다

- 대상: `frontend/flutter_app/lib/core/utils/price_classifier.dart`, `backend/app/services/price_matcher.py`
- 추천 테스트 파일: `frontend/flutter_app/test/price_classifier_test.dart`, `backend/tests/test_price_matcher.py`
- 현재 상태: 보강 필요
- Given: 평균 20, 표준편차 10이다.
- When: 사용자 가격이 20, 25, 36이다.
- Then: 각각 `safe`, `negotiable`, `warning`으로 판정된다.

### 5. 가격 API 장애 시 Flutter가 local MVP fallback을 사용한다

- 대상: `frontend/flutter_app/lib/features/scan/data/repositories/price_repository.dart`
- 추천 테스트 파일: `frontend/flutter_app/test/price_repository_test.dart`
- 현재 상태: 존재
- Given: Dio가 connection error를 던진다.
- When: `getStats()`와 `comparePrice()`를 호출한다.
- Then: `RegionStats.mock(productId)` 기반 결과와 `overpriced/negotiable/safe` 메시지를 반환한다.

### 6. 스캔 이미지는 원격 업로드를 기다리지 않고 로컬 히스토리에 저장된다

- 대상: `frontend/flutter_app/lib/features/scan/data/repositories/scan_history_repository.dart`
- 추천 테스트 파일: `frontend/flutter_app/test/scan_history_repository_test.dart`
- 현재 상태: 존재
- Given: remote upload adapter가 지연된다.
- When: `addCapturedImage()`를 호출한다.
- Then: 로컬 파일 path를 먼저 반환하고, background upload만 시작된다.

### 7. Camel Ride 가격 입력은 분당 가격으로 변환되어 가격 분석에 전달된다

- 대상: `frontend/flutter_app/lib/features/scan/presentation/screens/price_input_screen.dart`
- 추천 테스트 파일: `frontend/flutter_app/test/camel_ride_price_input_test.dart`
- 현재 상태: 보강 필요
- Given: 사용자가 30분, 총액 600 EGP를 입력한다.
- When: 분석 버튼을 누른다.
- Then: 다음 화면 route data의 `userPrice`가 `20 EGP/min`으로 전달된다.

## P1: 사용자 흐름 안정화 시나리오

### 8. ScanBloc은 인식 성공/실패 상태를 명확히 emit한다

- 대상: `frontend/flutter_app/lib/features/scan/presentation/bloc/scan_bloc.dart`
- 추천 테스트 파일: `frontend/flutter_app/test/scan_bloc_test.dart`
- 현재 상태: 보강 필요
- Given: fake repository가 성공 결과를 반환한다.
- When: `ScanImageBytesCaptured` event를 add한다.
- Then: `ScanProcessing -> ScanDetected` 순서로 상태가 나온다.
- 실패 케이스: repository가 exception을 던지면 `ScanProcessing -> ScanError`.

### 9. PriceBloc은 stats만 요청한 경우와 userPrice 포함 요청을 구분한다

- 대상: `frontend/flutter_app/lib/features/scan/presentation/bloc/price_bloc.dart`
- 추천 테스트 파일: `frontend/flutter_app/test/price_bloc_test.dart`
- 현재 상태: 보강 필요
- Given: fake location과 fake price repository가 있다.
- When: `PriceStatsRequested(productId)`를 호출한다.
- Then: `PriceLoaded(stats)`만 emit한다.
- When: `PriceStatsRequested(productId, userPrice)`를 호출한다.
- Then: `PriceLoaded(stats, comparison)`을 emit한다.

### 10. 가격 통계 cache는 같은 product/region 요청을 재사용한다

- 대상: `frontend/flutter_app/lib/features/scan/data/repositories/price_repository.dart`
- 추천 테스트 파일: `frontend/flutter_app/test/price_repository_test.dart`
- 현재 상태: 보강 필요
- Given: fake Dio가 호출 횟수를 기록한다.
- When: 같은 `productId`로 `getStats()`를 두 번 호출한다.
- Then: 네트워크 호출은 한 번만 발생한다.

### 11. 가격 제출 후 해당 상품 cache가 무효화된다

- 대상: `frontend/flutter_app/lib/features/scan/data/repositories/price_repository.dart`
- 추천 테스트 파일: `frontend/flutter_app/test/price_repository_test.dart`
- 현재 상태: 보강 필요
- Given: `tomato:cairo` cache가 존재한다.
- When: `submitPrice(productId: tomato)`를 호출한다.
- Then: 다음 `getStats(tomato)`는 API/fallback을 다시 조회한다.

### 12. 원격 스캔 히스토리의 detection/quoted price cache를 앱 모델로 복원한다

- 대상: `frontend/flutter_app/lib/features/scan/data/repositories/scan_history_repository.dart`
- 추천 테스트 파일: `frontend/flutter_app/test/scan_history_repository_test.dart`
- 현재 상태: 존재
- Given: backend history row에 `detected_product_code`, `quoted_unit_price_egp`가 포함되어 있다.
- When: `getHistory()`를 호출한다.
- Then: `hasDetectionCache == true`, `hasQuotedPrice == true`가 된다.

### 13. 커뮤니티 글 작성은 이미지와 payload를 multipart로 전송한다

- 대상: `backend/app/api/community.py`
- 추천 테스트 파일: `backend/tests/test_community_api.py`
- 현재 상태: 존재
- Given: image file과 JSON payload가 multipart로 전달된다.
- When: `POST /api/v1/community/posts`를 호출한다.
- Then: service에 image bytes, filename, parsed payload가 전달되고 `201`을 반환한다.

### 14. 커뮤니티 로컬 저장소는 새 글을 최신순으로 반환한다

- 대상: `frontend/flutter_app/lib/features/community/data/repositories/community_post_repository.dart`
- 추천 테스트 파일: `frontend/flutter_app/test/community_post_repository_test.dart`
- 현재 상태: 존재
- Given: 글 2개를 시간차로 저장한다.
- When: `getUserPosts()`를 호출한다.
- Then: 나중에 저장한 글이 먼저 나온다.

## P2: 회귀 방지 시나리오

### 15. product catalog와 price stats의 지원 상품 목록이 동기화된다

- 대상: `backend/app/services/catalog_service.py`
- 추천 테스트 파일: `backend/tests/test_price_api.py`
- 현재 상태: 존재
- Given: `/api/v1/products`가 지원 상품을 반환한다.
- When: 각 product의 `/price-stats?region=cairo`를 호출한다.
- Then: 모든 상품이 `200`과 `currency == EGP`를 반환한다.

### 16. Supabase row mapping은 숫자 문자열을 float/int로 안전하게 변환한다

- 대상: `backend/app/services/catalog_service.py`
- 추천 테스트 파일: `backend/tests/test_price_api.py`
- 현재 상태: 존재
- Given: Supabase fake row의 가격 필드가 문자열이다.
- When: `load_price_stats()`를 호출한다.
- Then: `avg_price`, `sample_count`가 API 모델 타입에 맞게 변환된다.

### 17. 설정 생성 스크립트는 backend-only secret을 Flutter로 복사하지 않는다

- 대상: `scripts/generate_flutter_defines.py`
- 추천 테스트 파일: `backend/tests/test_config_generation.py`
- 현재 상태: 존재
- Given: `.env`에 `SUPABASE_SERVICE_ROLE_KEY`가 있다.
- When: Flutter define 파일을 생성한다.
- Then: `TRUEPRICE_API_BASE_URL`만 포함하고 service role key는 제외한다.

### 18. 가격 결과 음성 문구는 verdict별 핵심 메시지를 포함한다

- 대상: `frontend/flutter_app/lib/core/utils/price_result_speech.dart`
- 추천 테스트 파일: `frontend/flutter_app/test/price_result_speech_test.dart`
- 현재 상태: 존재
- Given: fair/negotiable/overpriced comparison이 있다.
- When: speech text를 생성한다.
- Then: verdict별 행동 메시지가 포함된다.

### 19. 임시 이미지 파일 삭제 후에도 ScanEvent equality가 안전하다

- 대상: `frontend/flutter_app/lib/features/scan/presentation/bloc/scan_event.dart`
- 추천 테스트 파일: `frontend/flutter_app/test/scan_event_test.dart`
- 현재 상태: 존재
- Given: event 생성 후 원본 temp file이 삭제된다.
- When: `event.props`를 읽는다.
- Then: file stat 접근 없이 path 기반 props를 반환한다.

### 20. ML 데이터셋 생성 script는 camel_doll label을 유지한다

- 대상: `ml/scripts/build_camel_plush_bootstrap_yolo.py`
- 추천 테스트 파일: `ml/tests/test_build_camel_plush_bootstrap_yolo.py`
- 현재 상태: 존재
- Given: camel plush source image/annotation fixture가 있다.
- When: YOLO dataset builder를 실행한다.
- Then: class id와 `camel_doll` label이 유지된다.

## 바로 추가하면 좋은 테스트 5개

| 우선 | 테스트 | 이유 |
|---|---|---|
| 1 | `price_classifier_test.dart` | Flutter 화면/문구/색상 판정의 기준점 |
| 2 | `backend/tests/test_price_matcher.py` | Backend 판정과 Flutter 판정 불일치 방지 |
| 3 | `scan_repository_test.dart` | 앱-Backend detection contract 깨짐 방지 |
| 4 | `scan_bloc_test.dart` | 스캔 실패 demo-safe UI 보장 |
| 5 | `camel_ride_price_input_test.dart` | 현재 MVP 차별 흐름인 Camel Ride 회귀 방지 |

## 적용 방법

```bash
cd frontend/flutter_app
flutter test

cd ../../backend
python3 -m pytest
```

새 테스트를 추가할 때는 실제 API/YOLO/Supabase를 호출하지 말고 fake repository, fake Dio adapter, monkeypatch를 사용합니다. 실제 서버 연동은 `price_repository_backend_test.dart`처럼 명시적으로 skip 가능한 integration test로 분리합니다.
