import os
from functools import lru_cache
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parents[3]
DEFAULT_ENV_FILE = PROJECT_ROOT / ".env"


@lru_cache(maxsize=1)
def load_env_file() -> dict[str, str]:
    configured_path = os.getenv("TRUEPRICE_ENV_FILE")
    path = Path(configured_path).expanduser().resolve() if configured_path else DEFAULT_ENV_FILE
    if not path.exists():
        return {}

    values: dict[str, str] = {}
    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        key = key.strip()
        value = value.strip().strip('"').strip("'")
        if key:
            values[key] = value
    return values


def env_value(name: str, default: str | None = None) -> str | None:
    return os.getenv(name) or load_env_file().get(name) or default
