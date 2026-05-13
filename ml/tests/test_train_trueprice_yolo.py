import argparse
import tempfile
import unittest
from pathlib import Path

from ml.scripts.train_trueprice_yolo import (
    build_train_kwargs,
    dataset_has_any_boxes,
    load_class_names,
    remap_label_line,
    validate_dataset_for_training,
)


class TrainTruePriceYoloTest(unittest.TestCase):
    def test_load_class_names_supports_inline_list(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "data.yaml").write_text(
                "names: ['tomato', 'cherry_tomato', 'camel_doll']\n",
                encoding="utf-8",
            )

            self.assertEqual(
                load_class_names(root),
                {0: "tomato", 1: "cherry_tomato", 2: "camel_doll"},
            )

    def test_load_class_names_supports_mapping_block(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "data.yaml").write_text(
                "names:\n  0: tomato\n  1: camel_doll\n",
                encoding="utf-8",
            )

            self.assertEqual(load_class_names(root), {0: "tomato", 1: "camel_doll"})

    def test_remap_label_line_rewrites_class_id_only(self):
        self.assertEqual(
            remap_label_line("0 0.500000 0.500000 1.000000 1.000000", 2),
            "2 0.500000 0.500000 1.000000 1.000000",
        )

    def test_validate_dataset_requires_non_empty_classes_by_default(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "data.yaml").write_text(
                "path: .\ntrain: train/images\nval: valid/images\nnames: ['tomato', 'camel_doll']\n",
                encoding="utf-8",
            )
            for split in ("train", "valid", "test"):
                (root / split / "images").mkdir(parents=True)
                (root / split / "labels").mkdir(parents=True)
            (root / "train" / "images" / "tomato.jpg").write_bytes(b"fake")
            (root / "train" / "labels" / "tomato.txt").write_text(
                "0 0.5 0.5 0.2 0.2\n",
                encoding="utf-8",
            )

            with self.assertRaises(ValueError):
                validate_dataset_for_training(root, allow_empty_classes=False)

            summary = validate_dataset_for_training(root, allow_empty_classes=True)
            self.assertEqual(summary.class_counts[0], 1)
            self.assertEqual(summary.class_counts[1], 0)

    def test_build_train_kwargs_matches_ultralytics_api(self):
        args = argparse.Namespace(
            data=Path("dataset_sources/trueprice_yolo_bootstrap/data.yaml"),
            model="yolo11n.pt",
            epochs=30,
            imgsz=640,
            batch=16,
            device=None,
            workers=4,
            project=Path("runs/trueprice"),
            name="camel_bootstrap",
            seed=222,
            patience=20,
            exist_ok=True,
        )

        kwargs = build_train_kwargs(args)

        self.assertEqual(kwargs["data"], "dataset_sources/trueprice_yolo_bootstrap/data.yaml")
        self.assertEqual(kwargs["model"], "yolo11n.pt")
        self.assertEqual(kwargs["epochs"], 30)
        self.assertEqual(kwargs["imgsz"], 640)
        self.assertEqual(kwargs["batch"], 16)
        self.assertEqual(kwargs["project"], "runs/trueprice")
        self.assertEqual(kwargs["name"], "camel_bootstrap")
        self.assertNotIn("device", kwargs)

    def test_dataset_has_any_boxes_ignores_empty_scaffold(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            for split in ("train", "valid", "test"):
                (root / split / "labels").mkdir(parents=True)
            (root / "train" / "labels" / "empty.txt").write_text("", encoding="utf-8")

            self.assertFalse(dataset_has_any_boxes(root))

            (root / "valid" / "labels" / "box.txt").write_text(
                "0 0.5 0.5 1.0 1.0\n",
                encoding="utf-8",
            )
            self.assertTrue(dataset_has_any_boxes(root))


if __name__ == "__main__":
    unittest.main()
