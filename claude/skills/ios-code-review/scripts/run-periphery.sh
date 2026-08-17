#!/usr/bin/env bash
# run-periphery.sh — Periphery dead-code scan with JSON output.
set -eu
ROOT="${1:-$PWD}"
SCHEME="${2:-}"
PROJECT="${3:-}"
OUT="${4:-$ROOT/ios-audit/ios-code-review/periphery.json}"
mkdir -p "$(dirname "$OUT")"

if ! command -v periphery > /dev/null 2>&1; then
    echo '{"error": "periphery not installed"}' > "$OUT"
    exit 2
fi

cd "$ROOT"
# Detect project if not provided
if [ -z "$PROJECT" ]; then
    PROJECT=$(ls -d *.xcodeproj 2>/dev/null | head -1 || echo "")
fi
if [ -z "$SCHEME" ] && [ -n "$PROJECT" ]; then
    SCHEME=$(xcodebuild -list -project "$PROJECT" -json 2>/dev/null \
        | python3 -c "import sys, json; d=json.load(sys.stdin); print(d['project']['schemes'][0])" 2>/dev/null || echo "")
fi

if [ -z "$PROJECT" ] || [ -z "$SCHEME" ]; then
    echo '{"error": "could not detect project/scheme"}' > "$OUT"
    exit 2
fi

DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
periphery scan --project "$PROJECT" --schemes "$SCHEME" --quiet --format json > "$OUT" 2>/dev/null || true
echo "[run-periphery] → $OUT"
