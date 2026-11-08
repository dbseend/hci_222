#!/usr/bin/env python3
"""Compute robust reference statistics and a legacy-vs-robust comparison.

Input : backend/app/data/cairo_price_dataset_augmented_2026_05_13.json
Output: backend/app/data/price_stats_robust.json   (PriceStats-compatible rows)
        backend/supabase/robust_stats_columns.sql  (additive migration + UPDATEs)
        docs/robust_stats_report.md                (numbers for the paper)

Run: python3 scripts/compute_robust_stats.py   (no network, deterministic)
"""

from __future__ import annotations

import json
import random
import statistics
import sys
from collections import Counter, defaultdict
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "backend"))

from app.services import robust_stats as rs  # noqa: E402

DATASET = ROOT / "backend/app/data/cairo_price_dataset_augmented_2026_05_13.json"
OUT_JSON = ROOT / "backend/app/data/price_stats_robust.json"
OUT_SQL = ROOT / "backend/supabase/robust_stats_columns.sql"
OUT_MD = ROOT / "docs/robust_stats_report.md"

STAT_DATE = "2026-05-13"
STAT_AT = datetime(2026, 5, 13, 23, 59, tzinfo=timezone.utc)
TAU_DAYS = rs.DEFAULT_DECAY_TAU_DAYS
SOURCE_WEIGHTS = {"user_market": 1.0, "government": 0.8, "web": 0.5, "manual_seed": 0.3}
SOURCE_TYPE_MAP = {"web_scrape": "web", "web": "web", "government": "government",
                   "manual_seed": "manual_seed", "user_market": "user_market"}
SYNTHETIC_SOURCE = "MVP synthetic augmentation 2026-05-13"
MARKUPS = (0.8, 1.0, 1.2, 1.5, 2.0, 3.0)
CONTAMINATION_RATE, CONTAMINATION_FACTOR, SEED = 0.05, 5.0, 222


def load_rows(dataset):
    source_type = {s["name"]: SOURCE_TYPE_MAP.get(s["source_type"], "manual_seed")
                   for s in dataset["sources"]}
    rows = []
    for obs in dataset["observations"]:
        name = obs["source_name"]
        stype = source_type.get(name, "manual_seed")
        if name == SYNTHETIC_SOURCE:
            kind = "synthetic"
        elif stype == "manual_seed":
            kind = "manual"
        else:
            kind = "real"
        age = (STAT_AT - datetime.fromisoformat(obs["observed_at"])).total_seconds() / 86400
        rows.append({
            "product": obs["product_code"], "unit": obs["unit"], "kind": kind,
            "price": float(obs["unit_price_egp"]),
            "weight": SOURCE_WEIGHTS[stype] * float(obs.get("confidence_score") or 0.5)
                      * rs.recency_weight(age, TAU_DAYS),
        })
    return rows


def legacy(values):
    sd = statistics.pstdev(values) if len(values) > 1 else 0.0
    return {"avg": statistics.mean(values), "std": sd, "median": statistics.median(values)}


def legacy_verdict(price, avg, std):
    if std <= 0:
        return "warning" if price > avg else "safe"
    return rs.classify_z((price - avg) / std)


def robust_verdict(price, median, sigma):
    return rs.classify_z(rs.robust_z(price, median, sigma))


def per_product(rows):
    groups = defaultdict(list)
    for r in rows:
        groups[(r["product"], r["unit"])].append(r)
    return groups


def analyse(group):
    values = [r["price"] for r in group]
    weights = [r["weight"] for r in group]
    real = [r for r in group if r["kind"] == "real"]
    median = rs.weighted_median(values, weights)
    sigma = rs.robust_sigma(values, weights)
    mad = rs.weighted_mad(values, weights, median)
    real_w = [r["weight"] for r in real]
    return {
        "values": values, "weights": weights, "median": median, "sigma": sigma, "mad": mad,
        "legacy": legacy(values),
        "n": len(group), "n_real": len(real),
        "n_synth": sum(r["kind"] == "synthetic" for r in group),
        "n_manual": sum(r["kind"] == "manual" for r in group),
        "ess": rs.effective_sample_size(weights),
        "ess_real": rs.effective_sample_size(real_w) if real_w else 0.0,
        "real_median": statistics.median([r["price"] for r in real]) if real else None,
    }


def contaminate(values, rng):
    out = list(values)
    for i in rng.sample(range(len(out)), max(1, round(len(out) * CONTAMINATION_RATE))):
        out[i] *= CONTAMINATION_FACTOR
    return out


def main() -> int:
    dataset = json.loads(DATASET.read_text())
    rows = load_rows(dataset)
    groups = per_product(rows)
    stats = {key: analyse(g) for key, g in sorted(groups.items())}
    rng = random.Random(SEED)

    json_rows, sql_updates, md_rows = [], [], []
    drift_legacy, drift_robust = [], []
    confusion = Counter()
    missed = {"legacy": 0, "robust": 0}
    eligible = 0
    synth_shift = []
    for (product, unit), s in stats.items():
        lg = s["legacy"]
        conf = rs.confidence_score(min(s["n_real"], s["ess_real"]) if s["n_real"] else 0,
                                   s["median"], s["sigma"])
        json_rows.append({
            "product_id": product, "region": "cairo", "currency": "EGP",
            "avg_price": round(lg["avg"], 2), "median_price": round(s["median"], 2),
            "min_price": round(min(s["values"]), 2), "max_price": round(max(s["values"]), 2),
            "stddev_price": round(lg["std"], 2), "sample_count": s["n"],
            "window_days": 30, "stat_date": STAT_DATE,
            "mad_price": round(s["mad"], 4), "real_sample_count": s["n_real"],
            "synthetic_sample_count": s["n_synth"],
            "effective_sample_size": round(s["ess"], 2), "decay_tau_days": TAU_DAYS,
        })
        sql_updates.append(
            f"update public.price_reference_stats r set mad_price_egp = {s['mad']:.4f}, "
            f"median_price_egp = {s['median']:.2f}, real_sample_count = {s['n_real']}, "
            f"synthetic_sample_count = {s['n_synth']}, effective_sample_size = {s['ess']:.2f}, "
            f"decay_tau_days = {TAU_DAYS} from public.products p "
            f"where p.id = r.product_id and p.code = '{product}' and r.unit = '{unit}' "
            f"and r.region_code = 'cairo' and r.stat_date = '{STAT_DATE}';")

        # 1) warning-threshold drift under 5% x5 contamination
        dirty = contaminate(s["values"], rng)
        l_clean = lg["avg"] + 1.5 * lg["std"]
        l_dirty = statistics.mean(dirty) + 1.5 * statistics.pstdev(dirty)
        med_d = rs.weighted_median(dirty, s["weights"])
        r_clean = s["median"] + 1.5 * s["sigma"]
        r_dirty = med_d + 1.5 * rs.robust_sigma(dirty, s["weights"])
        drift_legacy.append(abs(l_dirty - l_clean) / l_clean * 100)
        drift_robust.append(abs(r_dirty - r_clean) / r_clean * 100)

        # 2) verdict agreement / missed overcharge on quotes = k x real-only median
        if s["real_median"]:
            eligible += 1
            for k in MARKUPS:
                price = s["real_median"] * k
                lv = legacy_verdict(price, lg["avg"], lg["std"])
                rv = robust_verdict(price, s["median"], s["sigma"])
                confusion[(k, lv, rv)] += 1
                if k >= 1.5:
                    missed["legacy"] += lv == "safe"
                    missed["robust"] += rv == "safe"
            synth_shift.append((s["median"] - s["real_median"]) / s["real_median"] * 100)

        md_rows.append((product, unit, s, conf))

    OUT_JSON.write_text(json.dumps(json_rows, indent=2, ensure_ascii=False) + "\n")
    OUT_SQL.write_text(
        "-- Additive migration for robust (median/MAD, recency-weighted) reference stats.\n"
        "-- NOT applied automatically. Run after the base schema and after seeding.\n"
        "begin;\n"
        "alter table public.price_reference_stats\n"
        "  add column if not exists mad_price_egp numeric check (mad_price_egp is null or mad_price_egp >= 0),\n"
        "  add column if not exists real_sample_count int check (real_sample_count is null or real_sample_count >= 0),\n"
        "  add column if not exists synthetic_sample_count int check (synthetic_sample_count is null or synthetic_sample_count >= 0),\n"
        "  add column if not exists effective_sample_size numeric,\n"
        "  add column if not exists decay_tau_days numeric check (decay_tau_days is null or decay_tau_days > 0);\n\n"
        "-- Recency-weighted median/MAD per product, generated by scripts/compute_robust_stats.py\n"
        + "\n".join(sql_updates) + "\ncommit;\n")

    total = Counter(r["kind"] for r in rows)

    def pct(a, b):
        return f"{a / b * 100:.1f}%" if b else "n/a"

    agree = sum(v for (k, lv, rv), v in confusion.items() if lv == rv)
    n_cells = sum(confusion.values())
    lines = [
        "# Robust reference statistics - legacy vs robust (generated)",
        "",
        f"Source: `{DATASET.name}`; stat date {STAT_DATE}; decay tau = {TAU_DAYS:g} d; "
        f"source weights {SOURCE_WEIGHTS}; seed {SEED}. Regenerate with "
        "`python3 scripts/compute_robust_stats.py`.",
        "",
        "## 1. Data composition",
        f"- Observations: {len(rows)} (real web/government {total['real']}, "
        f"manual/derived {total['manual']}, synthetic {total['synthetic']} = "
        f"{pct(total['synthetic'], len(rows))})",
        f"- Product-unit groups: {len(stats)}; with >=1 real observation: {eligible}",
        f"- Median shift caused by synthetic data (all-data weighted median vs real-only "
        f"median): median {statistics.median(synth_shift):+.1f}%, "
        f"range {min(synth_shift):+.1f}% to {max(synth_shift):+.1f}%",
        "",
        f"## 2. Outlier robustness ({CONTAMINATION_RATE:.0%} of samples x{CONTAMINATION_FACTOR:g})",
        "Relative drift of the price at which a quote turns `warning`:",
        f"- Legacy (mean + 1.5 sd): mean {statistics.mean(drift_legacy):.1f}%, "
        f"max {max(drift_legacy):.1f}%",
        f"- Robust (median + 1.5 sigma_r): mean {statistics.mean(drift_robust):.1f}%, "
        f"max {max(drift_robust):.1f}%",
        "",
        "## 3. Verdict behaviour on simulated quotes (k x real-only median)",
        f"- Verdict agreement legacy vs robust: {agree}/{n_cells} = {pct(agree, n_cells)}",
        f"- Overcharge quotes (k >= 1.5) still labelled `safe`: legacy {missed['legacy']}, "
        f"robust {missed['robust']} of {eligible * sum(k >= 1.5 for k in MARKUPS)}",
        "",
        "| k | legacy safe/neg/warn | robust safe/neg/warn |",
        "|---|---|---|",
    ]
    for k in MARKUPS:
        def dist(idx):
            c = Counter()
            for (kk, lv, rv), v in confusion.items():
                if kk == k:
                    c[(lv, rv)[idx]] += v
            return "/".join(str(c[x]) for x in ("safe", "negotiable", "warning"))
        lines.append(f"| {k:g} | {dist(0)} | {dist(1)} |")
    lines += ["", "## 4. Per-product reference (first 25 rows)",
              "| product | unit | n | real | mean | median | sd | sigma_r | confidence |",
              "|---|---|---|---|---|---|---|---|---|"]
    for product, unit, s, conf in md_rows[:25]:
        lg = s["legacy"]
        lines.append(f"| {product} | {unit} | {s['n']} | {s['n_real']} | {lg['avg']:.1f} | "
                     f"{s['median']:.1f} | {lg['std']:.1f} | {s['sigma']:.1f} | {conf:.0f} |")
    OUT_MD.write_text("\n".join(lines) + "\n")
    print("\n".join(lines[:30]))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
