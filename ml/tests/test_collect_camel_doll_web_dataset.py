import tempfile
import unittest
from pathlib import Path

from ml.scripts.collect_camel_doll_web_dataset import (
    extract_candidates,
    load_pages,
    next_image_index,
    reset_output,
)


class CollectCamelDollWebDatasetTest(unittest.TestCase):
    def test_extract_candidates_keeps_relevant_product_images(self):
        html = """
        <html>
          <head>
            <meta property="og:image" content="/cdn/camel-plush-main.jpg">
          </head>
          <body>
            <img src="/assets/logo.png" alt="logo">
            <img src="/images/camel-stuffed-toy-side.webp" alt="Camel stuffed toy side">
            <img src="/images/chair.jpg" alt="chair">
            <img data-src="/images/dubai-camel-doll-front.jpg" alt="Dubai camel doll">
          </body>
        </html>
        """

        candidates = extract_candidates("https://example.test/product", html)
        urls = {candidate.image_url for candidate in candidates}

        self.assertIn("https://example.test/cdn/camel-plush-main.jpg", urls)
        self.assertIn("https://example.test/images/camel-stuffed-toy-side.webp", urls)
        self.assertIn("https://example.test/images/dubai-camel-doll-front.jpg", urls)
        self.assertNotIn("https://example.test/assets/logo.png", urls)

    def test_reset_output_creates_review_structure(self):
        with tempfile.TemporaryDirectory() as tmp:
            out = Path(tmp) / "camel_doll_web"

            reset_output(out, keep_existing=False)

            self.assertTrue((out / "images" / "camel_doll").exists())
            self.assertTrue((out / "metadata").exists())

    def test_next_image_index_continues_existing_sequence(self):
        with tempfile.TemporaryDirectory() as tmp:
            image_dir = Path(tmp)
            (image_dir / "camel_doll_web_0001.jpg").write_bytes(b"one")
            (image_dir / "camel_doll_web_0017.webp").write_bytes(b"two")

            self.assertEqual(next_image_index(image_dir), 18)

    def test_load_pages_can_skip_builtin_seed_pages(self):
        with tempfile.TemporaryDirectory() as tmp:
            pages_file = Path(tmp) / "pages.txt"
            pages_file.write_text("https://example.test/one\n", encoding="utf-8")

            self.assertEqual(
                load_pages(pages_file, include_seed_pages=False),
                ["https://example.test/one"],
            )


if __name__ == "__main__":
    unittest.main()
