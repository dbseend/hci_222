#!/usr/bin/env python3
"""Download CC0/CC BY/CC BY-SA/PD images from Openverse for a set of queries.

Used to gather camel plush/toy candidates; build_openimages_fruit_camel_yolo.py
filters and labels them. Writes OUT_DIR/<id>.jpg and OUT_DIR/manifest.csv.

    python3 ml/scripts/collect_openverse_images.py OUT_DIR "camel toy" "toy camel" ...
"""

import csv
import json
import sys
import time
import urllib.parse
import urllib.request
from pathlib import Path

API = "https://api.openverse.org/v1/images/"
UA = {"User-Agent": "HCI-course-dataset/1.0 (academic project)"}
LICENSES = "cc0,pdm,by,by-sa"
MAX_PAGES = 10  # anonymous API: 20 results/page


def fetch(url: str) -> bytes | None:
    for attempt in range(3):
        try:
            return urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=20).read()
        except Exception as exc:
            print(f"retry {attempt + 1} {url}: {exc}", file=sys.stderr)
            time.sleep(2 * (attempt + 1))
    return None


def search(query: str):
    for page in range(1, MAX_PAGES + 1):
        params = {"q": query, "license": LICENSES, "page_size": 20, "page": page}
        raw = fetch(API + "?" + urllib.parse.urlencode(params))
        if not raw:
            return
        data = json.loads(raw)
        yield from data.get("results", [])
        if page >= data.get("page_count", 0):
            return
        time.sleep(1)


def main() -> int:
    if len(sys.argv) < 3:
        print(__doc__)
        return 2
    out = Path(sys.argv[1])
    out.mkdir(parents=True, exist_ok=True)
    seen: set[str] = set()
    rows = []
    for query in sys.argv[2:]:
        kept = 0
        for item in search(query):
            if item["id"] in seen:
                continue
            seen.add(item["id"])
            data = fetch(item.get("thumbnail") or item["url"])
            if not data:
                continue
            (out / f"{item['id']}.jpg").write_bytes(data)
            rows.append([item["id"], query, item.get("title", ""), item.get("license", ""),
                         item.get("creator", ""), item.get("foreign_landing_url", "")])
            kept += 1
            time.sleep(0.3)
        print(query, kept, flush=True)
    with open(out / "manifest.csv", "w", newline="") as f:
        writer = csv.writer(f)
        writer.writerow(["id", "query", "title", "license", "creator", "source"])
        writer.writerows(rows)
    return 0


if __name__ == "__main__":
    sys.exit(main())
