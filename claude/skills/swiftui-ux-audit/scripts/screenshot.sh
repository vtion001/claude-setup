#!/usr/bin/env bash
# screenshot.sh — capture a PNG screenshot from a booted simulator.
#
# Usage:
#   screenshot.sh <UDID> <output-path.png>

set -eu

UDID="${1:?UDID required}"
OUT="${2:?output path required}"

mkdir -p "$(dirname "$OUT")"

xcrun simctl io "$UDID" screenshot "$OUT" >/dev/null
echo "$OUT"
