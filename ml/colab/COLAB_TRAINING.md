# Colab Training

## Core Judgment

Use Colab GPU for the first real MVP training run. Local CPU training works,
but it is slow and ties up the Mac. The current weak-label camel dataset is
small enough to upload as a zip.

## Steps

1. Open `ml/colab/train_camel_bootstrap_colab.ipynb` in Colab.
2. Upload `ml/colab/camel_doll_yolo_bootstrap.zip` when the notebook asks.
3. Set runtime to GPU.
4. Run all cells.
5. Download `best.pt`.
6. Replace local `backend/models/best.pt`.

## Local Replacement

```bash
cp ~/Downloads/best.pt backend/models/best.pt
```

Then restart FastAPI:

```bash
uvicorn backend.app.main:app --host 0.0.0.0 --port 8000
```

## Important Limitation

This dataset uses full-image weak labels. It is enough for class-project MVP
pipeline validation, but if the detection box is unstable, move to manual
bounding boxes for 20-30 high-quality camel doll images.
