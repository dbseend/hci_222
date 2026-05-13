# TruePrice YOLO Training Plan

## Core Judgment

Use the existing trained YOLO model as the baseline:

```text
backend/models/best.pt
```

Current model classes:

```text
tomato, apple, avocado, blueberry, cherry, kiwi, mango, orange, rockmelon, strawberry
```

Do not replace this with zero-shot for normal demos. Add the missing MVP classes
through additional data and fine-tuning:

```text
cherry_tomato
camel_doll
```

`banana` exists in the API catalog for price-flow compatibility, but it is not in
the current YOLO model and should not be expected until a banana dataset is added.

## Dataset Strategy

### Use Existing / Public Data

- Keep the current open fruit dataset pipeline for the already-covered fruit
  classes.
- Use a Roboflow Universe cherry tomato dataset/export for `cherry_tomato`.
- Remap any ripeness labels such as `ripe`, `semi-ripe`, `unripe`,
  `fully_ripened`, or `green` into a single product class: `cherry_tomato`.

Candidate public cherry tomato datasets found during review:

```text
https://universe.roboflow.com/fyp-tbowm/cherry-tomato-detection
https://universe.roboflow.com/tomatoes-4icwf/cherry-tomatoes-ncnxo
https://universe.roboflow.com/tomato-hvsze/cherry-tomato-frphf
```

Prefer exports that provide YOLOv8/YOLOv11/YOLO26 text labels and a permissive
license such as CC BY 4.0.

### Collect Directly

Wikimedia collection for camel plush returned no usable images in the current
run, so collect `camel_doll` manually.

Minimum manual capture target:

```text
camel_doll: 80 images
```

Better target:

```text
camel_doll: 120-200 images
```

Capture variation:

```text
front, side, back, tilted
plain table, shelf, hand-held, market-like background
close-up, mid distance
bright light, indoor light, shadows
partial occlusion
```

For MVP labeling, draw one bounding box around the whole doll.

## Class Schema

Final training class order should stay stable:

```yaml
names:
  0: tomato
  1: apple
  2: avocado
  3: blueberry
  4: cherry
  5: kiwi
  6: mango
  7: orange
  8: rockmelon
  9: strawberry
  10: cherry_tomato
  11: camel_doll
```

Keep this order aligned with `backend/app/services/object_detector.py`.

## Workflow

1. Build or refresh the current open fruit dataset:

```bash
python3 ml/scripts/build_open_fruit_camel_dataset.py
```

2. Export a cherry tomato dataset from Roboflow in YOLO format.

3. Merge/remap the cherry tomato export into the local training workspace.

```bash
python3 ml/scripts/merge_roboflow_yolo_export.py /path/to/cherry-tomato-yolo.zip --source-name cherry_tomato_public
```

4. Capture and label camel doll images in Roboflow, CVAT, or LabelImg.

5. Export camel doll labels in YOLO format and place them under:

```text
dataset_sources/camel_doll_yolo/
  train/images/
  train/labels/
  valid/images/
  valid/labels/
  test/images/
  test/labels/
  data.yaml
```

6. Train with a pretrained YOLO base model.

```bash
python3 ml/scripts/train_trueprice_yolo.py \
  --preset combined_mvp \
  --model yolo11n.pt \
  --epochs 80 \
  --imgsz 640 \
  --batch 16 \
  --device mps
```

7. Copy the trained artifact into the backend:

```bash
cp runs/trueprice/combined_mvp/weights/best.pt backend/models/best.pt
```

8. Run the backend in YOLO mode:

```bash
TRUEPRICE_DETECTOR_MODE=yolo
TRUEPRICE_YOLO_MODEL_PATH=backend/models/best.pt
uvicorn app.main:app --host 0.0.0.0 --port 8000
```

## Acceptance Criteria

- Existing fruit classes still detect after fine-tuning.
- `tomato` and `cherry_tomato` are not confused in at least 5 phone photos each.
- `camel_doll` is detected in at least 5 phone photos with confidence >= 0.50.
- API response product IDs match catalog IDs:

```text
tomato
cherry_tomato
camel_doll
```

