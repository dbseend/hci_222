# YOLO On-Device MVP Plan

## 1. Core Decision

Use on-device YOLO for object recognition.

Backend is no longer responsible for YOLO inference. Backend owns product metadata, regional price data, user price comparison, scan logs, and community posts.

Target MVP:

```text
Camera capture
-> on-device YOLO inference
-> product confirmation
-> user price input
-> backend price comparison
-> result UI
```

Final presentation target:

```text
Primary device: iPhone
Secondary MVP test: Android
Inference mode: captured photo only
Network: available
Latency target: <= 2 seconds from photo capture to detection result
```

## 2. Detection Scope

Only two classes are in scope for the first model:

```yaml
names:
  0: tomato
  1: camel_doll
```

Do not include OCR in this phase.

Do not detect price tags in this phase.

Do not run realtime camera preview detection in this phase.

## 3. Class Definitions

### tomato

Definition:

```text
A single whole tomato photographed as an individual product.
```

Include:

```text
- Red tomato
- Orange tomato
- Slightly unripe tomato
- Tomato with stem/calyx
- Tomato held by hand
- Tomato on table, plate, shelf, or market stand
```

Exclude:

```text
- Cut tomato
- Cooked tomato
- Tomato sauce
- Tomato printed on packaging
- Tomato bunch labeled as one large pile
```

Labeling rule:

```text
Draw bbox around one tomato.
If multiple tomatoes appear, label each visible tomato separately.
Exclude hand, table, tray, bag, price tag, and background.
If partly occluded, label only the visible tomato area.
```

Important negative examples:

```text
- Apple
- Onion
- Potato
- Orange
- Red ball
- Red toy
- Other red round objects
```

### camel_doll

Definition:

```text
A single camel-shaped souvenir, doll, ornament, or small decorative product.
It must be an object sold as a product, not a real camel or a printed camel image.
```

Include:

```text
- Stuffed camel doll
- Fabric camel souvenir
- Wooden camel ornament
- Plastic camel ornament
- Metal camel ornament
- Keychain-sized camel souvenir if the camel shape is clear
- Camel doll held by hand
- Camel doll on a shelf or market stand
```

Exclude:

```text
- Real camel
- Camel drawing only
- Camel printed on shirt, cup, poster, bag, or packaging
- Background camel figure too small to recognize
- Cluster of dolls where individual objects cannot be separated
```

Labeling rule:

```text
Draw bbox around the whole camel product.
Include head, neck, humps, body, legs, and tail if visible.
Exclude hand, shelf, tag, string, shadow, and background.
If partly occluded, label only the visible object area.
If multiple camel dolls appear and each is separable, label each one separately.
```

Required variations:

```text
- Front view
- Side view
- 45-degree view
- Bright light
- Dim light
- Hand-held photo
- Shelf/market display photo
- Clean background
- Busy market background
- Brown/beige doll
- Colorful patterned doll
- Small souvenir
- Medium doll
```

## 4. Dataset Requirements

Recommended MVP dataset:

| Class | Minimum | Recommended |
| --- | ---: | ---: |
| tomato | 80-120 images | 200-500 images |
| camel_doll | 80-120 images | 200-500 images |
| negative/background | 50 images | 100-200 images |

Split:

```text
train: 70%
val: 20%
test: 10%
```

Folder layout:

```text
datasets/trueprice_yolo/
  images/
    train/
    val/
    test/
  labels/
    train/
    val/
    test/
  data.yaml
  README.md
```

`data.yaml`:

```yaml
path: datasets/trueprice_yolo
train: images/train
val: images/val
test: images/test

names:
  0: tomato
  1: camel_doll
```

YOLO label format:

```text
class_id x_center y_center width height
```

Coordinates are normalized to image width/height and must be between `0` and `1`.

## 5. Data Collection Checklist

For each class, collect images across:

```text
- Different distances: close / medium
- Different angles: front / side / 45-degree / top-ish
- Different lighting: daylight / indoor / shadow
- Different backgrounds: plain / market / table / hand-held
- Different phones if possible
- Different image orientations
```

Avoid dataset bias:

```text
- Do not capture every tomato on the same table.
- Do not capture every camel doll from the same angle.
- Do not use only clean backgrounds.
- Include confusing non-target objects as negatives.
```

Image naming convention:

```text
tomato_0001.jpg
tomato_0002.jpg
camel_doll_0001.jpg
negative_market_0001.jpg
```

## 6. Label QA Checklist

Before training, manually review labels:

```text
- No missing labels for visible target objects.
- No bbox includes too much background.
- No bbox cuts off large visible object parts.
- No wrong class IDs.
- No duplicate labels on the same object.
- Negative images have empty label files or no label files, depending on the labeling tool export.
- train/val/test contain visually different images, not near-duplicates.
```

Reject an image if:

```text
- Target object is too blurry.
- Target object is too small.
- Object identity is ambiguous.
- Multiple objects are inseparable.
- The image is not representative of the demo or service scenario.
```

## 7. Model Strategy

Primary model:

```text
YOLO11n detect
```

Reason:

```text
- Smallest practical YOLO11 detection model
- Good mobile MVP starting point
- Two-class custom detection should be lightweight
```

Initial training/export settings:

```text
imgsz: 320
classes: tomato, camel_doll
format: TFLite INT8 for Flutter MVP
optional iPhone path: CoreML
```

If accuracy is weak:

```text
1. Improve labels and add more images.
2. Increase imgsz from 320 to 416.
3. Try YOLO11s only if YOLO11n is clearly insufficient.
```

Do not start with YOLO11s unless needed. It increases mobile inference cost.

## 8. Training Commands

Install training dependencies in the training environment:

```bash
pip install -U ultralytics
```

Train:

```bash
yolo detect train \
  model=yolo11n.pt \
  data=datasets/trueprice_yolo/data.yaml \
  epochs=80 \
  imgsz=320 \
  batch=16 \
  name=trueprice_yolo11n_320_v1
```

Validate:

```bash
yolo detect val \
  model=runs/detect/trueprice_yolo11n_320_v1/weights/best.pt \
  data=datasets/trueprice_yolo/data.yaml \
  imgsz=320
```

Predict sanity check:

```bash
yolo detect predict \
  model=runs/detect/trueprice_yolo11n_320_v1/weights/best.pt \
  source=datasets/trueprice_yolo/images/test \
  imgsz=320 \
  conf=0.35
```

Export TFLite INT8:

```bash
yolo export \
  model=runs/detect/trueprice_yolo11n_320_v1/weights/best.pt \
  format=tflite \
  imgsz=320 \
  int8=True
```

Optional iPhone/CoreML export:

```bash
yolo export \
  model=runs/detect/trueprice_yolo11n_320_v1/weights/best.pt \
  format=coreml \
  imgsz=320
```

## 9. Acceptance Criteria

Dataset acceptance:

```text
- At least 80 labeled images per class.
- At least 50 negative/background images.
- No critical label mistakes in manual QA sample.
- Test set contains photos not visually duplicated from train set.
```

Model acceptance:

```text
- Demo objects are detected in normal lighting.
- Wrong class prediction is rare in the prepared demo scenario.
- Confidence for demo tomato/camel_doll is usually >= 0.60.
- False positive on obvious negative image is low.
```

App acceptance:

```text
- Capture -> detection result <= 2 seconds.
- Detection result includes product name and confidence.
- If confidence < threshold, app asks user to choose product manually.
- If no detection, app shows retry/gallery/manual selection path.
```

Recommended confidence logic:

```text
confidence >= 0.60: accept and show confirmation
0.35 <= confidence < 0.60: show "maybe" confirmation
confidence < 0.35: treat as no reliable detection
```

## 10. Flutter App Architecture

Target flow:

```text
ScanScreen
  -> capture photo
  -> OnDeviceDetector.detect(imagePath)
  -> DetectionResult
  -> PriceStatsScreen / confirmation step
  -> PriceInputScreen
  -> backend price compare
```

Expected Flutter files:

```text
assets/models/trueprice_yolo.tflite
assets/models/labels.txt
lib/features/scan/data/services/on_device_detector.dart
lib/features/scan/data/repositories/scan_repository.dart
lib/features/scan/data/models/detection_result.dart
lib/features/scan/presentation/screens/scan_screen.dart
```

Expected Flutter dependencies:

```yaml
tflite_flutter: compatible_version
image: compatible_version
```

Add assets later:

```yaml
flutter:
  assets:
    - assets/data/
    - assets/models/
```

Inference mode:

```text
Photo capture only.
No realtime preview detection.
No OCR.
No server-side YOLO call.
```

## 11. Backend Role

Backend responsibilities after moving YOLO on-device:

```text
- Product catalog
- Regional price statistics
- Price comparison verdict
- Scan history sync if needed
- Community post creation
- Optional analytics/logging
```

Backend no longer owns:

```text
- YOLO model loading
- Image upload for detection
- Object detection inference
- OCR
```

Recommended endpoints:

```http
GET /api/v1/products
GET /api/v1/products/{product_id}/price-stats?region=cairo
POST /api/v1/price/compare
POST /api/v1/scans
POST /api/v1/community-posts
```

`POST /api/v1/price/compare` request:

```json
{
  "product_id": "tomato",
  "region": "cairo",
  "user_price": 25,
  "currency": "EGP"
}
```

Response:

```json
{
  "product_id": "tomato",
  "display_name": "Tomato",
  "region": "cairo",
  "user_price": 25,
  "avg_price": 20,
  "min_price": 15,
  "max_price": 28,
  "verdict": "negotiable",
  "message": "Slightly above the local average."
}
```

MVP backend data files:

```text
backend/app/data/product_catalog.json
backend/app/data/price_stats.json
```

`product_catalog.json`:

```json
[
  {
    "product_id": "tomato",
    "display_name": "Tomato",
    "unit": "kg",
    "aliases": ["tomato", "tomatoes"]
  },
  {
    "product_id": "camel_doll",
    "display_name": "Camel Doll",
    "unit": "piece",
    "aliases": ["camel doll", "camel souvenir"]
  }
]
```

`price_stats.json`:

```json
[
  {
    "product_id": "tomato",
    "region": "cairo",
    "currency": "EGP",
    "avg_price": 20,
    "min_price": 15,
    "max_price": 28
  },
  {
    "product_id": "camel_doll",
    "region": "cairo",
    "currency": "EGP",
    "avg_price": 120,
    "min_price": 80,
    "max_price": 180
  }
]
```

## 12. Implementation Order

### Phase 1: Dataset

```text
1. Confirm class definitions.
2. Capture initial images.
3. Label images in YOLO format.
4. Split train/val/test.
5. Run label QA.
```

Done when:

```text
- data.yaml exists.
- Each class has minimum image count.
- Test images are reserved and not reused for training.
```

### Phase 2: Model

```text
1. Train YOLO11n at imgsz=320.
2. Validate.
3. Run prediction sanity check on test images.
4. Export TFLite INT8.
5. Test exported model output on sample images.
```

Done when:

```text
- best.pt exists.
- .tflite export exists.
- Demo tomato and camel doll are detected.
```

### Phase 3: Flutter Integration

```text
1. Add tflite_flutter and image dependencies.
2. Add model and labels assets.
3. Implement OnDeviceDetector.
4. Wire ScanScreen capture result into detector.
5. Map YOLO class to DetectionResult.
6. Add low-confidence/manual fallback UI.
```

Done when:

```text
- Photo capture returns tomato/camel_doll result.
- No internet is needed for detection.
- Detection completes within 2 seconds on iPhone.
```

### Phase 4: Backend Rework

```text
1. Remove YOLO inference from backend plan.
2. Implement product catalog endpoint.
3. Implement price stats endpoint.
4. Implement price compare endpoint.
5. Connect Flutter price flow to backend.
```

Done when:

```text
- App sends product_id and price.
- Backend returns verdict.
- UI displays comparison result.
```

### Phase 5: Demo Hardening

```text
1. Prepare fixed tomato and camel doll demo objects.
2. Capture test photos using final iPhone.
3. Measure capture -> detection latency.
4. Tune confidence threshold.
5. Add manual fallback for failure case.
6. Prepare offline model and online price API demo path.
```

Done when:

```text
- Tomato demo works 5/5 times.
- Camel doll demo works 5/5 times.
- Failure state is presentable.
- Full flow completes within 2 seconds to detection result.
```

## 13. Open Decisions

Need final confirmation before implementation:

```text
1. Use TFLite only for both Android and iPhone, or add CoreML path for iPhone presentation?
2. Use imgsz=320 first, or start at 416 for safer accuracy?
3. Store scan history locally only, or sync scans to backend?
4. Are price stats fixed mock data for presentation, or editable backend data?
```

Recommended defaults:

```text
1. Start with TFLite only.
2. Start with imgsz=320.
3. Keep scan history local for MVP.
4. Use fixed backend JSON price stats for presentation.
```

## 14. References

- Ultralytics YOLO documentation: https://docs.ultralytics.com/
- Ultralytics YOLO11 model table: https://huggingface.co/Ultralytics/YOLO11
- Ultralytics export documentation: https://github.com/ultralytics/ultralytics/blob/main/docs/en/modes/export.md
