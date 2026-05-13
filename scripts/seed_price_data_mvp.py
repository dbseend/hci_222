#!/usr/bin/env python3
"""Seed Cairo MVP price data into the final Supabase price schema."""

from __future__ import annotations

import argparse
import json
import math
import os
import statistics
import sys
import uuid
from collections import Counter, defaultdict
from pathlib import Path
from typing import Any

import requests


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_DATASET = ROOT / "backend/app/data/cairo_price_dataset_augmented_2026_05_13.json"
SEED_BATCH = "cairo_mvp_augmented_2026_05_13"
REGION_CODE = "cairo"
WINDOW_DAYS = 30
UUID_NAMESPACE = uuid.uuid5(uuid.NAMESPACE_URL, "trueprice/cairo-mvp-price-seed")

SOURCE_TYPE_MAP = {
    "web_scrape": "web",
    "web": "web",
    "government": "government",
    "manual_seed": "manual_seed",
    "user_market": "user_market",
}

SOURCE_WEIGHTS = {
    "user_market": 1.0,
    "government": 0.8,
    "web": 0.5,
    "manual_seed": 0.3,
}

STATUS_MAP = {
    "approved": "accepted",
    "accepted": "accepted",
    "rejected": "rejected",
    "pending": "pending",
}


def load_env(path: Path) -> None:
    if not path.exists():
        return
    for line in path.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        os.environ.setdefault(key.strip(), value.strip().strip('"').strip("'"))


def chunked(items: list[dict[str, Any]], size: int) -> list[list[dict[str, Any]]]:
    return [items[index : index + size] for index in range(0, len(items), size)]


def stable_uuid(*parts: Any) -> str:
    return str(uuid.uuid5(UUID_NAMESPACE, ":".join(str(part) for part in parts)))


def quantile(sorted_values: list[float], ratio: float) -> float:
    if not sorted_values:
        return 0.0
    position = (len(sorted_values) - 1) * ratio
    lower = math.floor(position)
    upper = math.ceil(position)
    if lower == upper:
        return sorted_values[lower]
    return sorted_values[lower] + (sorted_values[upper] - sorted_values[lower]) * (position - lower)


def round_money(value: float) -> float:
    return round(float(value), 2)


def normalize_source_type(value: str) -> str:
    return SOURCE_TYPE_MAP.get(value, "manual_seed")


def build_source_rows(dataset: dict[str, Any]) -> list[dict[str, Any]]:
    rows: dict[tuple[str, str], dict[str, Any]] = {}
    for source in dataset["sources"]:
        source_type = normalize_source_type(source.get("source_type", "manual_seed"))
        name = source["name"]
        rows[(source_type, name)] = {
            "source_type": source_type,
            "name": name,
            "url": source.get("url"),
            "weight": SOURCE_WEIGHTS[source_type],
            "is_active": True,
        }
    return list(rows.values())


def build_product_rows(dataset: dict[str, Any]) -> list[dict[str, Any]]:
    return [
        {
            "code": product["code"],
            "name": product["name"],
            "default_unit": product.get("default_unit", "kg"),
            "is_active": True,
        }
        for product in dataset["products"]
    ]


def source_lookup_key(source: dict[str, Any]) -> tuple[str, str]:
    return normalize_source_type(source.get("source_type", "manual_seed")), source["name"]


def observation_identity(observation: dict[str, Any], index: int) -> str:
    raw_payload = observation.get("raw_payload") or {}
    synthetic_id = raw_payload.get("synthetic_id")
    if synthetic_id:
        return str(synthetic_id)
    return "|".join(
        [
            str(index),
            observation["product_code"],
            observation["source_name"],
            observation.get("market_name") or "",
            observation["observed_at"],
            str(observation["unit_price_egp"]),
            observation.get("raw_product_name") or "",
        ]
    )


def build_observation_rows(
    dataset: dict[str, Any],
    product_ids: dict[str, str],
    source_ids: dict[tuple[str, str], str],
    source_types_by_name: dict[str, str],
) -> list[dict[str, Any]]:
    rows = []
    for index, observation in enumerate(dataset["observations"]):
        product_code = observation["product_code"]
        source_name = observation["source_name"]
        source_type = source_types_by_name[source_name]
        raw_payload = dict(observation.get("raw_payload") or {})
        raw_payload.update(
            {
                "seed_batch": SEED_BATCH,
                "raw_product_name": observation.get("raw_product_name"),
                "source_name": source_name,
                "source_type": source_type,
                "market_name": observation.get("market_name"),
                "city": observation.get("city"),
                "district": observation.get("district"),
                "original_status": observation.get("verification_status"),
            }
        )
        rows.append(
            {
                "id": stable_uuid(SEED_BATCH, "observation", observation_identity(observation, index)),
                "product_id": product_ids[product_code],
                "source_id": source_ids[(source_type, source_name)],
                "region_code": REGION_CODE,
                "currency": "EGP",
                "unit": observation.get("unit") or "kg",
                "quantity": observation.get("quantity") or 1,
                "total_price_egp": observation["total_price_egp"],
                "unit_price_egp": observation["unit_price_egp"],
                "observed_at": observation["observed_at"],
                "status": STATUS_MAP.get(observation.get("verification_status"), "pending"),
                "confidence_score": observation.get("confidence_score") or 0.5,
                "raw_payload": raw_payload,
            }
        )
    return rows


def build_reference_rows(
    observation_rows: list[dict[str, Any]],
    product_ids: dict[str, str],
    products_by_id: dict[str, dict[str, Any]],
    source_weights_by_id: dict[str, float],
    source_types_by_id: dict[str, str],
    stat_date: str,
) -> list[dict[str, Any]]:
    grouped: dict[tuple[str, str], list[dict[str, Any]]] = defaultdict(list)
    for row in observation_rows:
        if row["status"] == "accepted":
            grouped[(row["product_id"], row["unit"])].append(row)

    reference_rows = []
    for (product_id, unit), rows in grouped.items():
        values = sorted(float(row["unit_price_egp"]) for row in rows)
        weighted_sum = 0.0
        weight_sum = 0.0
        source_mix = Counter()
        for row in rows:
            source_id = row["source_id"]
            source_type = source_types_by_id[source_id]
            weight = source_weights_by_id[source_id] * float(row.get("confidence_score") or 0.5)
            weighted_sum += float(row["unit_price_egp"]) * weight
            weight_sum += weight
            source_mix[source_type] += 1

        product = products_by_id[product_id]
        reference_rows.append(
            {
                "id": stable_uuid(SEED_BATCH, "reference", product["code"], unit, WINDOW_DAYS, stat_date),
                "product_id": product_id,
                "region_code": REGION_CODE,
                "unit": unit,
                "window_days": WINDOW_DAYS,
                "stat_date": stat_date,
                "sample_count": len(values),
                "weighted_avg_price_egp": round_money(weighted_sum / weight_sum),
                "median_price_egp": round_money(statistics.median(values)),
                "min_price_egp": round_money(min(values)),
                "max_price_egp": round_money(max(values)),
                "p25_price_egp": round_money(quantile(values, 0.25)),
                "p75_price_egp": round_money(quantile(values, 0.75)),
                "stddev_price_egp": round_money(statistics.pstdev(values)) if len(values) > 1 else 0,
                "source_mix": {
                    "seed_batch": SEED_BATCH,
                    "source_counts": dict(source_mix),
                    "weight_policy": "source_weight * confidence_score",
                    "scope": "cairo_overall",
                },
            }
        )
    return reference_rows


def upsert_rows(client: Any, table: str, rows: list[dict[str, Any]], on_conflict: str, batch_size: int = 500) -> None:
    for chunk in chunked(rows, batch_size):
        client.upsert(table, chunk, on_conflict)


def select_all(client: Any, table: str, columns: str) -> list[dict[str, Any]]:
    return client.select(table, columns)


def seed_exchange_rate(client: Any, dataset: dict[str, Any]) -> int:
    inserted = 0
    for rate in dataset.get("exchange_rates", []):
        existing = client.select(
            "exchange_rates",
            "id",
            {
                "base_currency": f"eq.{rate['base_currency']}",
                "quote_currency": f"eq.{rate['quote_currency']}",
                "as_of_date": f"eq.{rate['as_of_date']}",
                "limit": "1",
            },
        )
        if existing:
            continue
        client.insert("exchange_rates", rate)
        inserted += 1
    return inserted


class SupabaseRestClient:
    def __init__(self, url: str, key: str) -> None:
        self.base_url = url.rstrip("/") + "/rest/v1"
        self.headers = {
            "apikey": key,
            "Authorization": f"Bearer {key}",
            "Content-Type": "application/json",
        }

    def request(
        self,
        method: str,
        table: str,
        *,
        params: dict[str, str] | None = None,
        json_body: Any | None = None,
        prefer: str | None = None,
    ) -> Any:
        headers = dict(self.headers)
        if prefer:
            headers["Prefer"] = prefer
        response = requests.request(
            method,
            f"{self.base_url}/{table}",
            headers=headers,
            params=params,
            json=json_body,
            timeout=60,
        )
        if response.status_code >= 400:
            raise RuntimeError(
                f"Supabase REST {method} {table} failed "
                f"({response.status_code}): {response.text[:1000]}"
            )
        if not response.text:
            return None
        return response.json()

    def upsert(self, table: str, rows: list[dict[str, Any]], on_conflict: str) -> None:
        self.request(
            "POST",
            table,
            params={"on_conflict": on_conflict},
            json_body=rows,
            prefer="resolution=merge-duplicates,return=minimal",
        )

    def insert(self, table: str, row: dict[str, Any]) -> None:
        self.request("POST", table, json_body=row, prefer="return=minimal")

    def select(
        self,
        table: str,
        columns: str,
        filters: dict[str, str] | None = None,
    ) -> list[dict[str, Any]]:
        params = {"select": columns}
        if filters:
            params.update(filters)
        return self.request("GET", table, params=params) or []


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--dataset", type=Path, default=DEFAULT_DATASET)
    parser.add_argument("--batch-size", type=int, default=500)
    args = parser.parse_args()

    load_env(ROOT / ".env")
    url = os.environ.get("SUPABASE_URL")
    key = os.environ.get("SUPABASE_SERVICE_ROLE_KEY")
    if not url or not key:
        print("Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY", file=sys.stderr)
        return 1

    dataset = json.loads(args.dataset.read_text())
    client = SupabaseRestClient(url, key)

    product_rows = build_product_rows(dataset)
    source_rows = build_source_rows(dataset)
    upsert_rows(client, "products", product_rows, "code", args.batch_size)
    upsert_rows(client, "price_sources", source_rows, "source_type,name", args.batch_size)

    products = select_all(client, "products", "id,code,name,default_unit")
    sources = select_all(client, "price_sources", "id,source_type,name,weight")
    product_ids = {product["code"]: product["id"] for product in products}
    products_by_id = {product["id"]: product for product in products}
    source_ids = {(source["source_type"], source["name"]): source["id"] for source in sources}
    source_weights_by_id = {source["id"]: float(source["weight"]) for source in sources}
    source_types_by_id = {source["id"]: source["source_type"] for source in sources}
    source_types_by_name = {source["name"]: source["source_type"] for source in source_rows}

    observation_rows = build_observation_rows(dataset, product_ids, source_ids, source_types_by_name)
    reference_rows = build_reference_rows(
        observation_rows,
        product_ids,
        products_by_id,
        source_weights_by_id,
        source_types_by_id,
        dataset["observed_date"],
    )

    upsert_rows(client, "price_observations", observation_rows, "id", args.batch_size)
    upsert_rows(
        client,
        "price_reference_stats",
        reference_rows,
        "product_id,region_code,unit,window_days,stat_date",
        args.batch_size,
    )
    exchange_rates_inserted = seed_exchange_rate(client, dataset)

    print(
        json.dumps(
            {
                "products_upserted": len(product_rows),
                "sources_upserted": len(source_rows),
                "observations_upserted": len(observation_rows),
                "reference_stats_upserted": len(reference_rows),
                "exchange_rates_inserted": exchange_rates_inserted,
                "seed_batch": SEED_BATCH,
                "window_days": WINDOW_DAYS,
                "region_code": REGION_CODE,
            },
            ensure_ascii=True,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
