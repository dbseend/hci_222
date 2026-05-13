# ML Workspace

Object detection dataset preparation, audit, and Colab training assets live here.
Generated datasets and model artifacts stay outside Git via the root `.gitignore`.

## Layout

- `scripts/`: dataset collection, conversion, and YOLO export merge scripts
- `tools/`: local validation tools for dataset structure
- `notebooks/`: Colab notebooks for training/export handoff

## Local Data Contract

The scripts expect local-only folders at the repository root:

- `dataset_sources/`: downloaded raw sources and intermediate review images
- `dataset_open_v1/`: generated open-data YOLO dataset and archives
- `datasets/`: legacy or ad hoc local dataset workspaces
- `outputs/`, `runs/`, `wandb/`: local run outputs

These folders are intentionally ignored and must not be committed.

## Common Commands

Build the current multi-class fruit YOLO dataset:

```bash
python3 ml/scripts/build_open_fruit_camel_dataset.py
```

Collect a strict-license camel plush/toy review set:

```bash
python3 -B ml/scripts/collect_open_camel_plush_dataset.py --target 40 --per-query 80
```

Build a weak-labeled camel plush YOLO bootstrap dataset from the reviewed seed:

```bash
python3 -B ml/scripts/build_camel_plush_bootstrap_yolo.py
```

See `ml/CAMEL_PLUSH_DATA_PIPELINE.md` before labeling or training. The output is
license-filtered review/bootstrap data. Manual bounding boxes are still required
for real detector quality.

Audit a YOLO dataset:

```bash
python3 ml/tools/yolo_dataset_audit.py datasets/trueprice_yolo
```

Train/export in Colab:

```text
ml/notebooks/train_trueprice_yolo_colab.ipynb
```

Upload the local zip when the notebook asks for it:

```text
dataset_open_v1/yolo_multiclass_fruit.zip
```
