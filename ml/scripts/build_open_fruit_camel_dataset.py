#!/usr/bin/env python3
"""
Build the new MVP object-detection dataset:

Classes:
0 fruit
1 camel_doll

Open train-ready fruit sources:
- Tomato Detection, CC0 1.0
- AgRobTomato, CC BY 4.0
- deepNIR Fruit Detection, CC BY 4.0

camel_doll is kept as an unlabeled review set because the currently available
open images are too sparse/noisy for automatic training.
"""

from __future__ import annotations

import json
import random
import shutil
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / "dataset_open_v1"
OUT = BASE / "yolo"
SEED = 222
CLASSES = ["fruit", "camel_doll"]

SPLITS = ["train", "valid", "test"]
SPLIT_RATIOS = {"train": 0.7, "valid": 0.2, "test": 0.1}

SOURCES = [
    {
        "name": "tomato_detection",
        "path": BASE / "raw" / "tomato_detection" / "ds0",
        "license": "CC0 1.0",
        "source_url": "https://datasetninja.com/tomato-detection",
        "mode": "single",
        "target_split": None,
        "include_classes": {"tomato"},
    },
    {
        "name": "agrobtomato",
        "path": BASE / "raw" / "agrobtomato" / "ds",
        "license": "CC BY 4.0",
        "source_url": "https://datasetninja.com/agrobtomato-dataset",
        "mode": "single",
        "target_split": None,
        "include_classes": {"breaking stage", "reddish", "riped", "unriped"},
    },
    {
        "name": "deepnir",
        "path": BASE / "raw" / "deepnir",
        "license": "CC BY 4.0",
        "source_url": "https://datasetninja.com/deepnir-fruit-detection",
        "mode": "pre_split",
        "include_classes": {
            "apple",
            "avocado",
            "blueberry",
            "cherry",
            "kiwi",
            "mango",
            "orange",
            "rockmelon",
            "strawberry",
        },
        "excluded_classes": {
            "wheat": "not a fruit target for this MVP",
            "capsicum": "consumer category is vegetable, excluded for product clarity",
        },
    },
]


def reset_output() -> None:
    if OUT.exists():
        shutil.rmtree(OUT)
    for split in SPLITS:
        (OUT / split / "images").mkdir(parents=True, exist_ok=True)
        (OUT / split / "labels").mkdir(parents=True, exist_ok=True)
    (OUT / "metadata").mkdir(parents=True, exist_ok=True)
    (OUT / "unlabeled_review" / "camel_doll").mkdir(parents=True, exist_ok=True)
    (OUT / "unlabeled_review" / "cherry_tomato").mkdir(parents=True, exist_ok=True)


def yolo_lines_from_supervisely(ann_path: Path, include_classes: set[str]) -> tuple[list[str], dict[str, int]]:
    ann = json.loads(ann_path.read_text(encoding="utf-8"))
    width = float(ann["size"]["width"])
    height = float(ann["size"]["height"])
    lines: list[str] = []
    counts: dict[str, int] = {}

    for obj in ann.get("objects", []):
        class_name = obj.get("classTitle", "")
        if class_name not in include_classes:
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
        counts[class_name] = counts.get(class_name, 0) + 1
    return lines, counts


def collect_single_source(source: dict) -> list[tuple[Path, Path, str]]:
    img_dir = source["path"] / "img"
    ann_dir = source["path"] / "ann"
    records = []
    for image_path in sorted(img_dir.glob("*")):
        if image_path.suffix.lower() not in {".jpg", ".jpeg", ".png", ".webp"}:
            continue
        ann_path = ann_dir / f"{image_path.name}.json"
        if ann_path.exists():
            records.append((image_path, ann_path, source["name"]))
    return records


def split_records(records: list[tuple[Path, Path, str]]) -> dict[str, list[tuple[Path, Path, str]]]:
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


def copy_records(records: list[tuple[Path, Path, str]], split: str, include_classes: set[str], source_name: str) -> dict:
    stats = {"images": 0, "boxes": 0, "source_class_boxes": {}}
    for image_path, ann_path, _ in records:
        lines, class_counts = yolo_lines_from_supervisely(ann_path, include_classes)
        if not lines:
            continue
        out_stem = f"{source_name}_{image_path.stem}"
        out_image = OUT / split / "images" / f"{out_stem}{image_path.suffix.lower()}"
        out_label = OUT / split / "labels" / f"{out_stem}.txt"
        shutil.copy2(image_path, out_image)
        out_label.write_text("\n".join(lines) + "\n", encoding="utf-8")
        stats["images"] += 1
        stats["boxes"] += len(lines)
        for class_name, count in class_counts.items():
            stats["source_class_boxes"][class_name] = stats["source_class_boxes"].get(class_name, 0) + count
    return stats


def merge_stats(target: dict, split: str, source_stats: dict) -> None:
    split_stats = target.setdefault(split, {"images": 0, "boxes": 0, "source_class_boxes": {}})
    split_stats["images"] += source_stats["images"]
    split_stats["boxes"] += source_stats["boxes"]
    for class_name, count in source_stats["source_class_boxes"].items():
        split_stats["source_class_boxes"][class_name] = split_stats["source_class_boxes"].get(class_name, 0) + count


def build_dataset() -> dict:
    summary = {
        "classes": CLASSES,
        "sources": [],
        "splits": {},
    }
    for source in SOURCES:
        source_summary = {
            "name": source["name"],
            "license": source["license"],
            "source_url": source["source_url"],
            "include_classes": sorted(source["include_classes"]),
            "excluded_classes": source.get("excluded_classes", {}),
            "splits": {},
        }
        if source["mode"] == "single":
            records = collect_single_source(source)
            split_map = split_records(records)
            for split, split_records_ in split_map.items():
                stats = copy_records(split_records_, split, source["include_classes"], source["name"])
                source_summary["splits"][split] = stats
                merge_stats(summary["splits"], split, stats)
        elif source["mode"] == "pre_split":
            for split in SPLITS:
                split_root = source["path"] / split
                records = collect_single_source({**source, "path": split_root})
                stats = copy_records(records, split, source["include_classes"], source["name"])
                source_summary["splits"][split] = stats
                merge_stats(summary["splits"], split, stats)
        else:
            raise ValueError(f"Unknown source mode: {source['mode']}")
        summary["sources"].append(source_summary)
    return summary


def copy_review_sets() -> dict:
    review = {}
    previous = ROOT / "dataset_sources" / "images"
    for class_name in ["camel_doll", "cherry_tomato"]:
        src = previous / class_name
        dst = OUT / "unlabeled_review" / class_name
        count = 0
        if src.exists():
            for image_path in sorted(src.iterdir()):
                if image_path.suffix.lower() not in {".jpg", ".jpeg", ".png", ".webp"}:
                    continue
                shutil.copy2(image_path, dst / image_path.name)
                count += 1
        review[class_name] = count
    return review


def write_data_yaml() -> None:
    two_class_content = f"""path: {OUT}
train: train/images
val: valid/images
test: test/images

nc: {len(CLASSES)}
names: ['fruit', 'camel_doll']
"""
    fruit_only_content = f"""path: {OUT}
train: train/images
val: valid/images
test: test/images

nc: 1
names: ['fruit']
"""
    (OUT / "data.yaml").write_text(two_class_content, encoding="utf-8")
    (OUT / "data_fruit_only.yaml").write_text(fruit_only_content, encoding="utf-8")


def write_docs(summary: dict) -> None:
    total_images = sum(v["images"] for v in summary["splits"].values())
    total_boxes = sum(v["boxes"] for v in summary["splits"].values())
    source_boxes: dict[str, int] = {}
    for split_data in summary["splits"].values():
        for name, count in split_data["source_class_boxes"].items():
            source_boxes[name] = source_boxes.get(name, 0) + count

    lines = [
        "# Open Fruit + Camel Doll Dataset v1",
        "",
        "## Core Judgment",
        "",
        "This dataset uses a two-class MVP schema: `fruit` and `camel_doll`.",
        "All open fruit labels are remapped into the single `fruit` class.",
        "The `camel_doll` class is present in `data.yaml`, but still needs labeled boxes before training a final two-class model.",
        "",
        "## Train-Ready Counts",
        "",
        f"- fruit images: {total_images}",
        f"- fruit boxes: {total_boxes}",
        "- camel_doll boxes: 0",
        "",
        "## Split Counts",
        "",
        "| split | images | boxes |",
        "| --- | ---: | ---: |",
    ]
    for split in SPLITS:
        stats = summary["splits"].get(split, {"images": 0, "boxes": 0})
        lines.append(f"| {split} | {stats['images']} | {stats['boxes']} |")
    lines.extend([
        "",
        "## Source Class Coverage",
        "",
        "| original class | boxes mapped to fruit |",
        "| --- | ---: |",
    ])
    for name, count in sorted(source_boxes.items(), key=lambda x: (-x[1], x[0])):
        lines.append(f"| {name} | {count} |")
    lines.extend([
        "",
        "## Included Open Sources",
        "",
        "- Tomato Detection: CC0 1.0",
        "- AgRobTomato Dataset: CC BY 4.0",
        "- deepNIR Fruit Detection: CC BY 4.0",
        "",
        "Excluded from deepNIR: `wheat`, `capsicum`.",
        "",
        "## Next Step",
        "",
        "Train `fruit` first, then add manually labeled camel doll images and retrain with both classes.",
    ])
    (OUT / "README.md").write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> int:
    reset_output()
    summary = build_dataset()
    summary["unlabeled_review"] = copy_review_sets()
    write_data_yaml()
    write_docs(summary)
    (OUT / "metadata" / "summary.json").write_text(
        json.dumps(summary, indent=2, ensure_ascii=False), encoding="utf-8"
    )
    print(json.dumps(summary, indent=2, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
