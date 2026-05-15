#!/usr/bin/env python3
"""Build a trainable YOLO dataset from local fruit images and camel data.

Inputs:
- dataset/Fruits Classification/{train,valid,test}/{Apple,Banana,Grape,Mango,Strawberry}
- dataset/IMG_*.JPG as direct camel_doll photos
- dataset_sources 2/trueprice_yolo_bootstrap camel_doll image/label pairs only

Output:
- dataset/trueprice_yolo_local

Fruit images are classification images, so the script assigns one centered
weak bounding box per image. Existing camel YOLO labels are preserved and
remapped into this dataset's class order.
"""

from __future__ import annotations

import json
import random
import re
import shutil
from collections import Counter, defaultdict
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
DATASET_ROOT = ROOT / "dataset"
FRUIT_ROOT = DATASET_ROOT / "Fruits Classification"
CAMEL_SOURCE = ROOT / "dataset_sources 2" / "trueprice_yolo_bootstrap"
OUT = DATASET_ROOT / "trueprice_yolo_local"

SPLITS = ("train", "valid", "test")
IMAGE_EXTENSIONS = {".jpg", ".jpeg", ".png", ".webp", ".heic", ".JPG", ".JPEG", ".PNG"}
WEAK_BOX = "0.500000 0.500000 0.900000 0.900000"
SEED = 222

CLASS_NAMES = [
    "apple",
    "banana",
    "grape",
    "mango",
    "strawberry",
    "camel_doll",
]
CLASS_TO_ID = {name: index for index, name in enumerate(CLASS_NAMES)}

FRUIT_FOLDER_TO_CLASS = {
    "Apple": "apple",
    "Banana": "banana",
    "Grape": "grape",
    "Mango": "mango",
    "Strawberry": "strawberry",
}


def reset_output() -> None:
    if OUT.exists():
        shutil.rmtree(OUT)
    for split in SPLITS:
        (OUT / split / "images").mkdir(parents=True, exist_ok=True)
        (OUT / split / "labels").mkdir(parents=True, exist_ok=True)
    (OUT / "metadata").mkdir(parents=True, exist_ok=True)


def slug(value: str) -> str:
    value = re.sub(r"[^a-zA-Z0-9]+", "_", value).strip("_").lower()
    return value[:120] or "image"


def image_files(path: Path) -> list[Path]:
    if not path.exists():
        return []
    return sorted(
        file
        for file in path.iterdir()
        if file.is_file() and file.suffix in IMAGE_EXTENSIONS
    )


def write_label(path: Path, class_id: int, yolo_box: str = WEAK_BOX) -> None:
    path.write_text(f"{class_id} {yolo_box}\n", encoding="utf-8")


def copy_image(src: Path, split: str, stem: str) -> Path:
    dst = OUT / split / "images" / f"{stem}{src.suffix.lower()}"
    shutil.copy2(src, dst)
    return dst


def copy_fruit_images() -> list[dict]:
    records: list[dict] = []
    for split in SPLITS:
        for folder_name, class_name in FRUIT_FOLDER_TO_CLASS.items():
            class_dir = FRUIT_ROOT / split / folder_name
            class_id = CLASS_TO_ID[class_name]
            for src in image_files(class_dir):
                stem = f"fruit_{split}_{class_name}_{slug(src.stem)}"
                dst = copy_image(src, split, stem)
                label = OUT / split / "labels" / f"{dst.stem}.txt"
                write_label(label, class_id)
                records.append(
                    {
                        "source": str(src.relative_to(ROOT)),
                        "file": str(dst.relative_to(OUT)),
                        "label": str(label.relative_to(OUT)),
                        "split": split,
                        "class_name": class_name,
                        "label_policy": "weak_center_box_from_classification_folder",
                    }
                )
    return records


def split_direct_camel_images(images: list[Path]) -> dict[str, list[Path]]:
    shuffled = images[:]
    random.Random(SEED).shuffle(shuffled)
    total = len(shuffled)
    train_end = int(total * 0.7)
    valid_end = train_end + int(total * 0.2)
    return {
        "train": shuffled[:train_end],
        "valid": shuffled[train_end:valid_end],
        "test": shuffled[valid_end:],
    }


def copy_direct_camel_images() -> list[dict]:
    records: list[dict] = []
    direct_images = sorted(
        file
        for file in DATASET_ROOT.glob("IMG_*.*")
        if file.is_file() and file.suffix in IMAGE_EXTENSIONS
    )
    split_map = split_direct_camel_images(direct_images)
    class_id = CLASS_TO_ID["camel_doll"]
    for split, images in split_map.items():
        for src in images:
            stem = f"direct_camel_{slug(src.stem)}"
            dst = copy_image(src, split, stem)
            label = OUT / split / "labels" / f"{dst.stem}.txt"
            write_label(label, class_id)
            records.append(
                {
                    "source": str(src.relative_to(ROOT)),
                    "file": str(dst.relative_to(OUT)),
                    "label": str(label.relative_to(OUT)),
                    "split": split,
                    "class_name": "camel_doll",
                    "label_policy": "weak_center_box_from_direct_single_object_photo",
                }
            )
    return records


def remap_camel_label(source_label: Path) -> list[str]:
    lines: list[str] = []
    for raw_line in source_label.read_text(encoding="utf-8").splitlines():
        parts = raw_line.strip().split()
        if len(parts) != 5:
            continue
        if int(parts[0]) != 11:
            continue
        lines.append(" ".join([str(CLASS_TO_ID["camel_doll"]), *parts[1:]]))
    return lines


def copy_existing_camel_yolo() -> list[dict]:
    records: list[dict] = []
    if not CAMEL_SOURCE.exists():
        return records

    for split in SPLITS:
        image_dir = CAMEL_SOURCE / split / "images"
        label_dir = CAMEL_SOURCE / split / "labels"
        for src in image_files(image_dir):
            if not src.name.startswith("camel_"):
                continue
            source_label = label_dir / f"{src.stem}.txt"
            if not source_label.exists():
                continue
            lines = remap_camel_label(source_label)
            if not lines:
                continue

            stem = f"source2_{slug(src.stem)}"
            dst = copy_image(src, split, stem)
            label = OUT / split / "labels" / f"{dst.stem}.txt"
            label.write_text("\n".join(lines) + "\n", encoding="utf-8")
            records.append(
                {
                    "source": str(src.relative_to(ROOT)),
                    "file": str(dst.relative_to(OUT)),
                    "label": str(label.relative_to(OUT)),
                    "split": split,
                    "class_name": "camel_doll",
                    "label_policy": "existing_yolo_box_remapped_from_dataset_sources_2",
                }
            )
    return records


def write_data_yaml() -> None:
    names = "[" + ", ".join(f"'{name}'" for name in CLASS_NAMES) + "]"
    (OUT / "data.yaml").write_text(
        f"""path: {OUT}
train: train/images
val: valid/images
test: test/images

nc: {len(CLASS_NAMES)}
names: {names}
""",
        encoding="utf-8",
    )


def write_metadata(records: list[dict]) -> None:
    split_counts = Counter(record["split"] for record in records)
    class_counts = Counter(record["class_name"] for record in records)
    policy_counts = Counter(record["label_policy"] for record in records)
    split_class_counts: dict[str, dict[str, int]] = defaultdict(lambda: defaultdict(int))
    for record in records:
        split_class_counts[record["split"]][record["class_name"]] += 1

    summary = {
        "dataset": str(OUT),
        "classes": CLASS_NAMES,
        "total_images": len(records),
        "split_counts": {split: split_counts[split] for split in SPLITS},
        "class_counts": {class_name: class_counts[class_name] for class_name in CLASS_NAMES},
        "split_class_counts": {
            split: {class_name: split_class_counts[split][class_name] for class_name in CLASS_NAMES}
            for split in SPLITS
        },
        "label_policy_counts": dict(policy_counts),
        "notes": [
            "Fruit labels are weak centered boxes because the source is a classification dataset.",
            "Direct camel photos use weak centered boxes because no manual bbox files were provided.",
            "dataset_sources 2 camel labels are preserved and remapped to this class order.",
        ],
    }
    (OUT / "metadata" / "summary.json").write_text(
        json.dumps(summary, indent=2, ensure_ascii=False),
        encoding="utf-8",
    )
    (OUT / "metadata" / "manifest.jsonl").write_text(
        "\n".join(json.dumps(record, ensure_ascii=False) for record in records) + "\n",
        encoding="utf-8",
    )

    lines = [
        "# TruePrice Local Fruit + Camel YOLO Dataset",
        "",
        "## Classes",
        "",
        ", ".join(CLASS_NAMES),
        "",
        "## Counts",
        "",
        "| class | images |",
        "| --- | ---: |",
    ]
    for class_name in CLASS_NAMES:
        lines.append(f"| {class_name} | {class_counts[class_name]} |")
    lines.extend(["", "## Splits", "", "| split | images |", "| --- | ---: |"])
    for split in SPLITS:
        lines.append(f"| {split} | {split_counts[split]} |")
    lines.extend(
        [
            "",
            "## Label Policy",
            "",
            "- Fruit: weak centered YOLO boxes from existing classification folders.",
            "- Direct camel photos: weak centered YOLO boxes.",
            "- dataset_sources 2 camel images: existing YOLO boxes remapped.",
        ]
    )
    (OUT / "README.md").write_text("\n".join(lines) + "\n", encoding="utf-8")


def build() -> dict:
    reset_output()
    records: list[dict] = []
    records.extend(copy_fruit_images())
    records.extend(copy_direct_camel_images())
    records.extend(copy_existing_camel_yolo())
    write_data_yaml()
    write_metadata(records)
    return json.loads((OUT / "metadata" / "summary.json").read_text(encoding="utf-8"))


def main() -> int:
    summary = build()
    print(json.dumps(summary, indent=2, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
