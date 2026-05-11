#!/usr/bin/env python3
"""
Merge a Roboflow YOLO export into dataset_sources/fruit_detection_yolo.

Expected target class order:
0 tomato
1 cherry_tomato
2 other_fruit

Examples:
  python3 ml/scripts/merge_roboflow_yolo_export.py /path/to/cherry-tomato-yolov11.zip --source-name cherry_tomato1
  python3 ml/scripts/merge_roboflow_yolo_export.py /path/to/tomato-roboflow.zip --source-name roboflow_tomato
"""

from __future__ import annotations

import argparse
import json
import re
import shutil
import tempfile
import zipfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
TARGET = ROOT / "dataset_sources" / "fruit_detection_yolo"
TARGET_CLASSES = ["tomato", "cherry_tomato", "other_fruit"]
CLASS_REMAP_BY_NAME = {
    "tomato": "tomato",
    "ripe": "tomato",
    "unripe": "tomato",
    "reject": "tomato",
    "red_ripetomato": "cherry_tomato",
    "green_unripetomato": "cherry_tomato",
    "orange": "cherry_tomato",
    "yellow": "cherry_tomato",
    "cherry_tomato": "cherry_tomato",
    "cherry tomato": "cherry_tomato",
    "cherry tomatoes": "cherry_tomato",
}


def normalize_name(value: str) -> str:
    return value.strip().strip("'\"").lower().replace("-", "_")


def find_export_root(path: Path) -> Path:
    if path.is_file() and path.suffix.lower() == ".zip":
        temp_dir = Path(tempfile.mkdtemp(prefix="roboflow_yolo_"))
        with zipfile.ZipFile(path) as archive:
            archive.extractall(temp_dir)
        path = temp_dir

    yaml_files = list(path.rglob("data.yaml")) + list(path.rglob("data.yml"))
    if not yaml_files:
        raise FileNotFoundError(f"No data.yaml found under {path}")
    return yaml_files[0].parent


def parse_names(data_yaml: Path) -> list[str]:
    text = data_yaml.read_text(encoding="utf-8")
    match = re.search(r"names:\s*\[(.*?)\]", text, re.S)
    if match:
        return [normalize_name(part) for part in match.group(1).split(",") if part.strip()]

    names: list[str] = []
    in_names = False
    for raw_line in text.splitlines():
        line = raw_line.rstrip()
        if line.strip().startswith("names:"):
            in_names = True
            continue
        if in_names:
            if not line.startswith(" ") and not line.startswith("-"):
                break
            item = re.sub(r"^\s*-\s*", "", line).strip()
            item = re.sub(r"^\s*\d+\s*:\s*", "", item).strip()
            if item:
                names.append(normalize_name(item))
    if not names:
        raise ValueError(f"Could not parse class names from {data_yaml}")
    return names


def class_id_map(source_names: list[str]) -> dict[int, int]:
    mapping: dict[int, int] = {}
    for source_id, source_name in enumerate(source_names):
        target_name = CLASS_REMAP_BY_NAME.get(source_name)
        if target_name is None:
            raise ValueError(
                f"Unsupported source class '{source_name}'. "
                f"Edit CLASS_REMAP_BY_NAME in {Path(__file__).name} before merging."
            )
        mapping[source_id] = TARGET_CLASSES.index(target_name)
    return mapping


def rewrite_label(src: Path, dst: Path, id_map: dict[int, int]) -> int:
    count = 0
    lines: list[str] = []
    if src.exists():
        for line in src.read_text(encoding="utf-8").splitlines():
            parts = line.strip().split()
            if len(parts) < 5:
                continue
            source_id = int(float(parts[0]))
            if source_id not in id_map:
                continue
            parts[0] = str(id_map[source_id])
            lines.append(" ".join(parts[:5]))
            count += 1
    dst.write_text("\n".join(lines) + ("\n" if lines else ""), encoding="utf-8")
    return count


def merge(export_root: Path, source_name: str) -> dict:
    source_names = parse_names(export_root / "data.yaml")
    id_map = class_id_map(source_names)
    summary = {
        "source_name": source_name,
        "source_root": str(export_root),
        "source_classes": source_names,
        "class_id_map": id_map,
        "splits": {},
    }

    for split in ["train", "valid", "test"]:
        image_dir = export_root / split / "images"
        label_dir = export_root / split / "labels"
        if not image_dir.exists():
            continue

        split_images = 0
        split_boxes = 0
        for image_path in sorted(image_dir.iterdir()):
            if image_path.suffix.lower() not in {".jpg", ".jpeg", ".png", ".webp"}:
                continue
            base_name = f"{source_name}_{image_path.stem}"
            dst_image = TARGET / split / "images" / f"{base_name}{image_path.suffix.lower()}"
            dst_label = TARGET / split / "labels" / f"{base_name}.txt"
            label_path = label_dir / f"{image_path.stem}.txt"
            shutil.copy2(image_path, dst_image)
            split_boxes += rewrite_label(label_path, dst_label, id_map)
            split_images += 1
        summary["splits"][split] = {"images": split_images, "boxes": split_boxes}
    return summary


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("export", type=Path, help="Roboflow YOLO zip or extracted folder")
    parser.add_argument("--source-name", required=True, help="Prefix for merged files")
    args = parser.parse_args()

    export_root = find_export_root(args.export)
    summary = merge(export_root, args.source_name)
    out_dir = TARGET / "metadata" / "imports"
    out_dir.mkdir(parents=True, exist_ok=True)
    out_file = out_dir / f"{args.source_name}.json"
    out_file.write_text(json.dumps(summary, indent=2, ensure_ascii=False), encoding="utf-8")
    print(json.dumps(summary, indent=2, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
