#!/usr/bin/env bash
# Demo server on this Mac: point the app config at the current LAN IP, then serve.
# Rebuild the Flutter app after the IP changes (it is baked in at build time).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PY="$ROOT/.venv/bin/python"
[ -x "$PY" ] || { echo "No .venv; run scripts/setup_local_demo.sh first." >&2; exit 1; }
PORT="${PORT:-8000}"
IP="${1:-$(ipconfig getifaddr en0 || ipconfig getifaddr en1 || true)}"
[ -n "$IP" ] || { echo "No LAN IP; connect to Wi-Fi or a hotspot." >&2; exit 1; }

URL="http://$IP:$PORT"
OLD_URL="$(sed -n 's#^TRUEPRICE_API_BASE_URL=##p' "$ROOT/.env")"
sed -i '' "s#^TRUEPRICE_API_BASE_URL=.*#TRUEPRICE_API_BASE_URL=$URL#" "$ROOT/.env"
"$PY" "$ROOT/scripts/generate_flutter_defines.py"
echo "API base URL: $URL"
if [ "$OLD_URL" != "$URL" ]; then
  echo "WARNING: API base URL changed ($OLD_URL -> $URL)." >&2
  echo "WARNING: Rebuild the Flutter app on the iPhone, or it will call the old address." >&2
fi

cd "$ROOT/backend"
exec "$PY" -m uvicorn app.main:app --host 0.0.0.0 --port "$PORT"
