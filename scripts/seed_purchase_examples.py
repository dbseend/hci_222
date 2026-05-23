#!/usr/bin/env python3
"""Seed example purchase records using YOLO test-set images."""

from __future__ import annotations

import argparse
import mimetypes
import random
import re
import sys
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ENV_FILE = ROOT / ".env"
TEST_IMAGES_DIR = ROOT / "dataset" / "trueprice_yolo_local" / "test" / "images"
BUCKET = "community-images"

PRODUCTS = {
    "apple": {
        "name": "Apple 1kg",
        "unit": "kg",
        "quantity": 1,
        "price_range": (55, 95),
    },
    "banana": {
        "name": "Banana 1kg",
        "unit": "kg",
        "quantity": 1,
        "price_range": (22, 42),
    },
    "grape": {
        "name": "Grapes 1kg",
        "unit": "kg",
        "quantity": 1,
        "price_range": (70, 135),
    },
    "mango": {
        "name": "Mango 1kg",
        "unit": "kg",
        "quantity": 1,
        "price_range": (65, 150),
    },
    "strawberry": {
        "name": "Strawberry 1kg",
        "unit": "kg",
        "quantity": 1,
        "price_range": (80, 165),
    },
    "camel_doll": {
        "name": "Camel Doll 1 pc",
        "unit": "pcs",
        "quantity": 1,
        "price_range": (280, 780),
    },
}

STORES = [
    ("Ataba Market", "Downtown Cairo"),
    ("Khan el-Khalili Market", "Old Cairo"),
    ("Imbaba Market", "Imbaba"),
    ("Zamalek Corner Shop", "Zamalek"),
    ("Dokki Street Market", "Dokki"),
    ("Maadi Local Market", "Maadi"),
    ("Heliopolis Grocer", "Heliopolis"),
    ("Giza Tourist Bazaar", "Giza"),
]


@dataclass(frozen=True)
class SeedRow:
    image: Path
    product_code: str
    product_name: str
    unit: str
    quantity: int
    price: float
    store_name: str
    location_name: str
    created_at: datetime


def load_env(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    if not path.exists():
        return values
    for raw_line in path.read_text().splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        values[key.strip()] = value.strip().strip('"').strip("'")
    return values


def infer_product_code(path: Path) -> str | None:
    name = path.name.lower()
    if "camel" in name:
        return "camel_doll"
    for code in PRODUCTS:
        if re.search(rf"(^|_){re.escape(code)}(_|\\.)", name):
            return code
    return None


def select_rows(limit: int, *, seed: int) -> list[SeedRow]:
    rng = random.Random(seed)
    images = [
        image
        for image in sorted(TEST_IMAGES_DIR.iterdir())
        if image.suffix.lower() in {".jpg", ".jpeg", ".png", ".webp"}
        and infer_product_code(image) in PRODUCTS
    ]
    if len(images) < limit:
        raise RuntimeError(f"Need {limit} test images, found {len(images)}")

    sampled = images[:limit]
    now = datetime.now(timezone.utc).replace(microsecond=0)
    rows: list[SeedRow] = []
    for index, image in enumerate(sampled):
        product_code = infer_product_code(image)
        if product_code is None:
            continue
        product = PRODUCTS[product_code]
        low, high = product["price_range"]
        price = round(rng.uniform(low, high), 2)
        store_name, location_name = STORES[index % len(STORES)]
        rows.append(
            SeedRow(
                image=image,
                product_code=product_code,
                product_name=str(product["name"]),
                unit=str(product["unit"]),
                quantity=int(product["quantity"]),
                price=price,
                store_name=store_name,
                location_name=location_name,
                created_at=now - timedelta(hours=index),
            )
        )
    return rows


def ensure_products(client, rows: list[SeedRow]) -> dict[str, str]:
    codes = sorted({row.product_code for row in rows})
    response = (
        client.table("products")
        .select("id, code")
        .in_("code", codes)
        .execute()
    )
    ids = {row["code"]: row["id"] for row in response.data}
    missing = [code for code in codes if code not in ids]
    for code in missing:
        product = PRODUCTS[code]
        inserted = (
            client.table("products")
            .insert(
                {
                    "code": code,
                    "name": str(product["name"]).split(" 1")[0],
                    "default_unit": product["unit"],
                }
            )
            .execute()
        )
        ids[code] = inserted.data[0]["id"]
    return ids


def upload_image(client, *, client_user_id: str, index: int, image: Path) -> str:
    suffix = image.suffix.lower()
    object_path = f"{client_user_id}/testset_{index:03d}{suffix}"
    content_type = mimetypes.guess_type(image.name)[0] or "image/jpeg"
    with image.open("rb") as file:
        client.storage.from_(BUCKET).upload(
            path=object_path,
            file=file,
            file_options={
                "cache-control": "3600",
                "content-type": content_type,
                "upsert": "true",
            },
        )
    return object_path


def seed(args: argparse.Namespace) -> None:
    env = load_env(ENV_FILE)
    url = env.get("SUPABASE_URL")
    key = env.get("SUPABASE_SERVICE_ROLE_KEY")
    if not url or not key:
        raise RuntimeError("Set SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY in .env")

    rows = select_rows(args.limit, seed=args.seed)
    if args.dry_run:
        for row in rows[:10]:
            print(f"{row.product_code:12} {row.price:7.2f} {row.image.relative_to(ROOT)}")
        print(f"dry-run rows: {len(rows)}")
        return

    from supabase import create_client

    client = create_client(url, key)
    product_ids = ensure_products(client, rows)

    existing = (
        client.table("purchases")
        .select("id")
        .eq("client_user_id", args.client_user_id)
        .execute()
    )
    if existing.data:
        ids = [row["id"] for row in existing.data]
        client.table("purchases").delete().in_("id", ids).execute()

    payloads = []
    for index, row in enumerate(rows, start=1):
        image_path = upload_image(
            client,
            client_user_id=args.client_user_id,
            index=index,
            image=row.image,
        )
        payloads.append(
            {
                "client_user_id": args.client_user_id,
                "product_id": product_ids[row.product_code],
                "product_name_override": row.product_name,
                "store_name_override": row.store_name,
                "location_override": row.location_name,
                "unit": row.unit,
                "quantity": row.quantity,
                "final_price_egp": row.price,
                "image_path": image_path,
                "created_at": row.created_at.isoformat(),
            }
        )

    client.table("purchases").insert(payloads).execute()
    print(f"seeded {len(payloads)} purchase examples for {args.client_user_id}")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--limit", type=int, default=100)
    parser.add_argument("--seed", type=int, default=222)
    parser.add_argument("--client-user-id", default="seed-testset-purchases")
    parser.add_argument("--dry-run", action="store_true")
    return parser.parse_args()


def main() -> int:
    try:
        seed(parse_args())
    except Exception as exc:
        print(f"seed failed: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
