#!/usr/bin/env python3
"""
Build a weak-labeled YOLO bootstrap dataset from reviewed camel plush images.

This is for MVP pipeline bring-up only. Because the source images do not have
manual bounding boxes yet, each generated image gets a full-image YOLO box:

0 0.5 0.5 1.0 1.0

Replace these labels with manual boxes before trusting detector quality.
"""

from __future__ import annotations

import argparse
import json
import random
import shutil
import subprocess
import sys
import time
from dataclasses import dataclass
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
DEFAULT_SOURCE = ROOT / "dataset_sources" / "camel_plush_open"
DEFAULT_OUT = ROOT / "dataset_sources" / "camel_plush_yolo_bootstrap"
IMAGE_EXTENSIONS = {".jpg", ".jpeg", ".png", ".webp"}
SPLITS = ("train", "valid", "test")
SPLIT_RATIOS = {"train": 0.7, "valid": 0.2, "test": 0.1}
SEED = 222
CLASS_NAME = "camel_plush"
WEAK_LABEL = "0 0.500000 0.500000 1.000000 1.000000\n"


@dataclass(frozen=True)
class Variant:
    name: str
    operations: tuple[str, ...]


VARIANTS = (
    Variant("orig", ()),
    Variant("flip_h", ("flip_h",)),
    Variant("crop_92_center", ("crop_92_center",)),
    Variant("crop_86_center", ("crop_86_center",)),
    Variant("crop_92_tl", ("crop_92_tl",)),
    Variant("crop_92_tr", ("crop_92_tr",)),
    Variant("crop_92_bl", ("crop_92_bl",)),
    Variant("crop_92_br", ("crop_92_br",)),
    Variant("crop_86_tl", ("crop_86_tl",)),
    Variant("crop_86_br", ("crop_86_br",)),
    Variant("flip_crop_92_center", ("flip_h", "crop_92_center")),
    Variant("flip_crop_86_center", ("flip_h", "crop_86_center")),
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Create a weak-labeled augmented YOLO dataset for camel_plush.",
    )
    parser.add_argument(
        "--source",
        type=Path,
        default=DEFAULT_SOURCE,
        help=f"camel_plush_open dataset directory. Default: {DEFAULT_SOURCE}",
    )
    parser.add_argument(
        "--out",
        type=Path,
        default=DEFAULT_OUT,
        help=f"Output YOLO dataset directory. Default: {DEFAULT_OUT}",
    )
    parser.add_argument(
        "--image-size",
        type=int,
        default=640,
        help="Final max image dimension for generated images.",
    )
    parser.add_argument(
        "--seed",
        type=int,
        default=SEED,
        help="Deterministic split seed.",
    )
    return parser.parse_args()


def run_sips(args: list[str]) -> None:
    result = subprocess.run(["sips", *args], check=False, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if result.returncode != 0:
        message = result.stderr.decode("utf-8", "replace").strip()
        raise RuntimeError(message or "sips failed")


def sips_property(image_path: Path, property_name: str) -> int:
    result = subprocess.run(
        ["sips", "-g", property_name, str(image_path)],
        check=False,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    if result.returncode != 0:
        message = result.stderr.decode("utf-8", "replace").strip()
        raise RuntimeError(message or f"failed to read {property_name}")
    for line in result.stdout.decode("utf-8", "replace").splitlines():
        if property_name in line:
            return int(float(line.rsplit(":", 1)[1].strip()))
    raise ValueError(f"Missing {property_name} in sips output for {image_path}")


def source_images(source: Path) -> list[Path]:
    image_dir = source / "images" / CLASS_NAME
    if not image_dir.exists():
        raise FileNotFoundError(f"Missing source image directory: {image_dir}")
    images = sorted(
        path
        for path in image_dir.iterdir()
        if path.is_file() and path.suffix.lower() in IMAGE_EXTENSIONS
    )
    if not images:
        raise FileNotFoundError(f"No source images found in {image_dir}")
    return images


def reset_output(out: Path) -> None:
    shutil.rmtree(out, ignore_errors=True)
    for split in SPLITS:
        (out / split / "images").mkdir(parents=True, exist_ok=True)
        (out / split / "labels").mkdir(parents=True, exist_ok=True)
    (out / "metadata").mkdir(parents=True, exist_ok=True)


def split_sources(images: list[Path], seed: int) -> dict[str, list[Path]]:
    shuffled = images[:]
    random.Random(seed).shuffle(shuffled)
    total = len(shuffled)
    train_end = max(1, int(total * SPLIT_RATIOS["train"]))
    valid_end = min(total, train_end + max(1, int(total * SPLIT_RATIOS["valid"])))
    if total >= 3 and valid_end == total:
        valid_end = total - 1
    return {
        "train": shuffled[:train_end],
        "valid": shuffled[train_end:valid_end],
        "test": shuffled[valid_end:],
    }


def apply_crop_percent(image_path: Path, percent: int, anchor: str) -> None:
    width = sips_property(image_path, "pixelWidth")
    height = sips_property(image_path, "pixelHeight")
    crop_w = max(1, int(width * percent / 100))
    crop_h = max(1, int(height * percent / 100))
    max_x = max(0, width - crop_w)
    max_y = max(0, height - crop_h)
    if anchor == "center":
        offset_x = int(max_x / 2)
        offset_y = int(max_y / 2)
    elif anchor == "tl":
        offset_x = 0
        offset_y = 0
    elif anchor == "tr":
        offset_x = max_x
        offset_y = 0
    elif anchor == "bl":
        offset_x = 0
        offset_y = max_y
    elif anchor == "br":
        offset_x = max_x
        offset_y = max_y
    else:
        raise ValueError(f"Unknown crop anchor: {anchor}")
    run_sips(
        [
            "--cropToHeightWidth",
            str(crop_h),
            str(crop_w),
            "--cropOffset",
            str(offset_y),
            str(offset_x),
            str(image_path),
        ]
    )


def apply_operations(image_path: Path, operations: tuple[str, ...], image_size: int) -> None:
    for operation in operations:
        if operation == "flip_h":
            run_sips(["--flip", "horizontal", str(image_path)])
        elif operation.startswith("crop_"):
            _, raw_percent, anchor = operation.split("_", 2)
            apply_crop_percent(image_path, int(raw_percent), anchor)
        else:
            raise ValueError(f"Unknown operation: {operation}")
    run_sips(["--resampleHeightWidthMax", str(image_size), str(image_path)])


def copy_variant(source_image: Path, out_image: Path, variant: Variant, image_size: int) -> None:
    shutil.copy2(source_image, out_image)
    apply_operations(out_image, variant.operations, image_size)


def build_dataset(args: argparse.Namespace) -> dict:
    images = source_images(args.source)
    reset_output(args.out)
    split_map = split_sources(images, args.seed)

    summary = {
        "classes": [CLASS_NAME],
        "source_dataset": str(args.source),
        "output": str(args.out),
        "label_policy": "weak_full_image_bbox",
        "warning": "MVP bootstrap only; replace with manual bounding boxes for real detector quality.",
        "variants_per_source": len(VARIANTS),
        "splits": {},
    }

    for split, split_images in split_map.items():
        generated = 0
        for source_image in split_images:
            for variant in VARIANTS:
                out_stem = f"{source_image.stem}_{variant.name}"
                out_image = args.out / split / "images" / f"{out_stem}.jpg"
                out_label = args.out / split / "labels" / f"{out_stem}.txt"
                copy_variant(source_image, out_image, variant, args.image_size)
                out_label.write_text(WEAK_LABEL, encoding="utf-8")
                generated += 1
        summary["splits"][split] = {
            "source_images": len(split_images),
            "generated_images": generated,
            "generated_boxes": generated,
        }

    write_dataset_files(args.out, args.source, summary)
    return summary


def copy_source_metadata(source: Path, out: Path) -> None:
    source_metadata = source / "metadata"
    if not source_metadata.exists():
        return
    dst = out / "metadata" / "source_attribution"
    shutil.copytree(source_metadata, dst, dirs_exist_ok=True)


def write_dataset_files(out: Path, source: Path, summary: dict) -> None:
    data_yaml = f"""path: {out}
train: train/images
val: valid/images
test: test/images

nc: 1
names: ['{CLASS_NAME}']
"""
    (out / "data.yaml").write_text(data_yaml, encoding="utf-8")
    (out / "metadata" / "summary.json").write_text(
        json.dumps(summary, indent=2, ensure_ascii=False),
        encoding="utf-8",
    )
    copy_source_metadata(source, out)

    total_generated = sum(split["generated_images"] for split in summary["splits"].values())
    readme = f"""# Camel Plush YOLO Bootstrap Dataset

## Core Judgment

This is a weak-labeled training bootstrap dataset for `camel_plush`.
It exists to make the YOLO training pipeline runnable from the currently
license-stable images.

## Counts

- source images: {sum(split["source_images"] for split in summary["splits"].values())}
- generated images: {total_generated}
- class: `camel_plush`

## Label Policy

Every generated image uses this full-image YOLO label:

```text
{WEAK_LABEL.strip()}
```

This is acceptable only for MVP pipeline testing. For real object detection
quality, replace labels with manual bounding boxes.

## Attribution

Original source metadata is copied to `metadata/source_attribution/`.
Keep that folder with any dataset archive or model card.
"""
    (out / "README.md").write_text(readme, encoding="utf-8")
    (out / "metadata" / "generated_at.txt").write_text(
        time.strftime("%Y-%m-%dT%H:%M:%SZ\n", time.gmtime()),
        encoding="utf-8",
    )


def main() -> int:
    args = parse_args()
    if args.image_size < 128:
        raise ValueError("--image-size must be at least 128")
    summary = build_dataset(args)
    print(json.dumps(summary, indent=2, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(main())
