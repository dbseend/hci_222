#!/usr/bin/env python3
"""Generate Supabase SQL seed files for the final MVP price schema."""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any

from seed_price_data_mvp import (
    REGION_CODE,
    SEED_BATCH,
    WINDOW_DAYS,
    build_observation_rows,
    build_product_rows,
    build_reference_rows,
    build_source_rows,
    stable_uuid,
)


ROOT = Path(__file__).resolve().parents[1]
BASE_DATASET = ROOT / "backend/app/data/cairo_price_dataset_2026_05_13.json"
AUGMENTED_DATASET = ROOT / "backend/app/data/cairo_price_dataset_augmented_2026_05_13.json"
BASE_OUTPUT = ROOT / "backend/supabase/seed_cairo_prices_2026_05_13.sql"
AUGMENTED_OUTPUT = ROOT / "backend/supabase/seed_cairo_prices_augmented_2026_05_13.sql"


def sql_literal(value: Any) -> str:
    if value is None:
        return "null"
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, (int, float)):
        return str(value)
    return "'" + str(value).replace("'", "''") + "'"


def jsonb_literal(value: dict[str, Any]) -> str:
    return sql_literal(json.dumps(value, ensure_ascii=False, sort_keys=True)) + "::jsonb"


def values(rows: list[str]) -> str:
    return ",\n  ".join(rows)


def product_sql(rows: list[dict[str, Any]]) -> str:
    row_sql = values(
        [
            f"({sql_literal(row['code'])}, {sql_literal(row['name'])}, "
            f"{sql_literal(row['default_unit'])}, {sql_literal(row['is_active'])})"
            for row in rows
        ]
    )
    return f"""insert into products (code, name, default_unit, is_active)
values
  {row_sql}
on conflict (code) do update set
  name = excluded.name,
  default_unit = excluded.default_unit,
  is_active = excluded.is_active,
  updated_at = now();
"""


def source_sql(rows: list[dict[str, Any]]) -> str:
    row_sql = values(
        [
            f"({sql_literal(row['source_type'])}, {sql_literal(row['name'])}, "
            f"{sql_literal(row.get('url'))}, {sql_literal(row['weight'])}, {sql_literal(row['is_active'])})"
            for row in rows
        ]
    )
    return f"""insert into price_sources (source_type, name, url, weight, is_active)
values
  {row_sql}
on conflict (source_type, name) do update set
  url = excluded.url,
  weight = excluded.weight,
  is_active = excluded.is_active;
"""


def observation_sql(
    rows: list[dict[str, Any]],
    product_code_by_id: dict[str, str],
    source_key_by_id: dict[str, tuple[str, str]],
) -> str:
    row_sql = values(
        [
            "("
            f"{sql_literal(row['id'])}::uuid, "
            f"{sql_literal(product_code_by_id[row['product_id']])}, "
            f"{sql_literal(source_key_by_id[row['source_id']][0])}, "
            f"{sql_literal(source_key_by_id[row['source_id']][1])}, "
            f"{sql_literal(row['region_code'])}, "
            f"{sql_literal(row['currency'])}, "
            f"{sql_literal(row['unit'])}, "
            f"{sql_literal(row['quantity'])}, "
            f"{sql_literal(row['total_price_egp'])}, "
            f"{sql_literal(row['unit_price_egp'])}, "
            f"{sql_literal(row['observed_at'])}::timestamptz, "
            f"{sql_literal(row['status'])}, "
            f"{sql_literal(row['confidence_score'])}, "
            f"{jsonb_literal(row['raw_payload'])}"
            ")"
            for row in rows
        ]
    )
    return f"""insert into price_observations (
  id,
  product_id,
  source_id,
  region_code,
  currency,
  unit,
  quantity,
  total_price_egp,
  unit_price_egp,
  observed_at,
  status,
  confidence_score,
  raw_payload
)
select
  seed_rows.id,
  products.id,
  price_sources.id,
  seed_rows.region_code,
  seed_rows.currency,
  seed_rows.unit,
  seed_rows.quantity,
  seed_rows.total_price_egp,
  seed_rows.unit_price_egp,
  seed_rows.observed_at,
  seed_rows.status,
  seed_rows.confidence_score,
  seed_rows.raw_payload
from (
  values
  {row_sql}
) as seed_rows (
  id,
  product_code,
  source_type,
  source_name,
  region_code,
  currency,
  unit,
  quantity,
  total_price_egp,
  unit_price_egp,
  observed_at,
  status,
  confidence_score,
  raw_payload
)
join products on products.code = seed_rows.product_code
join price_sources
  on price_sources.source_type = seed_rows.source_type
 and price_sources.name = seed_rows.source_name
on conflict (id) do update set
  product_id = excluded.product_id,
  source_id = excluded.source_id,
  region_code = excluded.region_code,
  currency = excluded.currency,
  unit = excluded.unit,
  quantity = excluded.quantity,
  total_price_egp = excluded.total_price_egp,
  unit_price_egp = excluded.unit_price_egp,
  observed_at = excluded.observed_at,
  status = excluded.status,
  confidence_score = excluded.confidence_score,
  raw_payload = excluded.raw_payload;
"""


def reference_sql(rows: list[dict[str, Any]], product_code_by_id: dict[str, str]) -> str:
    row_sql = values(
        [
            "("
            f"{sql_literal(row['id'])}::uuid, "
            f"{sql_literal(product_code_by_id[row['product_id']])}, "
            f"{sql_literal(row['region_code'])}, "
            f"{sql_literal(row['unit'])}, "
            f"{sql_literal(row['window_days'])}, "
            f"{sql_literal(row['stat_date'])}::date, "
            f"{sql_literal(row['sample_count'])}, "
            f"{sql_literal(row['weighted_avg_price_egp'])}, "
            f"{sql_literal(row['median_price_egp'])}, "
            f"{sql_literal(row['min_price_egp'])}, "
            f"{sql_literal(row['max_price_egp'])}, "
            f"{sql_literal(row['p25_price_egp'])}, "
            f"{sql_literal(row['p75_price_egp'])}, "
            f"{sql_literal(row['stddev_price_egp'])}, "
            f"{jsonb_literal(row['source_mix'])}"
            ")"
            for row in rows
        ]
    )
    return f"""insert into price_reference_stats (
  id,
  product_id,
  region_code,
  unit,
  window_days,
  stat_date,
  sample_count,
  weighted_avg_price_egp,
  median_price_egp,
  min_price_egp,
  max_price_egp,
  p25_price_egp,
  p75_price_egp,
  stddev_price_egp,
  source_mix
)
select
  seed_rows.id,
  products.id,
  seed_rows.region_code,
  seed_rows.unit,
  seed_rows.window_days,
  seed_rows.stat_date,
  seed_rows.sample_count,
  seed_rows.weighted_avg_price_egp,
  seed_rows.median_price_egp,
  seed_rows.min_price_egp,
  seed_rows.max_price_egp,
  seed_rows.p25_price_egp,
  seed_rows.p75_price_egp,
  seed_rows.stddev_price_egp,
  seed_rows.source_mix
from (
  values
  {row_sql}
) as seed_rows (
  id,
  product_code,
  region_code,
  unit,
  window_days,
  stat_date,
  sample_count,
  weighted_avg_price_egp,
  median_price_egp,
  min_price_egp,
  max_price_egp,
  p25_price_egp,
  p75_price_egp,
  stddev_price_egp,
  source_mix
)
join products on products.code = seed_rows.product_code
on conflict (product_id, region_code, unit, window_days, stat_date) do update set
  sample_count = excluded.sample_count,
  weighted_avg_price_egp = excluded.weighted_avg_price_egp,
  median_price_egp = excluded.median_price_egp,
  min_price_egp = excluded.min_price_egp,
  max_price_egp = excluded.max_price_egp,
  p25_price_egp = excluded.p25_price_egp,
  p75_price_egp = excluded.p75_price_egp,
  stddev_price_egp = excluded.stddev_price_egp,
  source_mix = excluded.source_mix;
"""


def exchange_rate_sql(rows: list[dict[str, Any]]) -> str:
    statements = []
    for row in rows:
        statements.append(
            "insert into exchange_rates (base_currency, quote_currency, rate, as_of_date, source)\n"
            "select "
            f"{sql_literal(row['base_currency'])}, "
            f"{sql_literal(row['quote_currency'])}, "
            f"{sql_literal(row['rate'])}, "
            f"{sql_literal(row['as_of_date'])}::date, "
            f"{sql_literal(row.get('source'))}\n"
            "where not exists (\n"
            "  select 1 from exchange_rates\n"
            f"  where base_currency = {sql_literal(row['base_currency'])}\n"
            f"    and quote_currency = {sql_literal(row['quote_currency'])}\n"
            f"    and as_of_date = {sql_literal(row['as_of_date'])}::date\n"
            ");"
        )
    return "\n\n".join(statements)


def build_seed_sql(dataset_path: Path, output_path: Path, title: str) -> None:
    dataset = json.loads(dataset_path.read_text())
    product_rows = build_product_rows(dataset)
    source_rows = build_source_rows(dataset)
    product_ids = {
        row["code"]: stable_uuid("product", row["code"])
        for row in product_rows
    }
    product_code_by_id = {row_id: code for code, row_id in product_ids.items()}
    source_ids = {
        (row["source_type"], row["name"]): stable_uuid("source", row["source_type"], row["name"])
        for row in source_rows
    }
    source_key_by_id = {row_id: key for key, row_id in source_ids.items()}
    products_by_id = {
        product_ids[row["code"]]: {
            "id": product_ids[row["code"]],
            "code": row["code"],
            "name": row["name"],
            "default_unit": row["default_unit"],
        }
        for row in product_rows
    }
    source_weights_by_id = {
        source_ids[(row["source_type"], row["name"])]: float(row["weight"])
        for row in source_rows
    }
    source_types_by_id = {
        source_ids[(row["source_type"], row["name"])]: row["source_type"]
        for row in source_rows
    }
    source_types_by_name = {row["name"]: row["source_type"] for row in source_rows}
    observation_rows = build_observation_rows(
        dataset,
        product_ids,
        source_ids,
        source_types_by_name,
    )
    reference_rows = build_reference_rows(
        observation_rows,
        product_ids,
        products_by_id,
        source_weights_by_id,
        source_types_by_id,
        dataset["observed_date"],
    )

    header = f"""-- {title}
-- Generated from scripts/generate_price_seed_sql.py
-- Target schema: products, price_sources, price_observations, price_reference_stats, exchange_rates.
-- Region: {REGION_CODE}; reference window: {WINDOW_DAYS} days; seed batch: {SEED_BATCH}.
begin;
"""
    body = "\n\n".join(
        [
            product_sql(product_rows),
            source_sql(source_rows),
            observation_sql(observation_rows, product_code_by_id, source_key_by_id),
            reference_sql(reference_rows, product_code_by_id),
            exchange_rate_sql(dataset.get("exchange_rates", [])),
        ]
    )
    output_path.write_text(f"{header}\n{body}\n\ncommit;\n")


def main() -> int:
    build_seed_sql(BASE_DATASET, BASE_OUTPUT, "Cairo base price seed for TruePrice MVP")
    build_seed_sql(AUGMENTED_DATASET, AUGMENTED_OUTPUT, "Cairo augmented price seed for TruePrice MVP")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
