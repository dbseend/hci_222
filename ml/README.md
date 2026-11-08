# ML Workspace

Dataset building and evaluation for the server detector `backend/models/best.pt`
(YOLO11n, classes `apple, banana, grape, mango, strawberry, camel_doll`).
Results and design decisions: [`docs/model_v2_report.md`](../docs/model_v2_report.md).

Downloaded images, generated datasets and training runs live in `datasets/` and
`runs/` at the repository root and are not committed.

## Layout

- `scripts/collect_openverse_images.py`: download CC0/CC BY/CC BY-SA camel toy candidates from Openverse
- `scripts/build_openimages_fruit_camel_yolo.py`: build the 6-class YOLO dataset
  (Open Images fruit boxes + hand-picked camel images boxed with YOLO-World)
- `tools/fetch_commons_eval_set.py`: download the independent Wikimedia Commons eval set
- `tools/eval_independent.py`: image-level accuracy of a model on that eval set
- `tests/`: unit tests for the dataset builder

## Reproduce

```bash
python3 -I ml/tools/fetch_commons_eval_set.py datasets/eval_commons 25
python3 -I ml/scripts/collect_openverse_images.py datasets/openverse_camel "camel toy" "stuffed camel" "camel plush"
# list the reviewed camel toy images in datasets/camel_curated.txt (manual step)
.venv/bin/python ml/scripts/build_openimages_fruit_camel_yolo.py
.venv/bin/yolo detect train model=yolo11n.pt data=datasets/trueprice_oi_v2/data.yaml epochs=50 imgsz=640 batch=16 device=mps
.venv/bin/python ml/tools/eval_independent.py datasets/eval_commons out.md 0.25 runs/detect/train/weights/best.pt
```

```bash
python3 -m pytest -q ml/tests
```
