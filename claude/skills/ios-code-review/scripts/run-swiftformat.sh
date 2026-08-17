#!/usr/bin/env bash
# run-swiftformat.sh — Run swiftformat --lint and count files needing changes.
set -eu
ROOT="${1:-$PWD}"
OUT="${2:-$ROOT/ios-audit/ios-code-review/swiftformat.txt}"
mkdir -p "$(dirname "$OUT")"

if ! command -v swiftformat > /dev/null 2>&1; then
    echo "[run-swiftformat] not installed; skipping"
    echo "swiftformat not installed" > "$OUT"
    exit 2
fi

cd "$ROOT"
swiftformat --lint . 2>&1 | tee "$OUT" | tail -5
