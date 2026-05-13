#!/usr/bin/env python3
"""Create local folders for Roboflow YOLO exports used by TruePrice."""

from __future__ import annotations

import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
DATASET_SOURCES = ROOT / "dataset_sources"
EXPORTS = DATASET_SOURCES / "roboflow_exports"
TARGETS = {
    "cherry_tomato_yolo": ["cherry_tomato"],
    "camel_doll_yolo": ["camel_doll"],
}
SPLITS = ("train", "valid", "test")


def write_data_yaml(dataset_dir: Path, class_names: list[str]) -> None:
    names = "[" + ", ".join(f"'{name}'" for name in class_names) + "]"
    (dataset_dir / "data.yaml").write_text(
        f"""path: {dataset_dir}
train: train/images
val: valid/images
test: test/images

nc: {len(class_names)}
names: {names}
""",
        encoding="utf-8",
    )


def main() -> int:
    EXPORTS.mkdir(parents=True, exist_ok=True)
    summary = {"exports": str(EXPORTS), "targets": {}}
    for name, class_names in TARGETS.items():
        dataset_dir = DATASET_SOURCES / name
        for split in SPLITS:
            (dataset_dir / split / "images").mkdir(parents=True, exist_ok=True)
            (dataset_dir / split / "labels").mkdir(parents=True, exist_ok=True)
        (dataset_dir / "metadata").mkdir(parents=True, exist_ok=True)
        write_data_yaml(dataset_dir, class_names)
        summary["targets"][name] = {
            "path": str(dataset_dir),
            "classes": class_names,
        }

    readme = DATASET_SOURCES / "README_TRUEPRICE_DATASETS.md"
    readme.write_text(
        """# TruePrice Local Dataset Workspace

Generated and downloaded data in this folder is local-only and ignored by Git.

## Roboflow ZIP Inbox

Put downloaded Roboflow YOLO export zip files here:

```text
dataset_sources/roboflow_exports/
```

## Target YOLO Folders

Cherry tomato exports should be merged with:

```bash
python3 ml/scripts/merge_roboflow_yolo_export.py dataset_sources/roboflow_exports/<zip-file>.zip --source-name cherry_tomato_public
```

Camel doll exports from Roboflow/CVAT/LabelImg should end up as:

```text
dataset_sources/camel_doll_yolo/
  data.yaml
  train/images/
  train/labels/
  valid/images/
  valid/labels/
  test/images/
  test/labels/
```

If manual labeling is not ready, use the generated bootstrap dataset:

```text
dataset_sources/camel_doll_yolo_bootstrap/
```
""",
        encoding="utf-8",
    )
    print(json.dumps(summary, indent=2, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
