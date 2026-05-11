#!/usr/bin/env python3
"""
Collect a small license-filtered starter dataset from Wikimedia Commons.

The script only keeps images with licenses that allow commercial use:
Public Domain, CC0, CC BY, and CC BY-SA. It rejects NC/ND variants.
Downloaded images still need manual visual review and bounding-box labeling.
"""

from __future__ import annotations

import csv
import hashlib
import html
import json
import os
import re
import subprocess
import sys
import time
from pathlib import Path
from urllib.parse import quote, urlencode


ROOT = Path(__file__).resolve().parents[1]
DATASET_ROOT = ROOT / "dataset_sources"
IMAGE_ROOT = DATASET_ROOT / "images"
META_ROOT = DATASET_ROOT / "metadata"

USER_AGENT = "HCI222 dataset curation/0.1 (student MVP; license-filtered)"

CLASSES = {
    "tomato": {
        "target": 25,
        "queries": [
            "tomato red fruit",
            "ripe tomato closeup",
            "tomato on white background",
            "tomato vegetable market",
        ],
    },
    "cherry_tomato": {
        "target": 25,
        "queries": [
            "cherry tomato fruit",
            "cherry tomatoes closeup",
            "small red tomato",
            "cherry tomato package",
        ],
    },
    "camel_doll": {
        "target": 18,
        "queries": [
            "camel plush toy",
            "camel stuffed animal",
            "camel toy",
            "stuffed camel",
            "toy camel",
        ],
    },
    "other_fruit": {
        "target": 30,
        "queries": [
            "apple fruit closeup",
            "banana fruit",
            "orange fruit",
            "grape fruit",
            "pear fruit",
        ],
    },
    "other_toy": {
        "target": 25,
        "queries": [
            "teddy bear plush toy",
            "giraffe plush toy",
            "horse plush toy",
            "stuffed animal toy",
            "plush toy",
        ],
    },
}


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


def license_allowed(short_name: str, usage_terms: str) -> bool:
    value = f"{short_name} {usage_terms}".lower()
    if not value.strip():
        return False
    blocked = ["noncommercial", "non-commercial", "cc-by-nc", "cc by-nc", " nc", "-nc", "no derivatives", "no-derivatives", " nd", "-nd"]
    if any(token in value for token in blocked):
        return False
    allowed = ["public domain", "cc0", "cc-by", "cc by", "attribution", "pd"]
    return any(token in value for token in allowed)


def slug(value: str) -> str:
    value = re.sub(r"^File:", "", value, flags=re.IGNORECASE)
    value = re.sub(r"\.[^.]+$", "", value)
    value = re.sub(r"[^a-zA-Z0-9]+", "_", value).strip("_").lower()
    return value[:80] or "image"


def extension_for_mime(mime: str) -> str:
    if "png" in mime:
        return "png"
    if "webp" in mime:
        return "webp"
    return "jpg"


def commons_search(query: str, limit: int = 50) -> list[dict]:
    params = {
        "action": "query",
        "generator": "search",
        "gsrsearch": query,
        "gsrnamespace": "6",
        "gsrlimit": str(limit),
        "prop": "imageinfo",
        "iiprop": "url|mime|size|extmetadata",
        "iiurlwidth": "900",
        "format": "json",
        "origin": "*",
    }
    url = "https://commons.wikimedia.org/w/api.php?" + urlencode(params)
    payload = run_curl(url)
    data = json.loads(payload.decode("utf-8"))
    return list(data.get("query", {}).get("pages", {}).values())


def page_url(title: str) -> str:
    return "https://commons.wikimedia.org/wiki/" + quote(title.replace(" ", "_"), safe=":/_")


def main() -> int:
    IMAGE_ROOT.mkdir(parents=True, exist_ok=True)
    META_ROOT.mkdir(parents=True, exist_ok=True)

    records: list[dict] = []
    skipped: list[dict] = []
    seen_originals: set[str] = set()

    for class_name, config in CLASSES.items():
        class_dir = IMAGE_ROOT / class_name
        class_dir.mkdir(parents=True, exist_ok=True)
        class_count = 0

        for query in config["queries"]:
            if class_count >= config["target"]:
                break
            try:
                pages = commons_search(query)
            except Exception as exc:
                skipped.append({"class_name": class_name, "query": query, "reason": str(exc)})
                continue

            for page in pages:
                if class_count >= config["target"]:
                    break
                info = (page.get("imageinfo") or [{}])[0]
                mime = info.get("mime", "")
                if not mime.startswith("image/") or mime == "image/svg+xml":
                    continue
                if info.get("width", 0) < 220 or info.get("height", 0) < 220:
                    continue

                extmetadata = info.get("extmetadata") or {}
                license_name = strip_html((extmetadata.get("LicenseShortName") or {}).get("value", ""))
                usage_terms = strip_html((extmetadata.get("UsageTerms") or {}).get("value", ""))
                if not license_allowed(license_name, usage_terms):
                    skipped.append(
                        {
                            "class_name": class_name,
                            "title": page.get("title"),
                            "license": license_name,
                            "reason": "license_not_allowed",
                        }
                    )
                    continue

                original_url = info.get("url")
                if not original_url or original_url in seen_originals:
                    continue
                seen_originals.add(original_url)

                image_url = info.get("thumburl") or original_url
                digest = hashlib.sha1(original_url.encode("utf-8")).hexdigest()[:8]
                file_name = f"{class_name}_{class_count + 1:03d}_{slug(page.get('title', 'image'))}_{digest}.{extension_for_mime(mime)}"
                dest = class_dir / file_name
                try:
                    run_curl(image_url, dest)
                except Exception as exc:
                    skipped.append({"class_name": class_name, "title": page.get("title"), "reason": str(exc)})
                    continue

                record = {
                    "file": str(dest.relative_to(DATASET_ROOT)),
                    "class_name": class_name,
                    "needs_manual_bbox": True,
                    "needs_visual_review": True,
                    "source": "Wikimedia Commons",
                    "title": page.get("title", ""),
                    "page_url": page_url(page.get("title", "")),
                    "original_url": original_url,
                    "downloaded_url": image_url,
                    "license": license_name,
                    "license_url": (extmetadata.get("LicenseUrl") or {}).get("value", ""),
                    "attribution_required": strip_html((extmetadata.get("AttributionRequired") or {}).get("value", "")),
                    "artist": strip_html((extmetadata.get("Artist") or {}).get("value", "")),
                    "credit": strip_html((extmetadata.get("Credit") or {}).get("value", "")),
                    "usage_terms": usage_terms,
                    "width": info.get("width"),
                    "height": info.get("height"),
                    "downloaded_bytes": dest.stat().st_size,
                    "collected_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
                }
                records.append(record)
                class_count += 1
                time.sleep(0.15)
            time.sleep(0.25)

    manifest_jsonl = META_ROOT / "manifest.jsonl"
    manifest_jsonl.write_text("\n".join(json.dumps(record, ensure_ascii=False) for record in records) + "\n", encoding="utf-8")

    manifest_csv = META_ROOT / "manifest.csv"
    fields = [
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
    ]
    with manifest_csv.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fields, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(records)

    (META_ROOT / "skipped.json").write_text(json.dumps(skipped, indent=2, ensure_ascii=False), encoding="utf-8")

    summary = {class_name: sum(1 for r in records if r["class_name"] == class_name) for class_name in CLASSES}
    summary_payload = {
        "dataset_root": str(DATASET_ROOT),
        "total_images": len(records),
        "class_counts": summary,
        "license_policy": "Commercial-use-only filter: Public Domain, CC0, CC BY, CC BY-SA. NC/ND rejected.",
        "next_step": "Manual visual review and bounding-box labeling are required before training.",
        "skipped_count": len(skipped),
    }
    (META_ROOT / "summary.json").write_text(json.dumps(summary_payload, indent=2, ensure_ascii=False), encoding="utf-8")
    print(json.dumps(summary_payload, indent=2, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(main())
