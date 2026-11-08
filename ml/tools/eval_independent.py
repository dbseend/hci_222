#!/usr/bin/env python3
"""Image-level sanity evaluation of backend/models/best.pt on an independent set.

Layout: SET_DIR/<class>/*.jpg (+ manifest.csv). Labels are image-level, not boxes,
so this reports top-1 accuracy / detection rate / box-area ratio / CPU latency,
NOT mAP. Usage: eval_independent.py SET_DIR OUT_MD [conf] [model.pt]
"""

import statistics
import sys
import time
from collections import Counter, defaultdict
from pathlib import Path

from ultralytics import YOLO

ROOT = Path(__file__).resolve().parents[2]
MODEL = ROOT / "backend/models/best.pt"
VOCAB = ["apple", "banana", "grape", "mango", "strawberry", "camel_doll"]


def main():
    set_dir, out_md = Path(sys.argv[1]), Path(sys.argv[2])
    conf = float(sys.argv[3]) if len(sys.argv) > 3 else 0.25
    model_path = Path(sys.argv[4]) if len(sys.argv) > 4 else MODEL
    model = YOLO(str(model_path))
    per = defaultdict(list)
    for cls_dir in sorted(p for p in set_dir.iterdir() if p.is_dir()):
        for img in sorted(cls_dir.glob("*.jpg")):
            r = model.predict(
                str(img), conf=conf, imgsz=640, verbose=False, device="cpu"
            )[0]
            h, w = r.orig_shape
            if len(r.boxes) == 0:
                per[cls_dir.name].append({"pred": None, "conf": 0, "area": 0, "n": 0})
                continue
            i = int(r.boxes.conf.argmax())
            x1, y1, x2, y2 = r.boxes.xyxy[i].tolist()
            per[cls_dir.name].append(
                {
                    "pred": r.names[int(r.boxes.cls[i])],
                    "conf": float(r.boxes.conf[i]),
                    "area": (x2 - x1) * (y2 - y1) / (w * h),
                    "n": len(r.boxes),
                }
            )
    # latency on one representative image, CPU, includes pre/post-processing
    sample = next(
        next(p for p in sorted(set_dir.iterdir()) if p.is_dir()).glob("*.jpg")
    )
    for _ in range(5):
        model.predict(str(sample), imgsz=640, verbose=False, device="cpu")
    times = []
    for _ in range(40):
        t = time.perf_counter()
        model.predict(str(sample), imgsz=640, verbose=False, device="cpu")
        times.append((time.perf_counter() - t) * 1000)
    times.sort()
    lat = {
        "median_ms": statistics.median(times),
        "p95_ms": times[int(0.95 * len(times)) - 1],
        "min_ms": times[0],
    }

    L = [
        f"# YOLO ({model_path.name}) - independent image-level check (generated)",
        "",
        f"Model: YOLO11n, classes {VOCAB}. conf >= {conf}, imgsz 640, CPU. "
        "Images: Wikimedia Commons (CC/PD), image-level labels from search class; "
        "label noise is possible. **Not mAP.**",
        "",
        "| class | n | detected | top-1 acc (all) | acc (detected) | mean conf | mean box area |",
        "|---|---|---|---|---|---|---|",
    ]
    tot_n = tot_ok = tot_det = 0
    confusion = {}
    for cls, rows in per.items():
        n = len(rows)
        det = [r for r in rows if r["pred"]]
        ok = sum(r["pred"] == cls for r in rows)
        confusion[cls] = Counter(r["pred"] or "none" for r in rows)
        if cls in VOCAB:
            tot_n += n
            tot_ok += ok
            tot_det += len(det)
        L.append(
            f"| {cls} | {n} | {len(det) / n:.0%} | "
            f"{(ok / n if cls in VOCAB else float('nan')):.0%} | "
            f"{(ok / len(det) if det and cls in VOCAB else float('nan')):.0%} | "
            f"{(statistics.mean(r['conf'] for r in det) if det else 0):.2f} | "
            f"{(statistics.mean(r['area'] for r in det) if det else 0):.2f} |"
        )
    L += [
        "",
        f"In-vocabulary overall: top-1 {tot_ok}/{tot_n} = {tot_ok / max(tot_n, 1):.0%}, "
        f"detected {tot_det}/{tot_n} = {tot_det / max(tot_n, 1):.0%}",
        "",
        "## Predicted-class distribution per true class",
    ]
    for cls, c in confusion.items():
        L.append(f"- {cls}: " + ", ".join(f"{k}={v}" for k, v in c.most_common()))
    L += [
        "",
        "## CPU latency (one 640px image, 40 runs, incl. pre/post-processing)",
        f"- median {lat['median_ms']:.0f} ms, p95 {lat['p95_ms']:.0f} ms, min {lat['min_ms']:.0f} ms",
    ]
    out_md.write_text("\n".join(L) + "\n")
    print("\n".join(L))


main()
