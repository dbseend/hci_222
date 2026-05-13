import tempfile
from collections.abc import Callable
from io import BytesIO
from functools import lru_cache
from pathlib import Path
from typing import Any

from app.core.env import PROJECT_ROOT, env_value
from app.models.detection import DetectionResponse
from app.services.catalog_service import get_product


BACKEND_DIR = Path(__file__).resolve().parents[2]
DEFAULT_MODEL_PATH = BACKEND_DIR / "models" / "best.pt"

CLASS_TO_PRODUCT_ID = {
    "apple": "apple",
    "avocado": "avocado",
    "banana": "banana",
    "blueberry": "blueberry",
    "cherry": "cherry",
    "cherry_tomato": "cherry_tomato",
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
    "banana": "موز",
    "blueberry": "توت أزرق",
    "camel_doll": "دمية جمل",
    "cherry": "كرز",
    "cherry_tomato": "طماطم كرزية",
    "fruit": "فاكهة",
    "kiwi": "كيوي",
    "mango": "مانجو",
    "orange": "برتقال",
    "rockmelon": "شمام",
    "strawberry": "فراولة",
    "tomato": "طماطم",
}

ZERO_SHOT_LABELS = (
    "apple",
    "avocado",
    "banana",
    "blueberry",
    "cherry",
    "cherry tomato",
    "cherry tomatoes",
    "grape tomato",
    "grape tomatoes",
    "kiwi",
    "mango",
    "orange",
    "rockmelon",
    "cantaloupe",
    "strawberry",
    "camel plush toy",
    "stuffed camel toy",
    "camel doll",
)

ZERO_SHOT_LABEL_TO_PRODUCT_ID = {
    "apple": "apple",
    "avocado": "avocado",
    "banana": "banana",
    "blueberry": "blueberry",
    "cherry": "cherry",
    "cherry_tomato": "cherry_tomato",
    "cherry_tomatoes": "cherry_tomato",
    "grape_tomato": "cherry_tomato",
    "grape_tomatoes": "cherry_tomato",
    "kiwi": "kiwi",
    "mango": "mango",
    "orange": "orange",
    "rockmelon": "rockmelon",
    "cantaloupe": "rockmelon",
    "strawberry": "strawberry",
    "camel_plush_toy": "camel_doll",
    "stuffed_camel_toy": "camel_doll",
    "camel_doll": "camel_doll",
}


class ObjectDetectorUnavailable(RuntimeError):
    pass


class ObjectNotDetected(RuntimeError):
    pass


class MockObjectDetector:
    def detect(
        self,
        image_bytes: bytes,
        filename: str,
        confidence_threshold: float = 0.25,
    ) -> DetectionResponse:
        if not image_bytes:
            raise ObjectNotDetected("Uploaded image is empty")

        product_id = _mock_product_id(filename)
        product = get_product(product_id)
        if product is None:
            raise ObjectDetectorUnavailable(f"Mock product is not in catalog: {product_id}")

        return DetectionResponse(
            product_id=product.product_id,
            name_kr=product.display_name,
            name_ar=PRODUCT_AR_NAMES.get(product.product_id, product.display_name),
            confidence=0.93,
            detected_price=None,
        )


class ZeroShotObjectDetector:
    def __init__(
        self,
        inference_pipeline: Callable[..., list[dict[str, Any]]] | None = None,
        image_loader: Callable[[bytes], Any] | None = None,
    ) -> None:
        self.model_name = env_value("TRUEPRICE_ZERO_SHOT_MODEL", "google/owlvit-base-patch32")
        self._pipeline = inference_pipeline
        self._image_loader = image_loader or _load_pil_image

    def detect(
        self,
        image_bytes: bytes,
        filename: str,
        confidence_threshold: float = 0.25,
    ) -> DetectionResponse:
        if not image_bytes:
            raise ObjectNotDetected("Uploaded image is empty")

        detector = self._load_pipeline()
        image = self._image_loader(image_bytes)
        predictions = detector(image, candidate_labels=list(ZERO_SHOT_LABELS))
        if not predictions:
            raise ObjectNotDetected("No zero-shot object detected")

        best = max(predictions, key=_zero_shot_score)
        confidence = _zero_shot_score(best)
        label = str(best.get("label", ""))

        if confidence < confidence_threshold:
            raise ObjectNotDetected(
                f"Best zero-shot prediction is below threshold: {label} ({confidence:.2f})"
            )

        product_id = ZERO_SHOT_LABEL_TO_PRODUCT_ID.get(_normalize_class_name(label))
        if product_id is None:
            raise ObjectNotDetected(f"Unsupported zero-shot label: {label}")

        product = get_product(product_id)
        if product is None:
            raise ObjectDetectorUnavailable(f"Detected product is not in catalog: {product_id}")

        return DetectionResponse(
            product_id=product.product_id,
            name_kr=product.display_name,
            name_ar=PRODUCT_AR_NAMES.get(product.product_id, product.display_name),
            confidence=round(confidence, 4),
            detected_price=None,
        )

    def _load_pipeline(self):
        if self._pipeline is not None:
            return self._pipeline

        try:
            from transformers import pipeline
        except ImportError as exc:
            raise ObjectDetectorUnavailable(
                "transformers is not installed. Run `pip install -r backend/requirements.txt`."
            ) from exc

        self._pipeline = pipeline(
            task="zero-shot-object-detection",
            model=self.model_name,
        )
        return self._pipeline


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


def _mock_product_id(filename: str) -> str:
    normalized = _normalize_class_name(Path(filename or "").stem)
    for class_name, product_id in CLASS_TO_PRODUCT_ID.items():
        if class_name in normalized:
            return product_id
    return "tomato"


def _safe_suffix(filename: str) -> str:
    suffix = Path(filename or "").suffix.lower()
    if suffix in {".jpg", ".jpeg", ".png", ".webp", ".bmp"}:
        return suffix
    return ".jpg"


def _load_pil_image(image_bytes: bytes):
    try:
        from PIL import Image, ImageOps
    except ImportError as exc:
        raise ObjectDetectorUnavailable(
            "Pillow is not installed. Run `pip install -r backend/requirements.txt`."
        ) from exc

    try:
        image = Image.open(BytesIO(image_bytes))
        return ImageOps.exif_transpose(image).convert("RGB")
    except Exception as exc:
        raise ObjectNotDetected("Uploaded image is not a readable image") from exc


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


def _zero_shot_score(prediction: dict[str, Any]) -> float:
    raw_score = prediction.get("score", prediction.get("confidence", 0))
    return float(raw_score)


def _normalize_class_name(class_name: str) -> str:
    return class_name.strip().lower().replace(" ", "_").replace("-", "_")


@lru_cache(maxsize=1)
def get_detector():
    mode = (env_value("TRUEPRICE_DETECTOR_MODE", "mock") or "mock").strip().lower()
    if mode == "zero_shot":
        return ZeroShotObjectDetector()
    if mode == "yolo":
        return YoloObjectDetector()
    return MockObjectDetector()
