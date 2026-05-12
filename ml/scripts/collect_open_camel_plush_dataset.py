#!/usr/bin/env python3
"""
Collect license-filtered camel plush/toy review images from Wikimedia Commons.

This script is intentionally conservative:
- Source is Wikimedia Commons only.
- Kept licenses must allow reuse: Public Domain, CC0, CC BY, or CC BY-SA.
- NC/ND/custom-restricted licenses are rejected.
- Every downloaded image gets source, license, author, and attribution metadata.

The output is a review dataset, not a train-ready YOLO dataset. Manual visual
review and bounding-box labeling are still required before training.
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
from pathlib import Path
from urllib.parse import quote, urlencode


ROOT = Path(__file__).resolve().parents[2]
DEFAULT_OUT = ROOT / "dataset_sources" / "camel_plush_open"
USER_AGENT = "HCI222 camel plush dataset curation/0.1 (student MVP; license-filtered)"
COMMONS_API = "https://commons.wikimedia.org/w/api.php"

ALLOWED_LICENSE_MARKERS = (
    "public domain",
    "cc0",
    "cc-by",
    "cc by",
    "creative commons attribution",
    "creative commons attribution-share alike",
    "attribution-share alike",
    "attribution",
)
BLOCKED_LICENSE_MARKERS = (
    "noncommercial",
    "non-commercial",
    "cc-by-nc",
    "cc by-nc",
    " nc",
    "-nc",
    "no derivatives",
    "no-derivatives",
    "cc-by-nd",
    "cc by-nd",
    " nd",
    "-nd",
    "fair use",
    "all rights reserved",
)

CAMEL_MARKERS = (
    "camel",
    "camila",
    "camels",
    "kamel",
)
TOY_MARKERS = (
    "plush",
    "stuffed",
    "soft toy",
    "toy",
    "doll",
    "peluche",
    "jucarie",
    "jucării",
)
NEGATIVE_TITLE_MARKERS = (
    "arabian camel",
    "bactrian camel",
    "camelus",
    "zoo",
    "desert",
    "caravan",
    "livestock",
)

SEARCH_QUERIES = (
    '"camel toy"',
    '"camel plush"',
    '"stuffed camel"',
    '"camel doll"',
    '"toy camel"',
    '"peluche camel"',
    '"kamel plush"',
    '"camila jucarie"',
)

IMAGE_EXTENSIONS = {".jpg", ".jpeg", ".png", ".webp"}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Collect open-license camel plush/toy review images from Wikimedia Commons.",
    )
    parser.add_argument(
        "--out",
        type=Path,
        default=DEFAULT_OUT,
        help=f"Output dataset directory. Default: {DEFAULT_OUT}",
    )
    parser.add_argument(
        "--target",
        type=int,
        default=40,
        help="Maximum number of accepted images to download.",
    )
    parser.add_argument(
        "--per-query",
        type=int,
        default=50,
        help="Wikimedia search result count per query.",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Fetch metadata and write manifests without downloading image files.",
    )
    parser.add_argument(
        "--keep-existing",
        action="store_true",
        help="Do not clear the managed image/metadata output before collection.",
    )
    return parser.parse_args()


def run_curl(url: str, output: Path | None = None) -> bytes:
    cmd = [
        "curl",
        "-L",
        "--fail",
        "--retry",
        "2",
        "--connect-timeout",
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


def strip_html(value: str) -> str:
    text = re.sub(r"<[^>]*>", "", value or "")
    return re.sub(r"\s+", " ", html.unescape(text)).strip()


def metadata_value(extmetadata: dict, key: str) -> str:
    return strip_html((extmetadata.get(key) or {}).get("value", ""))


def license_allowed(short_name: str, usage_terms: str, license_url: str) -> bool:
    value = f"{short_name} {usage_terms} {license_url}".lower()
    if not value.strip():
        return False
    if any(marker in value for marker in BLOCKED_LICENSE_MARKERS):
        return False
    return any(marker in value for marker in ALLOWED_LICENSE_MARKERS)


def text_matches_scope(title: str, extmetadata: dict) -> bool:
    text = " ".join(
        [
            title,
            metadata_value(extmetadata, "ObjectName"),
            metadata_value(extmetadata, "ImageDescription"),
            metadata_value(extmetadata, "Categories"),
        ]
    ).lower()

    has_camel = any(marker in text for marker in CAMEL_MARKERS)
    has_toy = any(marker in text for marker in TOY_MARKERS)
    negative_title = any(marker in title.lower() for marker in NEGATIVE_TITLE_MARKERS)
    return has_camel and has_toy and not negative_title


def commons_search(query: str, limit: int) -> list[dict]:
    params = {
        "action": "query",
        "generator": "search",
        "gsrsearch": query,
        "gsrnamespace": "6",
        "gsrlimit": str(limit),
        "prop": "imageinfo",
        "iiprop": "url|mime|size|extmetadata",
        "iiurlwidth": "1200",
        "format": "json",
        "origin": "*",
    }
    payload = run_curl(COMMONS_API + "?" + urlencode(params))
    data = json.loads(payload.decode("utf-8"))
    return list(data.get("query", {}).get("pages", {}).values())


def page_url(title: str) -> str:
    return "https://commons.wikimedia.org/wiki/" + quote(title.replace(" ", "_"), safe=":/_")


def slug(value: str) -> str:
    value = re.sub(r"^File:", "", value, flags=re.IGNORECASE)
    value = re.sub(r"\.[^.]+$", "", value)
    value = re.sub(r"[^a-zA-Z0-9]+", "_", value).strip("_").lower()
    return value[:90] or "image"


def extension_for(mime: str, url: str) -> str:
    suffix = Path(url.split("?", 1)[0]).suffix.lower()
    if suffix in IMAGE_EXTENSIONS:
        return suffix.lstrip(".")
    if "png" in mime:
        return "png"
    if "webp" in mime:
        return "webp"
    return "jpg"


def image_digest(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def record_from_page(page: dict, query: str, output_image: Path | None) -> dict:
    info = (page.get("imageinfo") or [{}])[0]
    extmetadata = info.get("extmetadata") or {}
    license_name = metadata_value(extmetadata, "LicenseShortName")
    usage_terms = metadata_value(extmetadata, "UsageTerms")
    license_url = (extmetadata.get("LicenseUrl") or {}).get("value", "")
    downloaded_bytes = output_image.stat().st_size if output_image and output_image.exists() else 0
    sha256 = image_digest(output_image) if output_image and output_image.exists() else ""

    return {
        "file": str(output_image.relative_to(output_image.parents[2])) if output_image else "",
        "class_name": "camel_plush",
        "source": "Wikimedia Commons",
        "source_query": query,
        "title": page.get("title", ""),
        "page_url": page_url(page.get("title", "")),
        "original_url": info.get("url", ""),
        "downloaded_url": info.get("thumburl") or info.get("url", ""),
        "license": license_name,
        "license_url": license_url,
        "usage_terms": usage_terms,
        "attribution_required": metadata_value(extmetadata, "AttributionRequired"),
        "artist": metadata_value(extmetadata, "Artist"),
        "credit": metadata_value(extmetadata, "Credit"),
        "width": info.get("width"),
        "height": info.get("height"),
        "mime": info.get("mime", ""),
        "downloaded_bytes": downloaded_bytes,
        "sha256": sha256,
        "needs_visual_review": True,
        "needs_manual_bbox": True,
        "collected_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
    }


def write_outputs(out: Path, records: list[dict], skipped: list[dict]) -> None:
    metadata_dir = out / "metadata"
    metadata_dir.mkdir(parents=True, exist_ok=True)

    (metadata_dir / "manifest.jsonl").write_text(
        "\n".join(json.dumps(record, ensure_ascii=False) for record in records) + ("\n" if records else ""),
        encoding="utf-8",
    )

    csv_fields = [
        "file",
        "class_name",
        "source",
        "title",
        "page_url",
        "license",
        "license_url",
        "attribution_required",
        "artist",
        "credit",
        "usage_terms",
        "sha256",
    ]
    with (metadata_dir / "manifest.csv").open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=csv_fields, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(records)

    with (metadata_dir / "review_queue.csv").open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(
            handle,
            fieldnames=["file", "class_name", "needs_visual_review", "needs_manual_bbox", "page_url", "title"],
            extrasaction="ignore",
        )
        writer.writeheader()
        writer.writerows(records)

    attribution_lines = [
        "# Camel Plush Open Dataset Attribution",
        "",
        "Images are from Wikimedia Commons and must be reviewed before training/public demo use.",
        "",
    ]
    for record in records:
        creator = record["artist"] or record["credit"] or "unknown creator"
        attribution_lines.append(
            f"- {record['title']} by {creator}; {record['license']} "
            f"({record['license_url']}); {record['page_url']}"
        )
    (metadata_dir / "ATTRIBUTION.md").write_text("\n".join(attribution_lines) + "\n", encoding="utf-8")

    (metadata_dir / "skipped.json").write_text(json.dumps(skipped, indent=2, ensure_ascii=False), encoding="utf-8")

    license_counts: dict[str, int] = {}
    for record in records:
        license_counts[record["license"]] = license_counts.get(record["license"], 0) + 1
    summary = {
        "dataset_root": str(out),
        "image_dir": str(out / "images" / "camel_plush"),
        "total_images": len(records),
        "class_counts": {"camel_plush": len(records)},
        "license_counts": license_counts,
        "license_policy": "Wikimedia Commons only; Public Domain, CC0, CC BY, and CC BY-SA allowed; NC/ND/restricted licenses rejected.",
        "status": "review_only_needs_visual_review_and_manual_bbox",
        "skipped_count": len(skipped),
        "next_step": "Remove false positives, label camel_plush bounding boxes, then export YOLO.",
    }
    (metadata_dir / "summary.json").write_text(json.dumps(summary, indent=2, ensure_ascii=False), encoding="utf-8")

    readme = f"""# Camel Plush Open Review Dataset

## Core Judgment

This is a license-filtered review dataset for `camel_plush`, not a train-ready YOLO dataset.

## Counts

- images: {len(records)}
- skipped candidates: {len(skipped)}

## License Policy

Only Wikimedia Commons images with Public Domain, CC0, CC BY, or CC BY-SA metadata are kept.
NC, ND, fair-use, all-rights-reserved, or unclear records are rejected.

## Required Next Step

1. Open `metadata/review_queue.csv`.
2. Delete false positives from `images/camel_plush`.
3. Label bounding boxes as `camel_plush` in Roboflow, CVAT, or LabelImg.
4. Export YOLO format for training.

Do not train directly from this folder without visual review and bbox labels.
"""
    (out / "README.md").write_text(readme, encoding="utf-8")


def collect(args: argparse.Namespace) -> dict:
    image_dir = args.out / "images" / "camel_plush"
    metadata_dir = args.out / "metadata"
    if not args.keep_existing:
        shutil.rmtree(image_dir, ignore_errors=True)
        shutil.rmtree(metadata_dir, ignore_errors=True)
    image_dir.mkdir(parents=True, exist_ok=True)
    metadata_dir.mkdir(parents=True, exist_ok=True)

    records: list[dict] = []
    skipped: list[dict] = []
    seen_originals: set[str] = set()
    seen_sha256: set[str] = set()

    for query in SEARCH_QUERIES:
        if len(records) >= args.target:
            break
        try:
            pages = commons_search(query, args.per_query)
        except Exception as exc:
            skipped.append({"query": query, "reason": f"search_failed: {exc}"})
            continue

        for page in pages:
            if len(records) >= args.target:
                break

            title = page.get("title", "")
            info = (page.get("imageinfo") or [{}])[0]
            extmetadata = info.get("extmetadata") or {}
            mime = info.get("mime", "")
            original_url = info.get("url", "")
            image_url = info.get("thumburl") or original_url

            skip_base = {"query": query, "title": title, "page_url": page_url(title)}
            if not mime.startswith("image/") or mime == "image/svg+xml":
                skipped.append({**skip_base, "reason": "unsupported_mime", "mime": mime})
                continue
            if info.get("width", 0) < 220 or info.get("height", 0) < 220:
                skipped.append({**skip_base, "reason": "too_small"})
                continue
            if not original_url or original_url in seen_originals:
                skipped.append({**skip_base, "reason": "duplicate_original_url"})
                continue

            license_name = metadata_value(extmetadata, "LicenseShortName")
            usage_terms = metadata_value(extmetadata, "UsageTerms")
            license_url = (extmetadata.get("LicenseUrl") or {}).get("value", "")
            if not license_allowed(license_name, usage_terms, license_url):
                skipped.append({**skip_base, "reason": "license_not_allowed", "license": license_name})
                continue
            if not text_matches_scope(title, extmetadata):
                skipped.append({**skip_base, "reason": "scope_filter_rejected"})
                continue

            seen_originals.add(original_url)
            url_digest = hashlib.sha1(original_url.encode("utf-8")).hexdigest()[:10]
            extension = extension_for(mime, image_url)
            dest = image_dir / f"camel_plush_{len(records) + 1:03d}_{slug(title)}_{url_digest}.{extension}"

            try:
                if args.dry_run:
                    record = record_from_page(page, query, None)
                else:
                    run_curl(image_url, dest)
                    digest = image_digest(dest)
                    if digest in seen_sha256:
                        dest.unlink(missing_ok=True)
                        skipped.append({**skip_base, "reason": "duplicate_file_hash"})
                        continue
                    seen_sha256.add(digest)
                    record = record_from_page(page, query, dest)
            except Exception as exc:
                skipped.append({**skip_base, "reason": f"download_failed: {exc}"})
                continue

            records.append(record)
            time.sleep(0.15)
        time.sleep(0.25)

    write_outputs(args.out, records, skipped)
    summary = json.loads((metadata_dir / "summary.json").read_text(encoding="utf-8"))
    print(json.dumps(summary, indent=2, ensure_ascii=False))
    return summary


def main() -> int:
    args = parse_args()
    if args.target <= 0:
        raise ValueError("--target must be greater than 0")
    if args.per_query <= 0 or args.per_query > 500:
        raise ValueError("--per-query must be between 1 and 500")
    collect(args)
    return 0


if __name__ == "__main__":
    sys.exit(main())
