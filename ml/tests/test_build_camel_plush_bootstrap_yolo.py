import unittest
from pathlib import Path

from ml.scripts.build_camel_plush_bootstrap_yolo import (
    VARIANTS,
    WEAK_LABEL,
    split_sources,
)


class CamelPlushBootstrapYoloTest(unittest.TestCase):
    def test_weak_label_is_valid_single_class_full_image_box(self):
        parts = WEAK_LABEL.strip().split()

        self.assertEqual(len(parts), 5)
        self.assertEqual(parts[0], "0")
        self.assertEqual([float(value) for value in parts[1:]], [0.5, 0.5, 1.0, 1.0])

    def test_split_sources_keeps_all_images_once(self):
        images = [Path(f"image_{index}.jpg") for index in range(10)]
        split_map = split_sources(images, seed=222)
        flattened = [path for split in split_map.values() for path in split]

        self.assertEqual(sorted(flattened), sorted(images))
        self.assertEqual(len(flattened), len(set(flattened)))
        self.assertGreaterEqual(len(split_map["train"]), 1)
        self.assertGreaterEqual(len(split_map["valid"]), 1)
        self.assertGreaterEqual(len(split_map["test"]), 1)

    def test_variant_count_is_large_enough_for_bootstrap(self):
        self.assertGreaterEqual(len(VARIANTS), 10)


if __name__ == "__main__":
    unittest.main()
