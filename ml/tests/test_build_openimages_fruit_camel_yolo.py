import random
import tempfile
import unittest
from pathlib import Path

from PIL import Image

from ml.scripts import build_openimages_fruit_camel_yolo as build


class BuildOpenImagesFruitCamelYoloTest(unittest.TestCase):
    def test_read_boxes_keeps_only_target_classes_as_yolo_rows(self):
        with tempfile.TemporaryDirectory() as tmp:
            csv_path = Path(tmp) / "boxes.csv"
            csv_path.write_text(
                "ImageID,Source,LabelName,Confidence,XMin,XMax,YMin,YMax\n"
                "img1,x,/m/014j1m,1,0.1,0.5,0.2,0.6\n"
                "img1,x,/m/0cmf2,1,0,1,0,1\n"
                "img2,x,/m/0fldg,1,0,1,0,0.5\n"
            )

            boxes = build.read_boxes(csv_path, has_header=True)

        self.assertEqual(set(boxes), {"img1", "img2"})
        cls, x, y, w, h = boxes["img1"][0]
        self.assertEqual(cls, 0)
        self.assertAlmostEqual(x, 0.3)
        self.assertAlmostEqual(y, 0.4)
        self.assertAlmostEqual(w, 0.4)
        self.assertAlmostEqual(h, 0.4)
        self.assertEqual(boxes["img2"][0][0], 3)

    def test_pick_images_caps_each_class(self):
        boxes = {f"a{i}": [(0, 0.5, 0.5, 1, 1)] for i in range(10)}
        boxes.update({f"m{i}": [(3, 0.5, 0.5, 1, 1)] for i in range(2)})

        chosen = build.pick_images(boxes, per_class=3, rng=random.Random(0))

        self.assertEqual(sum(i.startswith("a") for i in chosen), 3)
        self.assertEqual(sum(i.startswith("m") for i in chosen), 2)

    def test_near_duplicate_detects_resized_copy_but_not_different_image(self):
        gradient = Image.linear_gradient("L").convert("RGB")
        resized = gradient.resize((64, 64))
        flipped = gradient.transpose(Image.Transpose.FLIP_TOP_BOTTOM)

        hashes = [build.average_hash(gradient)]

        self.assertTrue(build.is_near_duplicate(build.average_hash(resized), hashes))
        self.assertFalse(build.is_near_duplicate(build.average_hash(flipped), hashes))

    def test_write_list_oversamples_rare_classes(self):
        with tempfile.TemporaryDirectory() as tmp:
            original = build.OUT
            build.OUT = Path(tmp)
            try:
                build.write_list(
                    "train",
                    [(Path("apple.jpg"), {0}), (Path("mango.jpg"), {0, 3}), (Path("camel.jpg"), {5})],
                    oversample=True,
                )
                lines = (Path(tmp) / "train.txt").read_text().split()
            finally:
                build.OUT = original

        self.assertEqual(lines.count("apple.jpg"), 1)
        self.assertEqual(lines.count("mango.jpg"), build.OVERSAMPLE[3])
        self.assertEqual(lines.count("camel.jpg"), build.OVERSAMPLE[build.CAMEL_ID])


if __name__ == "__main__":
    unittest.main()
