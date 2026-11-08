import importlib.util
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("measure_latency", ROOT / "scripts" / "measure_latency.py")
measure_latency = importlib.util.module_from_spec(spec)
spec.loader.exec_module(measure_latency)


def test_summarize_reports_median_p95_max() -> None:
    stats = measure_latency.summarize([float(ms) for ms in range(100, 0, -1)])

    assert stats == {"median": 50.5, "p95": 95.0, "max": 100.0}


def test_summarize_single_sample() -> None:
    assert measure_latency.summarize([42.0]) == {"median": 42.0, "p95": 42.0, "max": 42.0}
