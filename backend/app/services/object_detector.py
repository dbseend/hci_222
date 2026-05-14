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
    "dates": "dates",
    "fruit": "fruit",
    "grape": "grape",
    "grapefruit": "grapefruit",
    "guava": "guava",
    "kiwi": "kiwi",
    "lemon": "lemon",
    "mandarin": "mandarin",
    "mango": "mango",
    "orange": "orange",
    "peach": "peach",
    "pineapple": "pineapple",
    "plum": "plum",
    "pomegranate": "pomegranate",
    "rockmelon": "rockmelon",
    "strawberry": "strawberry",
    "tomato": "tomato",
    "watermelon": "watermelon",
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
    "dates": "تمر",
    "fruit": "فاكهة",
    "grape": "عنب",
    "grapefruit": "جريب فروت",
    "guava": "جوافة",
    "kiwi": "كيوي",
    "lemon": "ليمون",
    "mandarin": "يوسفي",
    "mango": "مانجو",
    "orange": "برتقال",
    "peach": "خوخ",
    "pineapple": "أناناس",
    "plum": "برقوق",
    "pomegranate": "رمان",
    "rockmelon": "شمام",
    "strawberry": "فراولة",
    "tomato": "طماطم",
    "watermelon": "بطيخ",
}

ZERO_SHOT_LABELS = (
    "apple",
    "avocado",
    "banana",
    "blueberry",
    "cherry",
    "cherry tomato",
    "cherry tomatoes",
    "dates",
    "grape tomato",
    "grape tomatoes",
    "grape",
    "grapes",
    "grapefruit",
    "guava",
    "kiwi",
    "lemon",
    "mandarin",
    "tangerine",
    "mango",
    "orange",
    "peach",
    "pineapple",
    "plum",
    "pomegranate",
    "rockmelon",
    "cantaloupe",
    "strawberry",
    "watermelon",
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
    "dates": "dates",
    "grape_tomato": "cherry_tomato",
    "grape_tomatoes": "cherry_tomato",
    "grape": "grape",
    "grapes": "grape",
    "grapefruit": "grapefruit",
    "guava": "guava",
    "kiwi": "kiwi",
    "lemon": "lemon",
    "mandarin": "mandarin",
    "tangerine": "mandarin",
    "mango": "mango",
    "orange": "orange",
    "peach": "peach",
    "pineapple": "pineapple",
    "plum": "plum",
    "pomegranate": "pomegranate",
    "rockmelon": "rockmelon",
    "cantaloupe": "rockmelon",
    "strawberry": "strawberry",
    "watermelon": "watermelon",
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

    def warm_up(self) -> None:
        return None


class ZeroShotObjectDetector:
    def __init__(
        self,
        inference_pipeline: Callable[..., list[dict[str, Any]]] | None = None,
        image_loader: Callable[[bytes], Any] | None = None,
    ) -> None:
        self.model_name = env_value("TRUEPRICE_ZERO_SHOT_MODEL", "google/owlvit-base-patch32")
        self._pipeline = inference_pipeline
        self._image_loader = image_loader or _load_pil_image

    def warm_up(self) -> None:
        self._load_pipeline()

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
    def __init__(
        self,
        model_path: Path | None = None,
        extra_model_paths: list[Path] | tuple[Path, ...] | None = None,
        model_loader: Callable[[Path], Any] | None = None,
    ) -> None:
        self.model_path = model_path or _model_path_from_env()
        self.extra_model_paths = (
            tuple(extra_model_paths)
            if extra_model_paths is not None
            else _extra_model_paths_from_env()
        )
        self._model_loader = model_loader
        self._model = None
        self._models = None

    def warm_up(self) -> None:
        self._load_models()

    def detect(
        self,
        image_bytes: bytes,
        filename: str,
        confidence_threshold: float = 0.25,
    ) -> DetectionResponse:
        models = self._load_models()
        suffix = _safe_suffix(filename)
        best_detection: tuple[float, str] | None = None

        with tempfile.NamedTemporaryFile(suffix=suffix, delete=True) as image_file:
            image_file.write(image_bytes)
            image_file.flush()
            for _, model in models:
                results = model(str(image_file.name), conf=confidence_threshold, verbose=False)
                candidate = _best_yolo_detection(results, model)
                if candidate is None:
                    continue
                if best_detection is None or candidate[0] > best_detection[0]:
                    best_detection = candidate

        if best_detection is None:
            raise ObjectNotDetected("No object detected")

        best_confidence, class_name = best_detection
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

    def _load_models(self):
        if self._models is not None:
            return self._models

        paths = _unique_paths((self.model_path, *self.extra_model_paths))
        self._models = [(path, self._load_model(path)) for path in paths]
        self._model = self._models[0][1]
        return self._models

    def _load_model(self, model_path: Path):
        if self._model_loader is not None:
            return self._model_loader(model_path)

        if not model_path.exists():
            raise ObjectDetectorUnavailable(f"YOLO model file not found: {model_path}")

        try:
            from ultralytics import YOLO
        except ImportError as exc:
            raise ObjectDetectorUnavailable(
                "Failed to import ultralytics. Install backend Python dependencies "
                "and required YOLO/OpenCV system libraries. "
                f"Original error: {exc}"
            ) from exc

        return YOLO(str(model_path))


def _model_path_from_env() -> Path:
    configured = env_value("TRUEPRICE_YOLO_MODEL_PATH")
    if configured:
        return _resolve_model_path(configured)
    return DEFAULT_MODEL_PATH


def _extra_model_paths_from_env() -> tuple[Path, ...]:
    configured = env_value("TRUEPRICE_YOLO_EXTRA_MODEL_PATHS")
    if configured:
        return tuple(
            _resolve_model_path(value)
            for value in configured.split(",")
            if value.strip()
        )

    return ()


def _resolve_model_path(value: str) -> Path:
    path = Path(value.strip()).expanduser()
    if not path.is_absolute():
        path = PROJECT_ROOT / path
    return path.resolve()


def _unique_paths(paths: tuple[Path, ...]) -> tuple[Path, ...]:
    unique: list[Path] = []
    seen: set[Path] = set()
    for path in paths:
        resolved = path.resolve()
        if resolved in seen:
            continue
        seen.add(resolved)
        unique.append(resolved)
    return tuple(unique)


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


def _best_yolo_detection(results, model) -> tuple[float, str] | None:
    if not results:
        return None

    result = results[0]
    boxes = getattr(result, "boxes", None)
    if boxes is None or len(boxes) == 0:
        return None

    best_index, best_confidence = _best_box(boxes)
    class_id = int(boxes.cls[best_index].item())
    return best_confidence, _class_name(result, model, class_id)


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
    mode = (env_value("TRUEPRICE_DETECTOR_MODE", "yolo") or "yolo").strip().lower()
    if mode == "zero_shot":
        return ZeroShotObjectDetector()
    if mode == "yolo":
        return YoloObjectDetector()
    mock_allowed = (
        (env_value("TRUEPRICE_ALLOW_MOCK_DETECTOR") or "").strip().lower() == "true"
    )
    if mode == "mock" and mock_allowed:
        return MockObjectDetector()
    if mode == "mock":
        return YoloObjectDetector()
    return MockObjectDetector()


def warm_up_detector() -> None:
    detector = get_detector()
    warm_up = getattr(detector, "warm_up", None)
    if callable(warm_up):
        warm_up()
