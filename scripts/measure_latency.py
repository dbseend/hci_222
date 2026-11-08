"""Measure /scan latency against the running local server.

    .venv/bin/python scripts/measure_latency.py --image fruit.jpg [--server URL] [--runs 50] [--warmup 5]
"""

import argparse
import math
import statistics
import sys
import time
from pathlib import Path

import httpx

SCAN_PATH = "/scan/detect-object"
CAIRO = {"lat": "30.0444", "lon": "31.2357"}


def summarize(samples_ms: list[float]) -> dict[str, float]:
    ordered = sorted(samples_ms)
    p95_index = max(0, math.ceil(0.95 * len(ordered)) - 1)  # nearest-rank p95
    return {
        "median": statistics.median(ordered),
        "p95": ordered[p95_index],
        "max": ordered[-1],
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--image", type=Path, required=True)
    parser.add_argument("--server", default="http://127.0.0.1:8000")
    parser.add_argument("--runs", type=int, default=50)
    parser.add_argument("--warmup", type=int, default=5)
    args = parser.parse_args()
    if args.runs <= args.warmup:
        parser.error("--runs must be greater than --warmup")

    image = args.image.read_bytes()
    samples: list[float] = []
    statuses: dict[int, int] = {}
    with httpx.Client(base_url=args.server, timeout=60) as client:
        for i in range(args.runs):
            start = time.perf_counter()
            response = client.post(
                SCAN_PATH,
                files={"image": (args.image.name, image, "image/jpeg")},
                data=CAIRO,
            )
            elapsed_ms = (time.perf_counter() - start) * 1000
            statuses[response.status_code] = statuses.get(response.status_code, 0) + 1
            if i >= args.warmup:
                samples.append(elapsed_ms)

    stats = summarize(samples)
    print(f"{len(samples)} measured runs ({args.warmup} warm-up excluded), HTTP status counts {statuses}")
    print(f"median {stats['median']:.0f} ms | p95 {stats['p95']:.0f} ms | max {stats['max']:.0f} ms")
    return 0 if set(statuses) <= {200, 404} else 1


if __name__ == "__main__":
    sys.exit(main())
