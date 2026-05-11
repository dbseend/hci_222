#!/usr/bin/env python3
"""
Build a YOLO object-detection dataset for fruit MVP training.

Current automated source:
- Dataset Ninja Tomato Detection mirror, Supervisely format, CC0.

Manual/future sources:
- Roboflow cherry tomato exports can be merged later with the same class order.
- Existing Wikimedia fruit images are kept as unlabeled review material.
"""

from __future__ import annotations

import json
import random
import shutil
from dataclasses import dataclass
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
TOMATO_RAW = ROOT / "dataset_sources" / "external_raw" / "tomato_detection" / "ds0"
OUT = ROOT / "dataset_sources" / "fruit_detection_yolo"

CLASSES = ["tomato", "cherry_tomato", "other_fruit"]
SPLIT_RATIOS = {"train": 0.7, "valid": 0.2, "test": 0.1}
SEED = 222


@dataclass(frozen=True)
class ImageRecord:
    image_path: Path
    ann_path: Path


def reset_output() -> None:
    if OUT.exists():
        shutil.rmtree(OUT)
    for split in SPLIT_RATIOS:
        (OUT / split / "images").mkdir(parents=True, exist_ok=True)
        (OUT / split / "labels").mkdir(parents=True, exist_ok=True)
    (OUT / "unlabeled_review").mkdir(parents=True, exist_ok=True)
    (OUT / "metadata").mkdir(parents=True, exist_ok=True)


def load_tomato_records() -> list[ImageRecord]:
    image_dir = TOMATO_RAW / "img"
    ann_dir = TOMATO_RAW / "ann"
    if not image_dir.exists() or not ann_dir.exists():
        raise FileNotFoundError(
            f"Missing Tomato Detection raw data at {TOMATO_RAW}. "
            "Download/extract tomato-detection-DatasetNinja.tar first."
        )

    records: list[ImageRecord] = []
    for image_path in sorted(image_dir.glob("*")):
        if image_path.suffix.lower() not in {".jpg", ".jpeg", ".png", ".webp"}:
            continue
        ann_path = ann_dir / f"{image_path.name}.json"
        if ann_path.exists():
            records.append(ImageRecord(image_path=image_path, ann_path=ann_path))
    return records


def split_records(records: list[ImageRecord]) -> dict[str, list[ImageRecord]]:
    shuffled = records[:]
    random.Random(SEED).shuffle(shuffled)
    total = len(shuffled)
    train_end = int(total * SPLIT_RATIOS["train"])
    valid_end = train_end + int(total * SPLIT_RATIOS["valid"])
    return {
        "train": shuffled[:train_end],
        "valid": shuffled[train_end:valid_end],
        "test": shuffled[valid_end:],
    }


def supervisely_to_yolo_lines(ann_path: Path) -> list[str]:
    ann = json.loads(ann_path.read_text(encoding="utf-8"))
    width = float(ann["size"]["width"])
    height = float(ann["size"]["height"])
    lines: list[str] = []

    for obj in ann.get("objects", []):
        if obj.get("classTitle") != "tomato":
            continue
        exterior = obj.get("points", {}).get("exterior", [])
        if len(exterior) != 2:
            continue
        (x1, y1), (x2, y2) = exterior
        x_min = max(0.0, min(float(x1), float(x2)))
        y_min = max(0.0, min(float(y1), float(y2)))
        x_max = min(width, max(float(x1), float(x2)))
        y_max = min(height, max(float(y1), float(y2)))
        box_w = x_max - x_min
        box_h = y_max - y_min
        if box_w <= 1 or box_h <= 1:
            continue

        cx = (x_min + x_max) / 2.0 / width
        cy = (y_min + y_max) / 2.0 / height
        bw = box_w / width
        bh = box_h / height
        lines.append(f"0 {cx:.6f} {cy:.6f} {bw:.6f} {bh:.6f}")
    return lines


def convert_tomato_dataset() -> dict:
    records = load_tomato_records()
    split_map = split_records(records)
    stats = {
        "source": "Dataset Ninja Tomato Detection",
        "license": "CC0 1.0",
        "total_images": len(records),
        "total_boxes": 0,
        "splits": {},
    }

    for split, split_records_ in split_map.items():
        split_boxes = 0
        for record in split_records_:
            dest_image = OUT / split / "images" / record.image_path.name
            dest_label = OUT / split / "labels" / f"{record.image_path.stem}.txt"
            shutil.copy2(record.image_path, dest_image)
            lines = supervisely_to_yolo_lines(record.ann_path)
            split_boxes += len(lines)
            dest_label.write_text("\n".join(lines) + ("\n" if lines else ""), encoding="utf-8")
        stats["splits"][split] = {
            "images": len(split_records_),
            "boxes": split_boxes,
        }
        stats["total_boxes"] += split_boxes
    return stats


def copy_unlabeled_review_images() -> dict:
    source_root = ROOT / "dataset_sources" / "images"
    review_classes = ["cherry_tomato", "other_fruit"]
    counts = {}
    for class_name in review_classes:
        src = source_root / class_name
        dst = OUT / "unlabeled_review" / class_name
        dst.mkdir(parents=True, exist_ok=True)
        copied = 0
        if src.exists():
            for path in sorted(src.glob("*")):
                if path.suffix.lower() not in {".jpg", ".jpeg", ".png", ".webp"}:
                    continue
                shutil.copy2(path, dst / path.name)
                copied += 1
        counts[class_name] = copied
    return counts


def write_yaml() -> None:
    names = "[" + ", ".join(f"'{name}'" for name in CLASSES) + "]"
    content = f"""path: {OUT}
train: train/images
val: valid/images
test: test/images

nc: {len(CLASSES)}
names: {names}
"""
    (OUT / "data.yaml").write_text(content, encoding="utf-8")


def write_readme(stats: dict, unlabeled_counts: dict) -> None:
    readme = f"""# Fruit Detection YOLO Dataset

## Status

This folder is a YOLO-ready dataset scaffold for the fruit MVP.

Currently train-ready:

- `tomato`: {stats["total_images"]} images, {stats["total_boxes"]} bounding boxes, CC0.

Not yet train-ready:

- `cherry_tomato`: Roboflow export or manual labels still required.
- `other_fruit`: manual labels still required.

## Split

| split | images | boxes |
| --- | ---: | ---: |
| train | {stats["splits"]["train"]["images"]} | {stats["splits"]["train"]["boxes"]} |
| valid | {stats["splits"]["valid"]["images"]} | {stats["splits"]["valid"]["boxes"]} |
| test | {stats["splits"]["test"]["images"]} | {stats["splits"]["test"]["boxes"]} |

## Class Order

```text
0 tomato
1 cherry_tomato
2 other_fruit
```

## Unlabeled Review Images

These are copied from the earlier license-filtered web collection for later Roboflow labeling:

| class | count |
| --- | ---: |
| cherry_tomato | {unlabeled_counts.get("cherry_tomato", 0)} |
| other_fruit | {unlabeled_counts.get("other_fruit", 0)} |

## Next Step

For MVP, import this folder into Roboflow, then import/fork a Roboflow cherry tomato dataset and map its classes into `cherry_tomato`.
"""
    (OUT / "README.md").write_text(readme, encoding="utf-8")


def main() -> int:
    reset_output()
    stats = convert_tomato_dataset()
    unlabeled_counts = copy_unlabeled_review_images()
    write_yaml()
    summary = {
        "classes": CLASSES,
        "tomato_detection": stats,
        "unlabeled_review": unlabeled_counts,
        "output": str(OUT),
    }
    (OUT / "metadata" / "summary.json").write_text(
        json.dumps(summary, indent=2, ensure_ascii=False), encoding="utf-8"
    )
    write_readme(stats, unlabeled_counts)
    print(json.dumps(summary, indent=2, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
