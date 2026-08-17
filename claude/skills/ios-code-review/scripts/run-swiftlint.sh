#!/usr/bin/env bash
# run-swiftlint.sh — Run SwiftLint with JSON output. Falls back gracefully
# if not installed.
set -eu
ROOT="${1:-$PWD}"
OUT="${2:-$ROOT/ios-audit/ios-code-review/swiftlint.json}"
mkdir -p "$(dirname "$OUT")"

if ! command -v swiftlint > /dev/null 2>&1; then
    echo '{"error": "swiftlint not installed"}' > "$OUT"
    exit 2
fi

cd "$ROOT"
swiftlint --reporter json > "$OUT" 2>/dev/null || true
COUNT=$(python3 -c "import json; d=json.load(open('$OUT')); print(len(d) if isinstance(d, list) else 0)" 2>/dev/null || echo 0)
echo "[run-swiftlint] $COUNT violations → $OUT"
