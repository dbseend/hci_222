#!/usr/bin/env python3
"""Audit a YOLO detection dataset before training."""

from __future__ import annotations

import argparse
from collections import Counter
from pathlib import Path


IMAGE_EXTENSIONS = {".jpg", ".jpeg", ".png", ".webp", ".heic"}
SPLITS = ("train", "valid", "test")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Validate TruePrice YOLO dataset structure and labels.",
    )
    parser.add_argument(
        "dataset_dir",
        type=Path,
        help="Path to a YOLO dataset directory containing data.yaml.",
    )
    return parser.parse_args()


def load_class_names(dataset_dir: Path) -> dict[int, str]:
    data_yaml = dataset_dir / "data.yaml"
    if not data_yaml.exists():
        raise FileNotFoundError(f"Missing data.yaml: {data_yaml}")

    text = data_yaml.read_text(encoding="utf-8")
    for line in text.splitlines():
        if not line.strip().startswith("names:"):
            continue
        raw_names = line.split(":", 1)[1].strip()
        if raw_names.startswith("[") and raw_names.endswith("]"):
            names = [
                item.strip().strip("'\"")
                for item in raw_names.strip("[]").split(",")
                if item.strip()
            ]
            return {index: name for index, name in enumerate(names)}

    raise ValueError(f"Could not parse inline names list from {data_yaml}")


def image_files(path: Path) -> list[Path]:
    return sorted(
        file
        for file in path.iterdir()
        if file.is_file() and file.suffix.lower() in IMAGE_EXTENSIONS
    )


def label_path_for(dataset_dir: Path, split: str, image_path: Path) -> Path:
    return dataset_dir / split / "labels" / f"{image_path.stem}.txt"


def validate_label_file(label_path: Path, split: str, class_names: dict[int, str]) -> tuple[Counter[int], list[str]]:
    counts: Counter[int] = Counter()
    errors: list[str] = []

    if not label_path.exists():
        errors.append(f"[{split}] missing label file: {label_path}")
        return counts, errors

    for line_number, raw_line in enumerate(label_path.read_text().splitlines(), start=1):
        line = raw_line.strip()
        if not line:
            continue

        parts = line.split()
        if len(parts) != 5:
            errors.append(
                f"[{split}] {label_path}:{line_number} expected 5 fields, got {len(parts)}"
            )
            continue

        try:
            class_id = int(parts[0])
            values = [float(value) for value in parts[1:]]
        except ValueError:
            errors.append(f"[{split}] {label_path}:{line_number} contains non-numeric data")
            continue

        if class_id not in class_names:
            errors.append(f"[{split}] {label_path}:{line_number} unknown class_id {class_id}")
            continue

        for value in values:
            if value < 0 or value > 1:
                errors.append(
                    f"[{split}] {label_path}:{line_number} coordinate out of range: {value}"
                )

        if values[2] <= 0 or values[3] <= 0:
            errors.append(
                f"[{split}] {label_path}:{line_number} width/height must be > 0"
            )

        counts[class_id] += 1

    return counts, errors


def audit(dataset_dir: Path) -> int:
    if not dataset_dir.exists():
        print(f"Dataset directory not found: {dataset_dir}")
        return 2
    try:
        class_names = load_class_names(dataset_dir)
    except Exception as exc:
        print(str(exc))
        return 2

    all_counts: Counter[int] = Counter()
    split_image_counts: Counter[str] = Counter()
    errors: list[str] = []

    for split in SPLITS:
        image_dir = dataset_dir / split / "images"
        label_dir = dataset_dir / split / "labels"

        if not image_dir.exists():
            errors.append(f"Missing image directory: {image_dir}")
            continue
        if not label_dir.exists():
            errors.append(f"Missing label directory: {label_dir}")
            continue

        images = image_files(image_dir)
        split_image_counts[split] = len(images)

        image_stems = {image.stem for image in images}
        label_stems = {
            label.stem
            for label in label_dir.iterdir()
            if label.is_file() and label.suffix.lower() == ".txt"
        }

        for extra_label in sorted(label_stems - image_stems):
            errors.append(f"[{split}] label without image: {label_dir / (extra_label + '.txt')}")

        for image in images:
            counts, label_errors = validate_label_file(
                label_path_for(dataset_dir, split, image),
                split,
                class_names,
            )
            all_counts.update(counts)
            errors.extend(label_errors)

    print("Dataset audit summary")
    print("=====================")
    print(f"Dataset: {dataset_dir}")
    print()
    print("Images by split:")
    for split in SPLITS:
        print(f"- {split}: {split_image_counts[split]}")
    print()
    print("Labels by class:")
    for class_id, class_name in class_names.items():
        print(f"- {class_id} {class_name}: {all_counts[class_id]}")

    if errors:
        print()
        print("Errors:")
        for error in errors:
            print(f"- {error}")
        return 1

    print()
    print("No structural label errors found.")
    return 0


def main() -> int:
    args = parse_args()
    return audit(args.dataset_dir)


if __name__ == "__main__":
    raise SystemExit(main())
