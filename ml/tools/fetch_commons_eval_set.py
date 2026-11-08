#!/usr/bin/env python3
"""Download an independent, license-filtered image set from Wikimedia Commons.

Used only for an out-of-distribution sanity check of backend/models/best.pt.
Labels are image-level (the searched class); they are NOT box annotations.
Usage: python3 fetch_commons_eval_set.py OUT_DIR [per_class]
"""

import csv
import json
import re
import sys
import time
import urllib.parse
import urllib.request
from pathlib import Path

API = "https://commons.wikimedia.org/w/api.php"
UA = {"User-Agent": "HCI-course-eval/1.0 (academic image sanity check)"}
OK_LICENSE = re.compile(r"^(CC0|CC BY|CC BY-SA|Public domain|PD|CC-BY)", re.I)
QUERIES = {
    "apple": ["apple fruit", "red apple", "green apple fruit"],
    "banana": ["banana fruit", "bananas bunch"],
    "grape": ["grapes fruit", "bunch of grapes"],
    "mango": ["mango fruit", "mangoes"],
    "strawberry": ["strawberries fruit", "strawberry fruit"],
    "camel_doll": [
        "camel plush",
        "stuffed camel toy",
        "camel toy souvenir",
        "plush camel toy",
        "toy camel",
        "camel stuffed animal",
        "camel figurine souvenir",
    ],
    "tomato": ["tomato fruit", "tomatoes vegetable"],  # out-of-vocabulary probe
}
KEYWORD = {
    "apple": "apple",
    "banana": "banana",
    "grape": "grape",
    "mango": "mango",
    "strawberry": "strawberr",
    "camel_doll": "camel",
    "tomato": "tomato",
}


def get(url, retries=2):
    for i in range(retries):
        try:
            return urllib.request.urlopen(
                urllib.request.Request(url, headers=UA), timeout=15
            ).read()
        except Exception:
            time.sleep(2 * (i + 1))
    return None


def search(q, limit=60):
    params = {
        "action": "query",
        "format": "json",
        "generator": "search",
        "gsrnamespace": "6",
        "gsrsearch": f"filetype:bitmap {q}",
        "gsrlimit": str(limit),
        "prop": "imageinfo",
        "iiprop": "url|size|extmetadata|mime",
        "iiurlwidth": "800",
    }
    raw = get(API + "?" + urllib.parse.urlencode(params))
    pages = json.loads(raw).get("query", {}).get("pages", {}) if raw else {}
    return list(pages.values())


def main():
    out = Path(sys.argv[1])
    per_class = int(sys.argv[2]) if len(sys.argv) > 2 else 25
    out.mkdir(parents=True, exist_ok=True)
    rows = []
    only = sys.argv[3].split(",") if len(sys.argv) > 3 else list(QUERIES)
    for cls, queries in QUERIES.items():
        if cls not in only:
            continue
        (out / cls).mkdir(exist_ok=True)
        seen, kept = set(), 0
        for q in queries:
            for page in search(q):
                if kept >= per_class:
                    break
                title = page.get("title", "")
                info = (page.get("imageinfo") or [{}])[0]
                meta = info.get("extmetadata", {})
                lic = meta.get("LicenseShortName", {}).get("value", "")
                if title in seen or not OK_LICENSE.match(lic):
                    continue
                if info.get("mime") not in ("image/jpeg", "image/png"):
                    continue
                if KEYWORD[cls] not in title.lower():
                    continue
                if min(info.get("width", 0), info.get("height", 0)) < 300:
                    continue
                seen.add(title)
                data = get(info.get("thumburl") or info["url"])
                if not data:
                    continue
                fn = out / cls / f"{kept:03d}.jpg"
                fn.write_bytes(data)
                author = re.sub("<[^>]+>", "", meta.get("Artist", {}).get("value", ""))[
                    :80
                ]
                rows.append(
                    [cls, fn.name, title, lic, author, info.get("descriptionurl", "")]
                )
                kept += 1
                time.sleep(0.4)
            time.sleep(1)
        print(cls, kept, flush=True)
    with open(out / f"manifest_{'_'.join(only)}.csv", "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["class", "file", "title", "license", "author", "source"])
        w.writerows(rows)


main()
