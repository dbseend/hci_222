# YOLO 모델 v2 개선 리포트 (2026-11-08)

대상 클래스는 기존과 동일: `apple, banana, grape, mango, strawberry, camel_doll` (클래스 순서 동일).
`backend/models/best.pt`를 v2로 교체했고, 기존 모델은 `backend/models/best_v1_backup.pt`(git 미추적)로 보관.

## 원인 진단

- v1은 분류용 과일 데이터셋에 **이미지 90% 크기의 가짜 박스**를 씌워 학습 → 사실상 분류기. 박스 면적 평균 0.93~0.98.
- 낙타 인형은 팀 자체 사진(배경이 단조로움)으로만 학습 → 처음 보는 배경의 과일을 대거 `camel_doll`로 예측
  (독립 평가 136장 중 62장이 `camel_doll` 오인식).

## 개선 계획 / 실행

1. **독립 평가셋 고정**: Wikimedia Commons(CC/PD) 클래스별 25장, camel 11장 (`ml/tools/fetch_commons_eval_set.py`).
   학습 데이터와 average-hash로 중복 제거.
2. **실제 박스 데이터**: Open Images V7(이미지 CC BY 2.0, 박스 CC BY 4.0)에서 5개 과일 박스를 가져옴.
   train 2,092장(클래스당 최대 500장), val 184장, test 614장.
3. **camel_doll**: Openverse(CC0/BY/BY-SA/PD)에서 낙타 장난감·인형·조각상 후보 186장 수집 →
   사람이 눈으로 48장 선별 → YOLO-World("camel") 박스 생성 → 39장 사용 (train 23 / val 16).
   v1 모델의 자체 예측은 박스·클래스 모두 노이즈가 커서 라벨로 쓰지 않음.
4. **불균형 보정**: mango ×3, camel_doll ×4 오버샘플링 (`train.txt` 반복).
5. **학습**: v1 가중치에서 파인튜닝(기존 camel 지식 유지 목적), YOLO11n, 640px, 50 epoch(49 완료),
   Apple M4 MPS, 약 2.2시간.

재현:

```bash
python3 -I ml/tools/fetch_commons_eval_set.py datasets/eval_commons 25 apple,banana,grape,mango,strawberry,camel_doll
python3 -I ml/scripts/collect_openverse_images.py datasets/openverse_camel "camel toy" "stuffed camel" "camel plush"
# datasets/camel_curated.txt 에 선별한 이미지 경로 기록 (수작업)
.venv/bin/python ml/scripts/build_openimages_fruit_camel_yolo.py
.venv/bin/yolo detect train model=backend/models/best_v1_backup.pt data=datasets/trueprice_oi_v2/data.yaml epochs=50 imgsz=640 batch=16 device=mps
.venv/bin/python ml/tools/eval_independent.py datasets/eval_commons out.md 0.25 <model.pt>
```

Open Images 박스 CSV(`datasets/openimages/meta/`)는 `ml/scripts/build_openimages_fruit_camel_yolo.py` 상단 docstring 참고.

## 결과

### 독립 평가셋 (Wikimedia, 이미지 단위 top-1, conf ≥ 0.25)

| class | v1 | v2 |
|---|---|---|
| apple | 44% | **80%** |
| banana | 44% | **84%** |
| grape | 36% | **80%** |
| mango | 60% | **76%** |
| strawberry | 24% | **84%** |
| camel_doll | **91%** (10/11) | 73% (8/11) |
| **전체** | **46%** (62/136) | **80%** (109/136) |
| 과일→camel_doll 오인식 | 62장 | 3장 |

### Open Images test split (614장, 실제 박스)

| | v1 | v2 |
|---|---|---|
| mAP50 | 0.109 | **0.430** |
| mAP50-95 | 0.057 | **0.323** |

### 서버 지연시간 (로컬 Mac, `/scan/detect-object`, 45회)

v1 중앙값 32 ms → v2 중앙값 28 ms / p95 29 ms (같은 YOLO11n 구조라 차이 없음).

### camel_doll 웹 사진 추가 검증 (실물 인형 확보 불가로 대체)

Openverse 신규 검색어 + Commons `Category:Toy camels`에서 학습·평가셋과 중복 제거 후 새 인형 사진 3장을 확보(공개 라이선스 사진은 사실상 소진).
기존 평가 11장 + 신규 3장 = 낙타 인형 14장, 같은 수집에서 나온 비-낙타 사진 12장(알파카, 인형, 모자 등)으로 오탐 확인.

| | v1 | v2 |
|---|---|---|
| 낙타 인형 → camel_doll (재현율) | 11/14 | 9/14 |
| 비-낙타 → camel_doll (오탐) | **7/12** | **3/12** |

v1의 높은 camel 점수는 "뭐든 camel_doll로 예측"하는 편향 때문(과일 오인식 62장과 같은 원인).
v2에 TTA(`augment=True`)·conf 0.15를 적용해도 10/14·오탐 2/12로 개선 폭이 작고 지연이 2~3배라 적용하지 않음.

## 한계 / 주의

- **camel_doll 재현율 약 64~73%**: 실물 인형은 확보 불가, 웹 사진으로만 검증. 표본이 14장이라 오차가 큼.
  공개 라이선스 웹 사진이 바닥나 추가 학습으로 개선할 데이터가 없음. 인형을 확보하면 실물 사진 30~50장으로 재학습하는 것이 가장 효과적.
- 바나나·포도는 이제 정확히 인식되지만 가격 카탈로그(`SUPPORTED_PRODUCT_IDS`)에 없어서 서버가 404를 반환하고,
  앱은 "Product not recognized"로 표시함 (모델 문제가 아님).
- 독립 평가셋 출처·라이선스: [`docs/eval_image_sources.csv`](eval_image_sources.csv).
- 학습 데이터 저작자 표기는 각 manifest(`datasets/*/manifest*.csv`)와 Open Images 이미지 ID로 추적 가능 (데이터는 git 미포함).
- 되돌리기: `cp backend/models/best_v1_backup.pt backend/models/best.pt`
