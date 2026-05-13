# Camel Plush Data Pipeline

## Core Judgment

For strict license compliance, use only sources that expose machine-readable
license, author, source page, and original URL metadata. The current MVP
collector uses Wikimedia Commons only.

The collected folder is a review set, not a train-ready detection dataset.
Some open-license results are camel toys, dolls, figures, or souvenirs rather
than soft plush. Remove false positives before bounding-box labeling.

## Collect

```bash
python3 -B ml/scripts/collect_open_camel_plush_dataset.py --target 40 --per-query 80
```

By default, the script rebuilds its managed image and metadata folders so the
manifest always matches the files on disk. Use `--keep-existing` only when
intentionally appending local review work.

Output:

```text
dataset_sources/camel_plush_open/
  images/camel_plush/
  metadata/
    manifest.csv
    manifest.jsonl
    review_queue.csv
    ATTRIBUTION.md
    skipped.json
    summary.json
```

`dataset_sources/` is ignored by Git. Keep the generated metadata with the
images when moving the dataset to Roboflow, CVAT, or LabelImg.

## License Policy

Allowed:

```text
Public domain
CC0
CC BY
CC BY-SA
```

Rejected:

```text
NC
ND
fair use
all rights reserved
unclear or missing license metadata
```

## Review and Label

1. Open `dataset_sources/camel_plush_open/metadata/review_queue.csv`.
2. Remove images that are not usable as `camel_plush`.
3. Label each valid object with one class: `camel_plush`.
4. Export YOLO format.
5. Keep `metadata/ATTRIBUTION.md` with the dataset archive.

## Bootstrap YOLO Dataset

If you need to run the training pipeline immediately from the current
license-stable seed images, build a weak-labeled augmented YOLO dataset:

```bash
python3 -B ml/scripts/build_camel_plush_bootstrap_yolo.py
```

Output:

```text
dataset_sources/camel_plush_yolo_bootstrap/
  data.yaml
  train/images/
  train/labels/
  valid/images/
  valid/labels/
  test/images/
  test/labels/
  metadata/source_attribution/
```

Current seed result:

```text
source images: 10
variants per source: 12
generated images: 120
train: 84
valid: 24
test: 12
```

Important: this bootstrap dataset uses weak full-image boxes:

```text
0 0.500000 0.500000 1.000000 1.000000
```

Use it only to make the MVP training/export path runnable. Replace these
labels with manual bounding boxes before evaluating real detection quality.

## MVP Note

Strict open-license camel plush images are sparse. If the reviewed count is
too low for training, use this set as seed data and add manually licensed
images from a source where written permission or license terms can be stored
in the same manifest format.
