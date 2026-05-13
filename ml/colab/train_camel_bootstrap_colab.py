# %% [markdown]
# # TruePrice Camel Doll YOLO Training
#
# Runtime:
# - Colab menu: Runtime > Change runtime type > T4 GPU
# - Upload `camel_doll_yolo_bootstrap.zip` when prompted.
#
# Output:
# - `best.pt` is downloaded automatically.
# - Copy that file to `backend/models/best.pt` in the local project.

# %%
!nvidia-smi
!pip install -q ultralytics

# %%
from google.colab import files

uploaded = files.upload()
zip_name = next(iter(uploaded))
print("uploaded:", zip_name)

# %%
import shutil
from pathlib import Path

work = Path("/content/trueprice")
if work.exists():
    shutil.rmtree(work)
work.mkdir(parents=True, exist_ok=True)

shutil.unpack_archive(zip_name, work)

dataset = work / "dataset_sources" / "camel_doll_yolo_bootstrap"
if not dataset.exists():
    dataset = work / "camel_doll_yolo_bootstrap"

assert dataset.exists(), f"dataset not found: {dataset}"
print(dataset)

# %%
data_yaml = dataset / "data.yaml"
data_yaml.write_text(
    f"""path: {dataset}
train: train/images
val: valid/images
test: test/images

nc: 1
names: ['camel_doll']
""",
    encoding="utf-8",
)
print(data_yaml.read_text())

# %%
from ultralytics import YOLO

model = YOLO("yolo11n.pt")
results = model.train(
    data=str(data_yaml),
    epochs=50,
    imgsz=640,
    batch=16,
    device=0,
    workers=2,
    project="/content/runs/trueprice",
    name="camel_bootstrap_colab",
    seed=222,
    patience=20,
    exist_ok=True,
)

# %%
from ultralytics import YOLO

save_dir = Path(results.save_dir)
best = save_dir / "weights" / "best.pt"
assert best.exists(), best

metrics = YOLO(str(best)).val(data=str(data_yaml), imgsz=640, device=0)
print("best:", best)

# %%
files.download(str(best))

