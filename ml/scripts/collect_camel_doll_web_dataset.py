#!/usr/bin/env python3
"""Collect camel doll product images for class-project YOLO bootstrapping.

This collector is intentionally pragmatic for a non-production class project.
It downloads visible product images from a small allowlist of camel plush/toy
product pages and writes source metadata next to the images for review.

The output is a review dataset, not a final train-ready dataset. Use Roboflow,
CVAT, or LabelImg to remove bad images and draw `camel_doll` boxes before real
fine-tuning.
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import html
import json
import re
import shutil
import subprocess
import sys
import time
from dataclasses import dataclass
from pathlib import Path
from urllib.parse import urljoin, urlparse


ROOT = Path(__file__).resolve().parents[2]
DEFAULT_OUT = ROOT / "dataset_sources" / "camel_doll_web"
USER_AGENT = "TruePrice HCI class dataset collection/0.1"
IMAGE_EXTENSIONS = {".jpg", ".jpeg", ".png", ".webp"}
IMAGE_KEYWORDS = (
    "camel",
    "plush",
    "stuffed",
    "toy",
    "doll",
    "souvenir",
)
SKIP_URL_MARKERS = (
    "logo",
    "icon",
    "avatar",
    "sprite",
    "placeholder",
    "payment",
    "badge",
    "banner",
)

SEED_PAGES = (
    "https://mister-plush.com/products/camel-plush",
    "https://aljabergallery.com/product/dubai-camel-soft-toy-plush-stuffed-animal-souvenir/",
    "https://www.jadeesantiquebearshoppe.com/products/vintage-tunisia-souvenir-dromedary-camel-plush-toy-50-cm",
    "https://www.thehujjajstore.com/products/souvenir-toy3",
    "https://royalempireexpress.com/product/camel-stuffed-animals-plush-soft-dubai-souvenir-toy-20cm/",
    "https://anwo.com/store/camel_stuffed_plush_dromedary.htm",
    "https://monami-designs.com/products/st1245",
    "https://www.meesho.com/camel-stuffed-soft-toy-25-cm/p/7cwlh7",
)


@dataclass(frozen=True)
class Candidate:
    image_url: str
    page_url: str
    source_hint: str


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Collect camel doll web images.")
    parser.add_argument(
        "--out",
        type=Path,
        default=DEFAULT_OUT,
        help=f"Output review dataset directory. Default: {DEFAULT_OUT}",
    )
    parser.add_argument(
        "--pages-file",
        type=Path,
        default=None,
        help="Optional newline-delimited product page URLs to add to the built-in seed pages.",
    )
    parser.add_argument(
        "--no-seed-pages",
        action="store_true",
        help="Use only --pages-file URLs instead of also trying the built-in seed pages.",
    )
    parser.add_argument("--limit", type=int, default=120)
    parser.add_argument("--keep-existing", action="store_true")
    parser.add_argument("--dry-run", action="store_true")
    return parser.parse_args()


def run_curl(url: str, output: Path | None = None) -> bytes:
    cmd = [
        "curl",
        "-L",
        "--fail",
        "--retry",
        "0",
        "--connect-timeout",
        "15",
        "--max-time",
        "15",
        "-A",
        USER_AGENT,
    ]
    if output is not None:
        cmd.extend(["-o", str(output)])
    cmd.append(url)

    result = subprocess.run(cmd, check=False, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if result.returncode != 0:
        raise RuntimeError(result.stderr.decode("utf-8", "replace").strip())
    return result.stdout


def reset_output(out: Path, keep_existing: bool) -> None:
    if out.exists() and not keep_existing:
        shutil.rmtree(out)
    (out / "images" / "camel_doll").mkdir(parents=True, exist_ok=True)
    (out / "metadata").mkdir(parents=True, exist_ok=True)


def load_pages(path: Path | None, include_seed_pages: bool = True) -> list[str]:
    pages = list(SEED_PAGES) if include_seed_pages else []
    if path is not None and path.exists():
        for raw_line in path.read_text(encoding="utf-8").splitlines():
            line = raw_line.strip()
            if line and not line.startswith("#"):
                pages.append(line)
    return list(dict.fromkeys(pages))


def extract_candidates(page_url: str, html_text: str) -> list[Candidate]:
    candidates: list[Candidate] = []
    decoded = html.unescape(html_text)

    for match in re.finditer(
        r'<meta[^>]+(?:property|name)=["\'](?:og:image|twitter:image)["\'][^>]+content=["\']([^"\']+)["\']',
        decoded,
        re.I,
    ):
        candidates.append(Candidate(urljoin(page_url, match.group(1)), page_url, "meta-image"))

    for match in re.finditer(r'<img\b[^>]*>', decoded, re.I):
        tag = match.group(0)
        src = attr_value(tag, "src") or attr_value(tag, "data-src") or attr_value(tag, "data-original")
        srcset = attr_value(tag, "srcset") or attr_value(tag, "data-srcset")
        alt = attr_value(tag, "alt") or ""
        title = attr_value(tag, "title") or ""
        hint = f"{alt} {title}".lower()
        if src and (is_relevant_hint(hint) or is_relevant_url(src)):
            candidates.append(Candidate(urljoin(page_url, src), page_url, hint.strip() or "img"))
        if srcset and (is_relevant_hint(hint) or is_relevant_url(srcset)):
            best = best_srcset_url(srcset)
            if best:
                candidates.append(Candidate(urljoin(page_url, best), page_url, hint.strip() or "srcset"))

    for match in re.finditer(r'https?://[^"\'\s<>]+?\.(?:jpg|jpeg|png|webp)(?:\?[^"\'\s<>]*)?', decoded, re.I):
        url = match.group(0)
        if is_relevant_url(url):
            candidates.append(Candidate(url, page_url, "raw-url"))

    unique: dict[str, Candidate] = {}
    for candidate in candidates:
        normalized = normalize_image_url(candidate.image_url)
        if normalized and should_keep_url(normalized):
            unique[normalized] = Candidate(normalized, candidate.page_url, candidate.source_hint)
    return list(unique.values())


def attr_value(tag: str, name: str) -> str | None:
    match = re.search(rf'\b{name}\s*=\s*["\']([^"\']+)["\']', tag, re.I)
    return match.group(1) if match else None


def best_srcset_url(srcset: str) -> str | None:
    choices = []
    for part in srcset.split(","):
        tokens = part.strip().split()
        if not tokens:
            continue
        weight = 1
        if len(tokens) > 1:
            raw_weight = tokens[1].rstrip("w").rstrip("x")
            if raw_weight.isdigit():
                weight = int(raw_weight)
        choices.append((weight, tokens[0]))
    if not choices:
        return None
    return max(choices, key=lambda item: item[0])[1]


def is_relevant_hint(value: str) -> bool:
    lowered = value.lower()
    return "camel" in lowered and any(keyword in lowered for keyword in IMAGE_KEYWORDS)


def is_relevant_url(value: str) -> bool:
    lowered = value.lower()
    return "camel" in lowered and any(keyword in lowered for keyword in ("plush", "toy", "doll", "stuffed"))


def normalize_image_url(url: str) -> str:
    url = html.unescape(url).strip()
    if not url or url.startswith("data:"):
        return ""
    return url


def should_keep_url(url: str) -> bool:
    lowered = url.lower()
    if any(marker in lowered for marker in SKIP_URL_MARKERS):
        return False
    suffix = Path(urlparse(url).path).suffix.lower()
    return suffix in IMAGE_EXTENSIONS or any(ext in lowered for ext in IMAGE_EXTENSIONS)


def image_digest(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def valid_image(path: Path) -> bool:
    try:
        from PIL import Image
    except ImportError:
        return path.stat().st_size > 8_000

    try:
        with Image.open(path) as image:
            width, height = image.size
        return width >= 220 and height >= 220 and path.stat().st_size > 8_000
    except Exception:
        return False


def download_candidates(candidates: list[Candidate], out: Path, limit: int, dry_run: bool) -> dict:
    image_dir = out / "images" / "camel_doll"
    manifest_rows: list[dict[str, str]] = []
    seen_digests: set[str] = existing_digests(image_dir)
    skipped: list[dict[str, str]] = []
    next_index = next_image_index(image_dir)

    for index, candidate in enumerate(candidates, start=1):
        if len(manifest_rows) >= limit:
            break

        suffix = Path(urlparse(candidate.image_url).path).suffix.lower()
        if suffix not in IMAGE_EXTENSIONS:
            suffix = ".jpg"
        stem = f"camel_doll_web_{next_index:04d}"
        next_index += 1
        tmp = image_dir / f"{stem}.download"
        dst = image_dir / f"{stem}{suffix}"

        if dry_run:
            manifest_rows.append(row_for(candidate, dst, "dry-run", ""))
            continue

        try:
            run_curl(candidate.image_url, tmp)
            if not valid_image(tmp):
                skipped.append(row_for(candidate, tmp, "invalid-image", ""))
                tmp.unlink(missing_ok=True)
                continue
            digest = image_digest(tmp)
            if digest in seen_digests:
                skipped.append(row_for(candidate, tmp, "duplicate", digest))
                tmp.unlink(missing_ok=True)
                continue
            seen_digests.add(digest)
            tmp.rename(dst)
            manifest_rows.append(row_for(candidate, dst, "downloaded", digest))
        except Exception as exc:
            skipped.append(row_for(candidate, dst, f"download-error: {exc}", ""))
            tmp.unlink(missing_ok=True)

    write_manifest(out, manifest_rows, skipped)
    return {
        "dataset_root": str(out),
        "images": len(manifest_rows),
        "existing_images": max(0, next_index - len(manifest_rows) - 1),
        "skipped": len(skipped),
        "candidates": len(candidates),
        "status": "review_only_needs_manual_bbox",
    }


def existing_digests(image_dir: Path) -> set[str]:
    digests: set[str] = set()
    for image_path in image_dir.iterdir() if image_dir.exists() else []:
        if image_path.is_file() and image_path.suffix.lower() in IMAGE_EXTENSIONS:
            try:
                digests.add(image_digest(image_path))
            except Exception:
                continue
    return digests


def next_image_index(image_dir: Path) -> int:
    max_index = 0
    for image_path in image_dir.iterdir() if image_dir.exists() else []:
        match = re.search(r"camel_doll_web_(\d+)", image_path.stem)
        if match:
            max_index = max(max_index, int(match.group(1)))
    return max_index + 1


def row_for(candidate: Candidate, path: Path, status: str, digest: str) -> dict[str, str]:
    return {
        "file": str(path),
        "image_url": candidate.image_url,
        "page_url": candidate.page_url,
        "source_hint": candidate.source_hint,
        "status": status,
        "sha256": digest,
    }


def write_manifest(out: Path, rows: list[dict[str, str]], skipped: list[dict[str, str]]) -> None:
    metadata = out / "metadata"
    fieldnames = ["file", "image_url", "page_url", "source_hint", "status", "sha256"]
    for filename, data in [("manifest.csv", rows), ("skipped.csv", skipped)]:
        with (metadata / filename).open("w", encoding="utf-8", newline="") as handle:
            writer = csv.DictWriter(handle, fieldnames=fieldnames)
            writer.writeheader()
            writer.writerows(data)
    (metadata / "manifest.jsonl").write_text(
        "".join(json.dumps(row, ensure_ascii=False) + "\n" for row in rows),
        encoding="utf-8",
    )
    (metadata / "summary.json").write_text(
        json.dumps(
            {
                "images": len(rows),
                "skipped": len(skipped),
                "created_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
                "usage_note": "Class-project review dataset. Manually verify rights and labels before reuse outside this course.",
            },
            indent=2,
            ensure_ascii=False,
        ),
        encoding="utf-8",
    )
    (out / "README.md").write_text(
        """# Camel Doll Web Review Dataset

This folder contains web-collected camel plush/toy product images for a class
project MVP. It is not a production/commercial dataset.

Next steps:

1. Review images under `images/camel_doll`.
2. Remove false positives and low-quality duplicates.
3. Upload to Roboflow/CVAT/LabelImg.
4. Draw one `camel_doll` box around each whole doll.
5. Export YOLO format to `dataset_sources/camel_doll_yolo`.

Keep `metadata/manifest.csv` with the dataset for source tracking.
""",
        encoding="utf-8",
    )


def main() -> int:
    args = parse_args()
    if args.limit < 1:
        raise ValueError("--limit must be positive")
    reset_output(args.out, args.keep_existing)
    pages = load_pages(args.pages_file, include_seed_pages=not args.no_seed_pages)
    all_candidates: list[Candidate] = []
    page_errors: dict[str, str] = {}
    for page_url in pages:
        try:
            html_text = run_curl(page_url).decode("utf-8", "replace")
            all_candidates.extend(extract_candidates(page_url, html_text))
        except Exception as exc:
            page_errors[page_url] = str(exc)

    unique_candidates = list({candidate.image_url: candidate for candidate in all_candidates}.values())
    summary = download_candidates(unique_candidates, args.out, args.limit, args.dry_run)
    summary["pages"] = len(pages)
    summary["page_errors"] = page_errors
    (args.out / "metadata" / "collection_summary.json").write_text(
        json.dumps(summary, indent=2, ensure_ascii=False),
        encoding="utf-8",
    )
    print(json.dumps(summary, indent=2, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(main())
