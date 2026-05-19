# Current Server YOLO Model Snapshot - 2026-05-19

This snapshot records the server-side detection setup before migrating the MVP
toward a mobile-friendly TFLite model.

## Runtime Configuration

The active local backend configuration uses YOLO mode:

```text
TRUEPRICE_DETECTOR_MODE=yolo
TRUEPRICE_YOLO_MODEL_PATH=backend/models/best.pt
TRUEPRICE_YOLO_EXTRA_MODEL_PATHS=backend/models/best_camel_doll_only.pt
```

`backend/app/services/object_detector.py` loads the primary model and every
extra model, runs inference for each model, and returns the highest-confidence
supported detection.

## Active Model Files

```text
backend/models/best.pt                  5.2 MB
backend/models/best_camel_doll_only.pt 20.2 MB
```

The backend therefore performs two YOLO inferences per uploaded scan image when
the extra model path is configured.

## Model Metadata

`backend/models/best.pt`

```text
Architecture: YOLO11n detect
Training image size: 640
Classes: apple, banana, grape, mango, strawberry, camel_doll
```

`backend/models/best_camel_doll_only.pt`

```text
Architecture: YOLO11n detect
Training image size: 416
Classes: camel_doll
```

## Local Dataset

The current local YOLO dataset is:

```text
dataset/trueprice_yolo_local/data.yaml
```

Its classes are:

```text
apple, banana, grape, mango, strawberry, camel_doll
```

This dataset can be reused for TFLite INT8 calibration/export for the same
6-class model. It does not contain `tomato`, so tomato detection requires adding
tomato images and labels before retraining.
