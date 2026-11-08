#!/usr/bin/env bash
# One-time setup for the local demo: .venv with backend + YOLO dependencies.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VENV="$ROOT/.venv"

PY=""
for candidate in python3.13 python3.12 python3.11 python3; do
  if command -v "$candidate" >/dev/null 2>&1 \
    && "$candidate" -c 'import sys; sys.exit(sys.version_info < (3, 11))'; then
    PY="$candidate"
    break
  fi
done
[ -n "$PY" ] || { echo "Python 3.11+ is required (brew install python@3.12)." >&2; exit 1; }
echo "Using $($PY --version) at $(command -v "$PY")"

[ -x "$VENV/bin/python" ] || "$PY" -m venv "$VENV"
"$VENV/bin/python" -m pip install --upgrade pip
"$VENV/bin/python" -m pip install \
  -r "$ROOT/backend/requirements-ml.txt" \
  -r "$ROOT/backend/requirements-dev.txt"

[ -f "$ROOT/.env" ] || echo "WARNING: .env is missing. Copy .env.example to .env and fill in the keys."

cat <<EOF

Setup done. Next:
  1. $VENV/bin/python scripts/demo_preflight.py
  2. scripts/run_local_server.sh
  3. cd frontend/flutter_app && flutter run --release   # iPhone on the same Wi-Fi
EOF
