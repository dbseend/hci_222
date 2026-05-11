# TruePrice YOLO Dataset

This dataset is for the first on-device YOLO MVP model.

## Classes

```yaml
0: tomato
1: camel_doll
```

## Image Targets

Minimum MVP target:

```text
tomato: 80-120 images
camel_doll: 80-120 images
negative/background: 50 images
```

Recommended target:

```text
tomato: 200-500 images
camel_doll: 200-500 images
negative/background: 100-200 images
```

## Split

```text
train: 70%
val: 20%
test: 10%
```

## Folder Layout

```text
images/train/
images/val/
images/test/
labels/train/
labels/val/
labels/test/
```

Every labeled image should have a matching `.txt` label file with the same basename.

Example:

```text
images/train/tomato_0001.jpg
labels/train/tomato_0001.txt
```

Negative/background images may have an empty label file.

## Label Format

YOLO detection labels:

```text
class_id x_center y_center width height
```

All coordinates must be normalized from `0` to `1`.

## Class Rules

### tomato

Label one whole tomato per bbox.

Include:

```text
- Red, orange, or slightly unripe tomato
- Tomato with stem/calyx
- Tomato held by hand
- Tomato on table, plate, shelf, or market stand
```

Exclude:

```text
- Cut/cooked tomato
- Tomato sauce
- Tomato printed on packaging
- Tomato pile labeled as one object
```

### camel_doll

Label one camel-shaped souvenir/doll/ornament per bbox.

Include:

```text
- Stuffed, fabric, wooden, plastic, or metal camel souvenir
- Keychain-sized camel if the shape is clear
- Hand-held or shelf-display camel product
```

Exclude:

```text
- Real camel
- Camel drawing only
- Camel printed on shirt, cup, poster, bag, or packaging
- Tiny background camel shape
- Inseparable cluster of dolls
```

## QA Command

From repository root:

```bash
python3 tools/yolo_dataset_audit.py datasets/trueprice_yolo
```

The audit checks folder structure, image/label pairing, class IDs, coordinate ranges, and split counts.
