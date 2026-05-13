import unittest

from ml.scripts.collect_open_camel_plush_dataset import (
    license_allowed,
    text_matches_scope,
)


class CamelPlushCollectorTest(unittest.TestCase):
    def test_license_allowed_accepts_open_commercial_licenses(self):
        self.assertTrue(license_allowed("CC BY-SA 4.0", "Creative Commons Attribution-Share Alike", ""))
        self.assertTrue(license_allowed("CC0", "Public domain", ""))
        self.assertTrue(license_allowed("Public domain", "Public domain", ""))

    def test_license_allowed_rejects_nc_nd_and_unclear_licenses(self):
        self.assertFalse(license_allowed("CC BY-NC 4.0", "NonCommercial", ""))
        self.assertFalse(license_allowed("CC BY-ND 4.0", "No derivatives", ""))
        self.assertFalse(license_allowed("", "", ""))

    def test_text_matches_scope_requires_camel_and_toy_terms(self):
        metadata = {
            "ImageDescription": {"value": "A camel plush toy on a table"},
            "Categories": {"value": "Stuffed animals|Toy camels"},
        }
        self.assertTrue(text_matches_scope("File:Camel toy.jpg", metadata))

    def test_text_matches_scope_rejects_living_camel_context(self):
        metadata = {
            "ImageDescription": {"value": "A camel in the desert"},
            "Categories": {"value": "Arabian camel|Zoo animals"},
        }
        self.assertFalse(text_matches_scope("File:Arabian camel at zoo.jpg", metadata))


if __name__ == "__main__":
    unittest.main()
