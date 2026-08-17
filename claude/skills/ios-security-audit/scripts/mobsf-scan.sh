#!/usr/bin/env bash
# mobsf-scan.sh — Runs mobsfscan against the project; emits JSON.
#
# Usage:
#   mobsf-scan.sh <project-root> [<output-json>]
#
# If mobsfscan isn't installed, exits 2 with a hint.

set -eu

ROOT="${1:?project root required}"
OUT="${2:-$ROOT/ios-audit/ios-security-audit/mobsf.json}"

mkdir -p "$(dirname "$OUT")"

if ! command -v mobsfscan > /dev/null 2>&1; then
    echo "[mobsf-scan] mobsfscan not installed. Install: pip install --user mobsfscan"
    exit 2
fi

cd "$ROOT"
mobsfscan --json -o "$OUT" . 2>&1 | tail -10
echo "[mobsf-scan] wrote $OUT"
