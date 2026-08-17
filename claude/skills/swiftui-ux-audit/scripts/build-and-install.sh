#!/usr/bin/env bash
# build-and-install.sh — xcodebuild + simctl install.
#
# Usage:
#   build-and-install.sh <scheme> <UDID> [<derived-data-dir>]
#
# Emits the path to the installed .app on stdout.

set -eu

SCHEME="${1:?scheme required}"
UDID="${2:?UDID required}"
DERIVED="${3:-./swiftui-ux-audit/.derived}"

mkdir -p "$DERIVED"

# Build for the simulator destination.
xcodebuild build \
  -scheme "$SCHEME" \
  -destination "platform=iOS Simulator,id=$UDID" \
  -configuration Debug \
  -derivedDataPath "$DERIVED" \
  -quiet

APP_PATH=$(find "$DERIVED/Build/Products/Debug-iphonesimulator" -maxdepth 2 -name "*.app" | head -1)
if [ -z "$APP_PATH" ]; then
    echo "No .app produced under $DERIVED" >&2
    exit 2
fi

xcrun simctl install "$UDID" "$APP_PATH"

echo "$APP_PATH"
