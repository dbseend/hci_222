import json
import math
import random
import statistics
from collections import defaultdict
from datetime import datetime, timedelta, timezone
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
BASE_JSON = ROOT / "backend/app/data/cairo_price_dataset_2026_05_13.json"
OUTPUT_JSON = ROOT / "backend/app/data/cairo_price_dataset_augmented_2026_05_13.json"
OUTPUT_SQL = ROOT / "backend/supabase/seed_cairo_prices_augmented_2026_05_13.sql"

STAT_DATE = "2026-05-13"
WINDOW_DAYS = 14
RANDOM_SEED = 222
SYNTHETIC_SOURCE_NAME = "MVP synthetic augmentation 2026-05-13"

TARGET_SYNTHETIC_PER_PRODUCT_DISTRICT = 24

DISTRICT_FACTORS = {
    "Obour": 0.82,
    "Downtown Cairo": 1.0,
    "Maadi": 1.16,
    "Nasr City": 1.08,
    "Khan el-Khalili": 1.12,
    "Giza/Pyramids": 1.18,
}

SOUVENIR_DISTRICT_FACTORS = {
    "Obour": 0.8,
    "Downtown Cairo": 0.95,
    "Maadi": 1.0,
    "Nasr City": 0.98,
    "Khan el-Khalili": 1.2,
    "Giza/Pyramids": 1.35,
}


def sql_str(value):
    if value is None:
        return "null"
    if isinstance(value, (int, float)):
        return str(value)
    return "'" + str(value).replace("'", "''") + "'"


def sql_json(value):
    return sql_str(json.dumps(value, ensure_ascii=False, sort_keys=True)) + "::jsonb"


def percentile(sorted_values, p):
    if not sorted_values:
        return 0
    if len(sorted_values) == 1:
        return sorted_values[0]
    pos = (len(sorted_values) - 1) * p
    low = math.floor(pos)
    high = math.ceil(pos)
    if low == high:
        return sorted_values[low]
    return sorted_values[low] + (sorted_values[high] - sorted_values[low]) * (pos - low)


def distribution(values, bucket_count=8):
    if not values:
        return []
    lo, hi = min(values), max(values)
    if math.isclose(lo, hi):
        return [{"bucket_start": round(lo, 2), "bucket_end": round(hi, 2), "count": len(values)}]
    width = (hi - lo) / bucket_count
    buckets = []
    for index in range(bucket_count):
        start = lo + width * index
        end = hi if index == bucket_count - 1 else lo + width * (index + 1)
        if index == bucket_count - 1:
            count = sum(1 for value in values if start <= value <= end)
        else:
            count = sum(1 for value in values if start <= value < end)
        buckets.append(
            {
                "bucket_start": round(start, 2),
                "bucket_end": round(end, 2),
                "count": count,
            }
        )
    return buckets


def stats_for(product_code, rows, district):
    values = sorted(row["unit_price_egp"] for row in rows)
    return {
        "stat_date": STAT_DATE,
        "product_code": product_code,
        "city": "Cairo",
        "district": district,
        "unit": rows[0]["unit"],
        "currency": "EGP",
        "avg_price": round(statistics.mean(values), 2),
        "median_price": round(statistics.median(values), 2),
        "min_price": round(min(values), 2),
        "max_price": round(max(values), 2),
        "stddev_price": round(statistics.pstdev(values), 2) if len(values) > 1 else 0,
        "p10_price": round(percentile(values, 0.1), 2),
        "p90_price": round(percentile(values, 0.9), 2),
        "sample_count": len(values),
        "distribution": distribution(values),
    }


def product_baselines(base_data):
    stats_by_product = {row["product_code"]: row for row in base_data["daily_price_stats"]}
    baselines = {}
    for product in base_data["products"]:
        code = product["code"]
        stat = stats_by_product[code]
        avg = float(stat["avg_price"])
        median = float(stat["median_price"])
        stddev = float(stat["stddev_price"])
        min_price = float(stat["min_price"])
        max_price = float(stat["max_price"])
        spread = stddev / avg if avg > 0 else 0.2
        baselines[code] = {
            "unit": product["default_unit"],
            "center": median if median > 0 else avg,
            "avg": avg,
            "min": min_price,
            "max": max_price,
            "spread": min(max(spread, 0.08), 0.45),
        }
    return baselines


def generate_synthetic_observations(base_data):
    rng = random.Random(RANDOM_SEED)
    baselines = product_baselines(base_data)
    markets = base_data["markets"]
    base_date = datetime(2026, 5, 13, 9, tzinfo=timezone.utc)
    observations = []

    for product in base_data["products"]:
        code = product["code"]
        baseline = baselines[code]
        is_souvenir = code == "camel_doll"
        factor_map = SOUVENIR_DISTRICT_FACTORS if is_souvenir else DISTRICT_FACTORS

        for market in markets:
            district = market["district"]
            district_factor = factor_map[district]
            for sample_index in range(TARGET_SYNTHETIC_PER_PRODUCT_DISTRICT):
                seasonal = 1.0 + rng.uniform(-0.035, 0.035)
                demand = 1.0 + rng.gauss(0, baseline["spread"] / 2.8)
                center = baseline["center"] * district_factor * seasonal
                value = center * demand

                low = max(1.0, baseline["min"] * district_factor * 0.72)
                high = baseline["max"] * district_factor * (1.35 if is_souvenir else 1.2)
                value = max(low, min(high, value))

                if baseline["unit"] == "kg":
                    quantity = rng.choice([0.5, 1.0, 1.0, 1.0, 2.0])
                else:
                    quantity = 1

                observed_at = base_date - timedelta(
                    days=rng.randint(0, WINDOW_DAYS - 1),
                    hours=rng.randint(0, 10),
                    minutes=rng.randint(0, 59),
                )
                confidence = 0.38 + min(0.24, baseline["spread"] / 2)
                synthetic_id = f"syn-{STAT_DATE}-{code}-{district.lower().replace('/', '-').replace(' ', '-')}-{sample_index:02d}"
                unit_price = round(value, 2)
                observations.append(
                    {
                        "synthetic_id": synthetic_id,
                        "product_code": code,
                        "source_name": SYNTHETIC_SOURCE_NAME,
                        "market_name": market["name"],
                        "city": "Cairo",
                        "district": district,
                        "unit": baseline["unit"],
                        "quantity": quantity,
                        "total_price_egp": round(unit_price * quantity, 2),
                        "unit_price_egp": unit_price,
                        "observed_at": observed_at.isoformat(),
                        "verification_status": "approved",
                        "confidence_score": round(confidence, 2),
                        "raw_product_name": f"{product['name']} synthetic Cairo sample",
                        "raw_payload": {
                            "synthetic": True,
                            "synthetic_id": synthetic_id,
                            "basis": "Generated from 2026-05-13 Cairo seed observations, district multipliers, and bounded random spread.",
                            "random_seed": RANDOM_SEED,
                            "window_days": WINDOW_DAYS,
                            "district_factor": district_factor,
                        },
                    }
                )
    return observations


def build_augmented_dataset(base_data, synthetic_observations):
    synthetic_source = {
        "name": SYNTHETIC_SOURCE_NAME,
        "source_type": "manual_seed",
        "url": None,
        "reliability_score": 0.38,
        "notes": "Synthetic MVP augmentation. Keep confidence low and replace with crowdsourced/market data as soon as available.",
    }

    source_names = {source["name"] for source in base_data["sources"]}
    sources = list(base_data["sources"])
    if synthetic_source["name"] not in source_names:
        sources.append(synthetic_source)

    all_observations = list(base_data["observations"]) + synthetic_observations
    by_product = defaultdict(list)
    by_product_district = defaultdict(list)
    for row in all_observations:
        by_product[row["product_code"]].append(row)
        by_product_district[(row["product_code"], row["district"])].append(row)

    stats = []
    for product_code, rows in sorted(by_product.items()):
        stats.append(stats_for(product_code, rows, None))
    for (product_code, district), rows in sorted(by_product_district.items()):
        stats.append(stats_for(product_code, rows, district))

    augmented = dict(base_data)
    augmented["scope"] = "Cairo MVP augmented price dataset for TruePrice"
    augmented["augmentation"] = {
        "synthetic": True,
        "synthetic_source_name": SYNTHETIC_SOURCE_NAME,
        "random_seed": RANDOM_SEED,
        "target_synthetic_per_product_district": TARGET_SYNTHETIC_PER_PRODUCT_DISTRICT,
        "warning": "Synthetic rows are for MVP distribution UX only. Do not present them as independently verified market observations.",
    }
    augmented["sources"] = sources
    augmented["synthetic_observations"] = synthetic_observations
    augmented["observations"] = all_observations
    augmented["daily_price_stats"] = stats
    return augmented


def write_sql(augmented, synthetic_observations):
    stats = augmented["daily_price_stats"]
    source = next(item for item in augmented["sources"] if item["name"] == SYNTHETIC_SOURCE_NAME)
    lines = [
        "-- Cairo synthetic price augmentation for TruePrice MVP",
        "-- Generated from scripts/generate_cairo_synthetic_prices.py",
        "-- Run after the base schema and seed_cairo_prices_2026_05_13.sql.",
        "-- This refreshes daily_price_stats for 2026-05-13 using real seed + synthetic observations.",
        "begin;",
        "",
        "insert into price_sources (name, source_type, url, reliability_score)",
        f"select {sql_str(source['name'])}, {sql_str(source['source_type'])}, {sql_str(source['url'])}, {source['reliability_score']}",
        "where not exists (select 1 from price_sources where name = "
        + sql_str(source["name"])
        + ");",
        "",
        "with synthetic_rows (synthetic_id, product_code, market_name, source_name, city, district, unit, quantity, total_price_egp, observed_at, verification_status, confidence_score, raw_product_name, raw_payload) as (",
        "  values",
        "  "
        + ",\n  ".join(
            "("
            + ", ".join(
                [
                    sql_str(row["synthetic_id"]),
                    sql_str(row["product_code"]),
                    sql_str(row["market_name"]),
                    sql_str(row["source_name"]),
                    sql_str(row["city"]),
                    sql_str(row["district"]),
                    sql_str(row["unit"]),
                    str(row["quantity"]),
                    str(row["total_price_egp"]),
                    sql_str(row["observed_at"]),
                    sql_str(row["verification_status"]),
                    str(row["confidence_score"]),
                    sql_str(row["raw_product_name"]),
                    sql_json(row["raw_payload"]),
                ]
            )
            + ")"
            for row in synthetic_observations
        ),
        ")",
        "insert into price_observations (product_id, market_id, source_id, source_type, city, district, unit, quantity, total_price_egp, observed_at, verification_status, confidence_score, raw_product_name, raw_payload)",
        "select p.id, m.id, ps.id, 'manual_seed', r.city, r.district, r.unit, r.quantity, r.total_price_egp, r.observed_at::timestamptz, r.verification_status, r.confidence_score, r.raw_product_name, r.raw_payload",
        "from synthetic_rows r",
        "join products p on p.code = r.product_code",
        "left join markets m on m.name = r.market_name",
        "join price_sources ps on ps.name = r.source_name",
        "where not exists (",
        "  select 1 from price_observations po",
        "  where po.raw_payload->>'synthetic_id' = r.synthetic_id",
        ");",
        "",
        "delete from daily_price_stats where stat_date = '2026-05-13'::date;",
        "",
        "with stat_rows (stat_date, product_code, city, district, unit, currency, avg_price, median_price, min_price, max_price, stddev_price, p10_price, p90_price, sample_count, distribution) as (",
        "  values",
        "  "
        + ",\n  ".join(
            "("
            + ", ".join(
                [
                    sql_str(row["stat_date"]),
                    sql_str(row["product_code"]),
                    sql_str(row["city"]),
                    sql_str(row["district"]),
                    sql_str(row["unit"]),
                    sql_str(row["currency"]),
                    str(row["avg_price"]),
                    str(row["median_price"]),
                    str(row["min_price"]),
                    str(row["max_price"]),
                    str(row["stddev_price"]),
                    str(row["p10_price"]),
                    str(row["p90_price"]),
                    str(row["sample_count"]),
                    sql_json(row["distribution"]),
                ]
            )
            + ")"
            for row in stats
        ),
        ")",
        "insert into daily_price_stats (stat_date, product_id, city, district, unit, currency, avg_price, median_price, min_price, max_price, stddev_price, p10_price, p90_price, sample_count, distribution)",
        "select sr.stat_date::date, p.id, sr.city, sr.district, sr.unit, sr.currency, sr.avg_price, sr.median_price, sr.min_price, sr.max_price, sr.stddev_price, sr.p10_price, sr.p90_price, sr.sample_count, sr.distribution",
        "from stat_rows sr",
        "join products p on p.code = sr.product_code;",
        "",
        "commit;",
        "",
    ]
    OUTPUT_SQL.write_text("\n".join(lines), encoding="utf-8")


def main():
    base_data = json.loads(BASE_JSON.read_text(encoding="utf-8"))
    synthetic_observations = generate_synthetic_observations(base_data)
    augmented = build_augmented_dataset(base_data, synthetic_observations)
    OUTPUT_JSON.write_text(json.dumps(augmented, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    write_sql(augmented, synthetic_observations)


if __name__ == "__main__":
    main()
