#!/usr/bin/env python3
"""Train TruePrice YOLO detectors from the collected local datasets.

Current MVP data status:
- fruit classes are train-ready in dataset_open_v1/yolo after running
  build_open_fruit_camel_dataset.py.
- cherry_tomato can be merged from a Roboflow YOLO export into
  dataset_sources/cherry_tomato_yolo.
- camel_doll should come from a manually labeled YOLO export at
  dataset_sources/camel_doll_yolo. The weak camel_plush bootstrap remains a
  fallback only for pipeline bring-up.

The combined preset keeps the final class order stable:
0 tomato
1 apple
2 avocado
3 blueberry
4 cherry
5 kiwi
6 mango
7 orange
8 rockmelon
9 strawberry
10 cherry_tomato
11 camel_doll
"""

from __future__ import annotations

import argparse
import json
import shutil
from collections import Counter
from dataclasses import dataclass
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
DATASET_SOURCES = ROOT / "dataset_sources"
FRUIT_DATASET = ROOT / "dataset_open_v1" / "yolo"
CHERRY_TOMATO_DATASET = DATASET_SOURCES / "cherry_tomato_yolo"
CAMEL_DOLL_DATASET = DATASET_SOURCES / "camel_doll_yolo"
CAMEL_BOOTSTRAP_DATASET = DATASET_SOURCES / "camel_doll_yolo_bootstrap"
COMBINED_BOOTSTRAP_DATASET = DATASET_SOURCES / "trueprice_yolo_bootstrap"
RUNS_DIR = ROOT / "runs" / "trueprice"

IMAGE_EXTENSIONS = {".jpg", ".jpeg", ".png", ".webp"}
SPLITS = ("train", "valid", "test")
FINAL_CLASS_NAMES = [
    "tomato",
    "apple",
    "avocado",
    "blueberry",
    "cherry",
    "kiwi",
    "mango",
    "orange",
    "rockmelon",
    "strawberry",
    "cherry_tomato",
    "camel_doll",
]


@dataclass(frozen=True)
class DatasetSummary:
    dataset_dir: Path
    class_names: dict[int, str]
    split_image_counts: dict[str, int]
    class_counts: Counter[int]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Prepare and train YOLO models for the TruePrice MVP.",
    )
    parser.add_argument(
        "--preset",
        choices=("combined_mvp", "camel_bootstrap", "fruit"),
        default="combined_mvp",
        help="Dataset preset. combined_mvp builds fruit + cherry_tomato + camel_doll data.",
    )
    parser.add_argument(
        "--data",
        type=Path,
        default=None,
        help="Override data.yaml path. If omitted, the selected preset is used.",
    )
    parser.add_argument(
        "--combined-out",
        type=Path,
        default=COMBINED_BOOTSTRAP_DATASET,
        help=f"Output directory for --preset combined_mvp. Default: {COMBINED_BOOTSTRAP_DATASET}",
    )
    parser.add_argument("--model", default="yolo11n.pt", help="Ultralytics base model.")
    parser.add_argument("--epochs", type=int, default=50)
    parser.add_argument("--imgsz", type=int, default=640)
    parser.add_argument("--batch", type=int, default=16)
    parser.add_argument("--device", default=None, help="Optional Ultralytics device, e.g. 0, cpu, mps.")
    parser.add_argument("--workers", type=int, default=4)
    parser.add_argument("--project", type=Path, default=RUNS_DIR)
    parser.add_argument("--name", default=None, help="Run name. Defaults to preset name.")
    parser.add_argument("--seed", type=int, default=222)
    parser.add_argument("--patience", type=int, default=20)
    parser.add_argument("--exist-ok", action="store_true")
    parser.add_argument(
        "--allow-empty-classes",
        action="store_true",
        help="Allow classes with zero labels. Required until cherry_tomato boxes are added.",
    )
    parser.add_argument(
        "--prepare-only",
        action="store_true",
        help="Build/validate the dataset but do not start training.",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Print the resolved training configuration without importing Ultralytics.",
    )
    parser.add_argument(
        "--export",
        choices=("onnx", "tflite"),
        default=None,
        help="Optional export format after training.",
    )
    return parser.parse_args()


def load_class_names(dataset_dir: Path) -> dict[int, str]:
    data_yaml = dataset_dir / "data.yaml"
    if not data_yaml.exists():
        raise FileNotFoundError(f"Missing data.yaml: {data_yaml}")

    lines = data_yaml.read_text(encoding="utf-8").splitlines()
    for index, line in enumerate(lines):
        stripped = line.strip()
        if not stripped.startswith("names:"):
            continue

        raw = stripped.split(":", 1)[1].strip()
        if raw.startswith("[") and raw.endswith("]"):
            names = [
                item.strip().strip("'\"")
                for item in raw.strip("[]").split(",")
                if item.strip()
            ]
            return {class_id: name for class_id, name in enumerate(names)}

        mapping: dict[int, str] = {}
        for child in lines[index + 1 :]:
            if not child.startswith((" ", "\t")):
                break
            child = child.strip()
            if not child or ":" not in child:
                continue
            raw_id, name = child.split(":", 1)
            mapping[int(raw_id.strip())] = name.strip().strip("'\"")
        if mapping:
            return dict(sorted(mapping.items()))

    raise ValueError(f"Could not parse names from {data_yaml}")


def image_files(image_dir: Path) -> list[Path]:
    if not image_dir.exists():
        return []
    return sorted(
        path
        for path in image_dir.iterdir()
        if path.is_file() and path.suffix.lower() in IMAGE_EXTENSIONS
    )


def label_counts(label_dir: Path, class_names: dict[int, str]) -> Counter[int]:
    counts: Counter[int] = Counter()
    if not label_dir.exists():
        return counts

    for label_path in sorted(label_dir.glob("*.txt")):
        for line_number, raw_line in enumerate(label_path.read_text(encoding="utf-8").splitlines(), start=1):
            line = raw_line.strip()
            if not line:
                continue
            parts = line.split()
            if len(parts) != 5:
                raise ValueError(f"{label_path}:{line_number} expected 5 YOLO fields")
            class_id = int(parts[0])
            if class_id not in class_names:
                raise ValueError(f"{label_path}:{line_number} unknown class id {class_id}")
            coords = [float(value) for value in parts[1:]]
            if any(value < 0 or value > 1 for value in coords):
                raise ValueError(f"{label_path}:{line_number} coordinate out of range")
            if coords[2] <= 0 or coords[3] <= 0:
                raise ValueError(f"{label_path}:{line_number} box width/height must be > 0")
            counts[class_id] += 1
    return counts


def dataset_has_any_boxes(dataset_dir: Path) -> bool:
    if not dataset_dir.exists():
        return False
    for split in SPLITS:
        label_dir = dataset_dir / split / "labels"
        if not label_dir.exists():
            continue
        for label_path in label_dir.glob("*.txt"):
            if label_path.read_text(encoding="utf-8").strip():
                return True
    return False


def validate_dataset_for_training(dataset_dir: Path, allow_empty_classes: bool) -> DatasetSummary:
    if not dataset_dir.exists():
        raise FileNotFoundError(f"Dataset not found: {dataset_dir}")

    class_names = load_class_names(dataset_dir)
    split_image_counts: dict[str, int] = {}
    total_counts: Counter[int] = Counter()

    for split in SPLITS:
        image_dir = dataset_dir / split / "images"
        label_dir = dataset_dir / split / "labels"
        if not image_dir.exists():
            raise FileNotFoundError(f"Missing image directory: {image_dir}")
        if not label_dir.exists():
            raise FileNotFoundError(f"Missing label directory: {label_dir}")

        images = image_files(image_dir)
        split_image_counts[split] = len(images)
        image_stems = {image.stem for image in images}
        label_stems = {label.stem for label in label_dir.glob("*.txt")}
        missing_labels = sorted(image_stems - label_stems)
        if missing_labels:
            raise ValueError(f"[{split}] missing label files for {len(missing_labels)} images")

        total_counts.update(label_counts(label_dir, class_names))

    if not sum(total_counts.values()):
        raise ValueError(f"No bounding boxes found in {dataset_dir}")

    empty_classes = [
        class_name
        for class_id, class_name in class_names.items()
        if total_counts[class_id] == 0
    ]
    if empty_classes and not allow_empty_classes:
        raise ValueError(
            "Classes without boxes: "
            + ", ".join(empty_classes)
            + ". Add labels or pass --allow-empty-classes for a temporary MVP run."
        )

    return DatasetSummary(
        dataset_dir=dataset_dir,
        class_names=class_names,
        split_image_counts=split_image_counts,
        class_counts=total_counts,
    )


def remap_label_line(line: str, target_class_id: int) -> str:
    parts = line.strip().split()
    if len(parts) != 5:
        raise ValueError(f"Invalid YOLO label line: {line}")
    return " ".join([str(target_class_id), *parts[1:]])


def reset_yolo_output(out: Path) -> None:
    shutil.rmtree(out, ignore_errors=True)
    for split in SPLITS:
        (out / split / "images").mkdir(parents=True, exist_ok=True)
        (out / split / "labels").mkdir(parents=True, exist_ok=True)
    (out / "metadata").mkdir(parents=True, exist_ok=True)


def copy_yolo_records(
    *,
    source: Path,
    out: Path,
    split: str,
    prefix: str,
    class_id_map: dict[int, int],
) -> dict[str, int]:
    copied = {"images": 0, "boxes": 0}
    image_dir = source / split / "images"
    label_dir = source / split / "labels"

    for image_path in image_files(image_dir):
        source_label = label_dir / f"{image_path.stem}.txt"
        if not source_label.exists():
            continue

        remapped_lines: list[str] = []
        for raw_line in source_label.read_text(encoding="utf-8").splitlines():
            line = raw_line.strip()
            if not line:
                continue
            source_class_id = int(line.split()[0])
            if source_class_id not in class_id_map:
                continue
            remapped_lines.append(remap_label_line(line, class_id_map[source_class_id]))

        if not remapped_lines:
            continue

        out_stem = f"{prefix}_{image_path.stem}"
        shutil.copy2(image_path, out / split / "images" / f"{out_stem}{image_path.suffix.lower()}")
        (out / split / "labels" / f"{out_stem}.txt").write_text(
            "\n".join(remapped_lines) + "\n",
            encoding="utf-8",
        )
        copied["images"] += 1
        copied["boxes"] += len(remapped_lines)

    return copied


def copy_all_yolo_records(
    *,
    source: Path,
    out: Path,
    prefix: str,
    class_id_map: dict[int, int],
) -> dict[str, dict[str, int]]:
    if not source.exists():
        return {split: {"images": 0, "boxes": 0} for split in SPLITS}

    return {
        split: copy_yolo_records(
            source=source,
            out=out,
            split=split,
            prefix=prefix,
            class_id_map=class_id_map,
        )
        for split in SPLITS
    }


def write_combined_data_yaml(out: Path) -> None:
    names = "[" + ", ".join(f"'{name}'" for name in FINAL_CLASS_NAMES) + "]"
    (out / "data.yaml").write_text(
        f"""path: {out}
train: train/images
val: valid/images
test: test/images

nc: {len(FINAL_CLASS_NAMES)}
names: {names}
""",
        encoding="utf-8",
    )


def prepare_combined_mvp_dataset(out: Path) -> dict:
    reset_yolo_output(out)
    fruit_class_names = load_class_names(FRUIT_DATASET) if FRUIT_DATASET.exists() else {}
    fruit_class_id_map = {
        source_id: FINAL_CLASS_NAMES.index(class_name)
        for source_id, class_name in fruit_class_names.items()
        if class_name in FINAL_CLASS_NAMES
    }
    cherry_class_names = load_class_names(CHERRY_TOMATO_DATASET) if CHERRY_TOMATO_DATASET.exists() else {}
    cherry_class_id_map = {
        source_id: FINAL_CLASS_NAMES.index("cherry_tomato")
        for source_id, class_name in cherry_class_names.items()
        if class_name == "cherry_tomato"
    }
    camel_source = CAMEL_DOLL_DATASET if dataset_has_any_boxes(CAMEL_DOLL_DATASET) else CAMEL_BOOTSTRAP_DATASET
    camel_class_names = load_class_names(camel_source) if camel_source.exists() else {}
    camel_class_id_map = {
        source_id: FINAL_CLASS_NAMES.index("camel_doll")
        for source_id, class_name in camel_class_names.items()
        if class_name in {"camel_doll", "camel_plush"}
    }

    stats = {
        "output": str(out),
        "class_order": FINAL_CLASS_NAMES,
        "label_policy": {
            "fruit_classes": "manual boxes from dataset_open_v1/yolo",
            "cherry_tomato": "Roboflow/CVAT/LabelImg YOLO boxes from dataset_sources/cherry_tomato_yolo",
            "camel_doll": "manual boxes from dataset_sources/camel_doll_yolo; weak camel_plush bootstrap fallback if absent",
        },
        "sources": {
            "fruit": str(FRUIT_DATASET),
            "cherry_tomato": str(CHERRY_TOMATO_DATASET),
            "camel_doll": str(camel_source),
        },
        "splits": {},
    }

    fruit_stats_by_split = copy_all_yolo_records(
        source=FRUIT_DATASET,
        out=out,
        prefix="fruit",
        class_id_map=fruit_class_id_map,
    )
    cherry_stats_by_split = copy_all_yolo_records(
        source=CHERRY_TOMATO_DATASET,
        out=out,
        prefix="cherry_tomato",
        class_id_map=cherry_class_id_map,
    )
    camel_stats_by_split = copy_all_yolo_records(
        source=camel_source,
        out=out,
        prefix="camel",
        class_id_map=camel_class_id_map,
    )

    for split in SPLITS:
        fruit_stats = fruit_stats_by_split[split]
        cherry_stats = cherry_stats_by_split[split]
        camel_stats = camel_stats_by_split[split]
        stats["splits"][split] = {
            "fruit_images": fruit_stats["images"],
            "fruit_boxes": fruit_stats["boxes"],
            "cherry_tomato_images": cherry_stats["images"],
            "cherry_tomato_boxes": cherry_stats["boxes"],
            "camel_images": camel_stats["images"],
            "camel_boxes": camel_stats["boxes"],
        }

    write_combined_data_yaml(out)
    (out / "metadata" / "summary.json").write_text(
        json.dumps(stats, indent=2, ensure_ascii=False),
        encoding="utf-8",
    )
    return stats


def resolve_data_yaml(args: argparse.Namespace) -> Path:
    if args.data is not None:
        return args.data
    if args.preset == "fruit":
        return FRUIT_DATASET / "data.yaml"
    if args.preset == "camel_bootstrap":
        return CAMEL_BOOTSTRAP_DATASET / "data.yaml"
    if args.preset == "combined_mvp":
        prepare_combined_mvp_dataset(args.combined_out)
        return args.combined_out / "data.yaml"
    raise ValueError(f"Unsupported preset: {args.preset}")


def build_train_kwargs(args: argparse.Namespace) -> dict:
    kwargs = {
        "model": args.model,
        "data": str(args.data),
        "epochs": args.epochs,
        "imgsz": args.imgsz,
        "batch": args.batch,
        "workers": args.workers,
        "project": str(args.project),
        "name": args.name,
        "seed": args.seed,
        "patience": args.patience,
        "exist_ok": args.exist_ok,
    }
    if args.device:
        kwargs["device"] = args.device
    return kwargs


def print_dataset_summary(summary: DatasetSummary) -> None:
    print("Dataset summary")
    print("===============")
    print(f"dataset: {summary.dataset_dir}")
    print("images:")
    for split in SPLITS:
        print(f"- {split}: {summary.split_image_counts.get(split, 0)}")
    print("boxes:")
    for class_id, class_name in summary.class_names.items():
        print(f"- {class_id} {class_name}: {summary.class_counts[class_id]}")


def run_training(args: argparse.Namespace) -> Path:
    from ultralytics import YOLO

    train_kwargs = build_train_kwargs(args)
    model_path = train_kwargs.pop("model")
    model = YOLO(model_path)
    result = model.train(**train_kwargs)
    save_dir = Path(getattr(result, "save_dir", args.project / args.name))

    if args.export:
        best_model = save_dir / "weights" / "best.pt"
        export_model = YOLO(str(best_model if best_model.exists() else model_path))
        export_model.export(format=args.export, imgsz=args.imgsz)

    return save_dir


def main() -> int:
    args = parse_args()
    if args.name is None:
        args.name = args.preset

    args.data = resolve_data_yaml(args)
    dataset_dir = args.data.parent
    summary = validate_dataset_for_training(
        dataset_dir,
        allow_empty_classes=args.allow_empty_classes,
    )
    print_dataset_summary(summary)

    train_kwargs = build_train_kwargs(args)
    print()
    print("Training config")
    print("===============")
    print(json.dumps(train_kwargs, indent=2, ensure_ascii=False))

    if args.prepare_only or args.dry_run:
        return 0

    save_dir = run_training(args)
    print(f"\nTraining finished: {save_dir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
