#!/usr/bin/env bash
# run-xcodebuild-tests.sh — Run tests + emit .xcresult bundle path.
set -eu
ROOT="${1:-$PWD}"
SCHEME="${2:-}"
PROJECT="${3:-}"
DEVICE="${4:-iPhone 17}"

cd "$ROOT"
PROJECT="${PROJECT:-$(ls -d *.xcodeproj 2>/dev/null | head -1)}"
SCHEME="${SCHEME:-$(xcodebuild -list -project "$PROJECT" -json 2>/dev/null | python3 -c "import sys,json;print(json.load(sys.stdin)['project']['schemes'][0])" 2>/dev/null)}"

OUT="$ROOT/ios-audit/ios-qa-audit/test-results.xcresult"
rm -rf "$OUT"
mkdir -p "$(dirname "$OUT")"

DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild test \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -destination "platform=iOS Simulator,name=$DEVICE" \
    -enableCodeCoverage YES \
    -resultBundlePath "$OUT" 2>&1 \
    | xcbeautify 2>/dev/null || cat
echo "[run-xcodebuild-tests] → $OUT"
