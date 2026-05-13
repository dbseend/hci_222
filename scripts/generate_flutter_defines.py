from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / ".env"
TARGET = ROOT / "frontend" / "flutter_app" / ".dart_tool" / "trueprice_dart_defines.json"
CLIENT_KEYS = {"TRUEPRICE_API_BASE_URL"}


def main() -> None:
    if not SOURCE.exists():
        raise SystemExit(f"Missing env file: {SOURCE}")

    data = _read_dotenv(SOURCE)
    client_data = {key: data[key] for key in CLIENT_KEYS if data.get(key)}
    if "TRUEPRICE_API_BASE_URL" not in client_data:
        raise SystemExit("Missing TRUEPRICE_API_BASE_URL in .env")

    TARGET.parent.mkdir(parents=True, exist_ok=True)
    lines = [f"{key}={value}" for key, value in sorted(client_data.items())]
    TARGET.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"Wrote Flutter dart defines: {TARGET}")


def _read_dotenv(path: Path) -> dict[str, str]:
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


if __name__ == "__main__":
    main()
