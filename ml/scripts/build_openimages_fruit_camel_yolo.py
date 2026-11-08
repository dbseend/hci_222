#!/usr/bin/env python3
"""Build a 6-class YOLO dataset with real boxes for the current server classes.

Classes (same order as backend/models/best.pt):
0 apple, 1 banana, 2 grape, 3 mango, 4 strawberry, 5 camel_doll

Inputs (local-only, see ml/README.md):
- datasets/openimages/meta/train-fruit-bbox.csv  (train rows for the 5 fruit MIDs)
- datasets/openimages/meta/{validation,test}-annotations-bbox.csv
- datasets/camel_curated.txt: hand-reviewed camel toy/figurine image paths
  (collected with collect_openverse_images.py)
- datasets/eval_commons/<class>/*.jpg (independent eval set, excluded from training)

Fruit boxes come from Open Images (images CC BY 2.0, boxes CC BY 4.0).
camel_doll boxes come from the open-vocabulary YOLO-World detector prompted
with "camel"; the old model's own camel predictions were too noisy to reuse.

    .venv/bin/python ml/scripts/build_openimages_fruit_camel_yolo.py [--per-class 500]
"""

import argparse
import csv
import hashlib
import random
import sys
import urllib.request
from collections import defaultdict
from concurrent.futures import ThreadPoolExecutor
from io import BytesIO
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
META = ROOT / "datasets" / "openimages" / "meta"
CAMEL_LIST = ROOT / "datasets" / "camel_curated.txt"
EVAL_SET = ROOT / "datasets" / "eval_commons"
OUT = ROOT / "datasets" / "trueprice_oi_v2"
BOX_MODEL = ROOT / "datasets" / "yolov8s-worldv2.pt"

CLASS_NAMES = ["apple", "banana", "grape", "mango", "strawberry", "camel_doll"]
MID_TO_CLASS = {"/m/014j1m": 0, "/m/09qck": 1, "/m/0388q": 2, "/m/0fldg": 3, "/m/07fbm7": 4}
CAMEL_ID = 5
S3 = "https://open-images-dataset.s3.amazonaws.com/{split}/{image_id}.jpg"
SPLIT_SOURCES = {"train": "train", "val": "validation", "test": "test"}
# Rare classes are repeated in train.txt so each epoch sees them more often.
OVERSAMPLE = {3: 3, CAMEL_ID: 4}
MAX_SIDE = 800
SEED = 222


def read_boxes(path: Path, has_header: bool) -> dict[str, list[tuple[int, float, float, float, float]]]:
    boxes = defaultdict(list)
    with path.open() as f:
        reader = csv.reader(f)
        if has_header:
            next(reader)
        for row in reader:
            cls = MID_TO_CLASS.get(row[2])
            if cls is None:
                continue
            x_min, x_max, y_min, y_max = map(float, row[4:8])
            boxes[row[0]].append((cls, (x_min + x_max) / 2, (y_min + y_max) / 2, x_max - x_min, y_max - y_min))
    return boxes


def pick_images(boxes, per_class: int | None, rng: random.Random) -> list[str]:
    by_class = defaultdict(list)
    for image_id, items in sorted(boxes.items()):
        for cls in {item[0] for item in items}:
            by_class[cls].append(image_id)
    chosen: set[str] = set()
    for ids in by_class.values():
        rng.shuffle(ids)
        chosen.update(ids[:per_class] if per_class else ids)
    return sorted(chosen)


def average_hash(image: Image.Image) -> int:
    pixels = list(image.convert("L").resize((8, 8)).getdata())
    mean = sum(pixels) / len(pixels)
    return sum(1 << i for i, p in enumerate(pixels) if p > mean)


def is_near_duplicate(h: int, eval_hashes: list[int]) -> bool:
    return any(bin(h ^ other).count("1") <= 4 for other in eval_hashes)


def save_resized(image: Image.Image, path: Path) -> None:
    image = image.convert("RGB")
    image.thumbnail((MAX_SIDE, MAX_SIDE))
    image.save(path, quality=90)


def download(split: str, image_id: str, out_dir: Path) -> Image.Image | None:
    target = out_dir / f"{image_id}.jpg"
    if target.exists():
        return Image.open(target)
    url = S3.format(split=SPLIT_SOURCES[split], image_id=image_id)
    try:
        data = urllib.request.urlopen(url, timeout=30).read()
        image = Image.open(BytesIO(data))
        save_resized(image, target)
        return Image.open(target)
    except Exception as exc:
        print(f"skip {image_id}: {exc}", file=sys.stderr)
        return None


def write_labels(path: Path, rows) -> None:
    path.write_text("".join(f"{c} {x:.6f} {y:.6f} {w:.6f} {h:.6f}\n" for c, x, y, w, h in rows))


def build_fruit_split(split, boxes, ids, eval_hashes) -> list[tuple[Path, set[int]]]:
    image_dir, label_dir = OUT / "images" / split, OUT / "labels" / split
    image_dir.mkdir(parents=True, exist_ok=True)
    label_dir.mkdir(parents=True, exist_ok=True)
    with ThreadPoolExecutor(16) as pool:
        images = list(pool.map(lambda i: download(split, i, image_dir), ids))
    kept = []
    for image_id, image in zip(ids, images):
        if image is None:
            continue
        if is_near_duplicate(average_hash(image), eval_hashes):
            (image_dir / f"{image_id}.jpg").unlink()
            continue
        write_labels(label_dir / f"{image_id}.txt", boxes[image_id])
        kept.append((image_dir / f"{image_id}.jpg", {b[0] for b in boxes[image_id]}))
    print(f"{split}: {len(kept)} fruit images", flush=True)
    return kept


def build_camel(eval_hashes, min_conf: float) -> dict[str, list[tuple[Path, set[int]]]]:
    from ultralytics import YOLOWorld

    model = YOLOWorld(str(BOX_MODEL))
    model.set_classes(["camel", "camel toy"])
    result = {"train": [], "val": []}
    for line in CAMEL_LIST.read_text().splitlines():
        path = ROOT / line.strip()
        try:
            image = Image.open(path).convert("RGB")
        except Exception as exc:
            print(f"skip {path.name}: {exc}", file=sys.stderr)
            continue
        if is_near_duplicate(average_hash(image), eval_hashes):
            continue
        pred = model.predict(image, conf=min_conf, verbose=False, device="cpu")[0]
        rows = [(CAMEL_ID, *map(float, box.xywhn[0])) for box in pred.boxes]
        if not rows:
            print(f"no camel box: {path.name}", file=sys.stderr)
            continue
        split = "val" if int(hashlib.md5(path.stem.encode()).hexdigest(), 16) % 5 == 0 else "train"
        image_dir, label_dir = OUT / "images" / split, OUT / "labels" / split
        target = image_dir / f"camel_{path.stem}.jpg"
        save_resized(image, target)
        write_labels(label_dir / f"camel_{path.stem}.txt", rows)
        result[split].append((target, {CAMEL_ID}))
    print(f"camel_doll: {len(result['train'])} train, {len(result['val'])} val", flush=True)
    return result


def write_list(name: str, items, oversample: bool) -> None:
    lines = []
    for path, classes in items:
        repeat = max((OVERSAMPLE.get(c, 1) for c in classes), default=1) if oversample else 1
        lines += [str(path)] * repeat
    (OUT / f"{name}.txt").write_text("\n".join(lines) + "\n")


def main() -> int:
    parser = argparse.ArgumentParser(description="Build the 6-class Open Images + camel YOLO dataset.")
    parser.add_argument("--per-class", type=int, default=500, help="max train images per fruit class")
    parser.add_argument("--camel-conf", type=float, default=0.15)
    args = parser.parse_args()

    rng = random.Random(SEED)
    eval_hashes = [average_hash(Image.open(p)) for p in EVAL_SET.glob("*/*.jpg")]
    sources = {
        "train": read_boxes(META / "train-fruit-bbox.csv", has_header=False),
        "val": read_boxes(META / "validation-annotations-bbox.csv", has_header=True),
        "test": read_boxes(META / "test-annotations-bbox.csv", has_header=True),
    }
    splits = {}
    for split, boxes in sources.items():
        ids = pick_images(boxes, args.per_class if split == "train" else None, rng)
        splits[split] = build_fruit_split(split, boxes, ids, eval_hashes)
    camel = build_camel(eval_hashes, args.camel_conf)

    write_list("train", splits["train"] + camel["train"], oversample=True)
    write_list("val", splits["val"] + camel["val"], oversample=False)
    write_list("test", splits["test"], oversample=False)
    names = "\n".join(f"  {i}: {n}" for i, n in enumerate(CLASS_NAMES))
    (OUT / "data.yaml").write_text(
        f"path: {OUT}\ntrain: train.txt\nval: val.txt\ntest: test.txt\nnames:\n{names}\n"
    )
    print(f"wrote {OUT / 'data.yaml'}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
