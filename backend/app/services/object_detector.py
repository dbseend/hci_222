import tempfile
from functools import lru_cache
from pathlib import Path

from app.core.env import PROJECT_ROOT, env_value
from app.models.detection import DetectionResponse
from app.services.catalog_service import get_product


BACKEND_DIR = Path(__file__).resolve().parents[2]
DEFAULT_MODEL_PATH = BACKEND_DIR / "models" / "best.pt"

CLASS_TO_PRODUCT_ID = {
    "apple": "apple",
    "avocado": "avocado",
    "blueberry": "blueberry",
    "cherry": "cherry",
    "fruit": "fruit",
    "kiwi": "kiwi",
    "mango": "mango",
    "orange": "orange",
    "rockmelon": "rockmelon",
    "strawberry": "strawberry",
    "tomato": "tomato",
    "camel_doll": "camel_doll",
}

PRODUCT_AR_NAMES = {
    "apple": "تفاح",
    "avocado": "أفوكادو",
    "blueberry": "توت أزرق",
    "camel_doll": "دمية جمل",
    "cherry": "كرز",
    "fruit": "فاكهة",
    "kiwi": "كيوي",
    "mango": "مانجو",
    "orange": "برتقال",
    "rockmelon": "شمام",
    "strawberry": "فراولة",
    "tomato": "طماطم",
}


class ObjectDetectorUnavailable(RuntimeError):
    pass


class ObjectNotDetected(RuntimeError):
    pass


class YoloObjectDetector:
    def __init__(self, model_path: Path | None = None) -> None:
        self.model_path = model_path or _model_path_from_env()
        self._model = None

    def detect(
        self,
        image_bytes: bytes,
        filename: str,
        confidence_threshold: float = 0.25,
    ) -> DetectionResponse:
        model = self._load_model()
        suffix = _safe_suffix(filename)

        with tempfile.NamedTemporaryFile(suffix=suffix, delete=True) as image_file:
            image_file.write(image_bytes)
            image_file.flush()
            results = model(str(image_file.name), conf=confidence_threshold, verbose=False)

        if not results:
            raise ObjectNotDetected("No YOLO result returned")

        result = results[0]
        boxes = getattr(result, "boxes", None)
        if boxes is None or len(boxes) == 0:
            raise ObjectNotDetected("No object detected")

        best_index, best_confidence = _best_box(boxes)
        class_id = int(boxes.cls[best_index].item())
        class_name = _class_name(result, model, class_id)
        product_id = CLASS_TO_PRODUCT_ID.get(_normalize_class_name(class_name))

        if product_id is None:
            raise ObjectNotDetected(f"Unsupported detected class: {class_name}")

        product = get_product(product_id)
        if product is None:
            raise ObjectDetectorUnavailable(f"Detected product is not in catalog: {product_id}")

        return DetectionResponse(
            product_id=product.product_id,
            name_kr=product.display_name,
            name_ar=PRODUCT_AR_NAMES.get(product.product_id, product.display_name),
            confidence=round(best_confidence, 4),
            detected_price=None,
        )

    def _load_model(self):
        if self._model is not None:
            return self._model

        if not self.model_path.exists():
            raise ObjectDetectorUnavailable(f"YOLO model file not found: {self.model_path}")

        try:
            from ultralytics import YOLO
        except ImportError as exc:
            raise ObjectDetectorUnavailable(
                "ultralytics is not installed. Run `pip install -r backend/requirements.txt`."
            ) from exc

        self._model = YOLO(str(self.model_path))
        return self._model


def _model_path_from_env() -> Path:
    configured = env_value("TRUEPRICE_YOLO_MODEL_PATH")
    if configured:
        path = Path(configured).expanduser()
        if not path.is_absolute():
            path = PROJECT_ROOT / path
        return path.resolve()
    return DEFAULT_MODEL_PATH


def _safe_suffix(filename: str) -> str:
    suffix = Path(filename or "").suffix.lower()
    if suffix in {".jpg", ".jpeg", ".png", ".webp", ".bmp"}:
        return suffix
    return ".jpg"


def _best_box(boxes) -> tuple[int, float]:
    confidences = boxes.conf
    best_index = int(confidences.argmax().item())
    return best_index, float(confidences[best_index].item())


def _class_name(result, model, class_id: int) -> str:
    names = getattr(result, "names", None) or getattr(model, "names", {})
    if isinstance(names, dict):
        return str(names.get(class_id, class_id))
    if isinstance(names, list) and 0 <= class_id < len(names):
        return str(names[class_id])
    return str(class_id)


def _normalize_class_name(class_name: str) -> str:
    return class_name.strip().lower().replace(" ", "_").replace("-", "_")


@lru_cache(maxsize=1)
def get_detector() -> YoloObjectDetector:
    return YoloObjectDetector()
