#!/usr/bin/env bash
set -euo pipefail

BUNDLE_ID="${BUNDLE_ID:-com.shyoon840.hci222.trueprice}"
APP_PATH="${APP_PATH:-build/ios/iphoneos/Runner.app}"

if [ "$#" -eq 0 ]; then
  echo "Usage: scripts/run_ios_devices.sh <ios-device-udid> [ios-device-udid...]"
  echo
  echo "Find UDIDs with:"
  echo "  flutter devices"
  exit 64
fi

echo "Building signed iOS debug app..."
flutter build ios --debug

if [ ! -d "$APP_PATH" ]; then
  echo "Built app not found: $APP_PATH" >&2
  exit 66
fi

pids=()
for device_id in "$@"; do
  (
    echo "[$device_id] Installing $APP_PATH"
    xcrun devicectl device install app --device "$device_id" "$APP_PATH"

    echo "[$device_id] Launching $BUNDLE_ID"
    xcrun devicectl device process launch \
      --device "$device_id" \
      --terminate-existing \
      "$BUNDLE_ID"
  ) &
  pids+=("$!")
done

status=0
for pid in "${pids[@]}"; do
  if ! wait "$pid"; then
    status=1
  fi
done

exit "$status"
