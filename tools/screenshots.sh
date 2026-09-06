#!/usr/bin/env bash
#
# Captures the App Store screenshot set.
#
# App Store Connect requires 6.9" iPhone screenshots (1320x2868), which is the
# Pro Max family. Each screen is reached through the DEBUG launch arguments
# rather than by scripting taps, so the run is deterministic.
#
# Usage:  tools/screenshots.sh [output-dir]

set -euo pipefail

DEVICE="${DEVICE:-iPhone 17 Pro Max}"
RUNTIME="${RUNTIME:-26.5}"
BUNDLE_ID="com.mlcreativestudios.PhotoStyler"
SCHEME="PhotoStyler"
OUT="${1:-build/screenshots}"
DD="${DD:-build/DerivedData}"

mkdir -p "$OUT"

udid=$(xcrun simctl list devices available -j \
  | /usr/bin/python3 -c '
import json, sys
want_device = sys.argv[1]
want_runtime = sys.argv[2]
data = json.load(sys.stdin)["devices"]
for runtime, devices in data.items():
    if want_runtime.replace(".", "-") not in runtime:
        continue
    for d in devices:
        if d["name"] == want_device and d.get("isAvailable"):
            print(d["udid"]); sys.exit(0)
sys.exit("no %s on iOS %s" % (want_device, want_runtime))
' "$DEVICE" "$RUNTIME")

echo "Device: $DEVICE ($udid)"

echo "Building…"
xcodebuild build \
  -project PhotoStyler.xcodeproj \
  -scheme "$SCHEME" \
  -configuration Debug \
  -destination "id=$udid" \
  -derivedDataPath "$DD" \
  -quiet

APP="$DD/Build/Products/Debug-iphonesimulator/PhotoStyler.app"

xcrun simctl boot "$udid" 2>/dev/null || true
xcrun simctl bootstatus "$udid" -b >/dev/null

# A clean device each run: no stale permission alerts, no leftover gallery
# entries, and a fixed status bar so the frames look composed rather than
# accidental.
xcrun simctl uninstall "$udid" "$BUNDLE_ID" 2>/dev/null || true
xcrun simctl install "$udid" "$APP"
xcrun simctl privacy "$udid" grant camera "$BUNDLE_ID" >/dev/null 2>&1 || true
xcrun simctl privacy "$udid" grant photos-add "$BUNDLE_ID" >/dev/null 2>&1 || true
xcrun simctl status_bar "$udid" override \
  --time "09:41" --batteryState charged --batteryLevel 100 --cellularBars 4 --wifiBars 3

shot() {
  local name="$1"; shift
  echo "  → $name"
  xcrun simctl terminate "$udid" "$BUNDLE_ID" >/dev/null 2>&1 || true
  xcrun simctl launch "$udid" "$BUNDLE_ID" "$@" >/dev/null
  sleep "${SETTLE:-6}"
  xcrun simctl io "$udid" screenshot "$OUT/$name.png" >/dev/null
}

echo "Capturing…"
shot "1-home"
shot "2-camera"   -openCamera
shot "3-styles"   -openStyles
shot "4-compare"  -openStyles -openProfile warm-film
shot "5-gallery"  -openGallery

xcrun simctl status_bar "$udid" clear
xcrun simctl terminate "$udid" "$BUNDLE_ID" >/dev/null 2>&1 || true

echo
echo "Saved to $OUT:"
for f in "$OUT"/*.png; do
  printf '  %-14s %s\n' "$(basename "$f")" "$(sips -g pixelWidth -g pixelHeight "$f" | awk '/pixel/{printf "%s ", $2}')"
done
