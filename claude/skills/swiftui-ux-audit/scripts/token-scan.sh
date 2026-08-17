#!/usr/bin/env bash
# token-scan.sh — static design-token violation scan.
#
# Reads the project's design-token file path from the detection JSON, then
# greps for token bypasses across Swift sources. Emits a single JSON object.
#
# Usage:
#   token-scan.sh [<project-root>] [<detect-json-path>]

set -eu

ROOT="${1:-$PWD}"
DETECT="${2:-$ROOT/swiftui-ux-audit/.detect.json}"
cd "$ROOT"

TOKEN_FILE=""
TOKEN_FILES_GREP_ARGS=""
if [ -f "$DETECT" ]; then
    TOKEN_FILE=$(python3 -c "import json;d=json.load(open('$DETECT'));print(d.get('token_file',''))")
    # All detected token files, as a pipe-separated grep pattern
    TOKEN_FILES_PIPE=$(python3 -c "
import json,re
d=json.load(open('$DETECT'))
files=d.get('token_files') or ([d['token_file']] if d.get('token_file') else [])
print('|'.join(re.escape(f) for f in files))")
fi

# Helper that returns count + first 10 sample matches as JSON
scan() {
    local pattern="$1"
    local excludes_token="${2:-yes}"
    local extra_exclude="${3:-}"
    local matches
    matches=$(grep -rEn --include='*.swift' \
        --exclude-dir='.derived' \
        --exclude-dir='build' \
        --exclude-dir='.build' \
        --exclude-dir='Pods' \
        --exclude-dir='Carthage' \
        --exclude-dir='*UITests*' \
        --exclude-dir='*Tests*' \
        "$pattern" . 2>/dev/null || true)
    if [ -n "$TOKEN_FILES_PIPE" ] && [ "$excludes_token" = "yes" ]; then
        matches=$(printf '%s\n' "$matches" | grep -vE "$TOKEN_FILES_PIPE" || true)
    fi
    if [ -n "$extra_exclude" ]; then
        matches=$(printf '%s\n' "$matches" | grep -v "$extra_exclude" || true)
    fi
    local count
    count=$(printf '%s\n' "$matches" | grep -c . || true)
    local samples
    samples=$(printf '%s\n' "$matches" | head -10 | python3 -c '
import sys,json
print(json.dumps([l.strip() for l in sys.stdin if l.strip()]))')
    printf '{"count":%d,"samples":%s}' "$count" "$samples"
}

cat <<JSON
{
  "token_file": "$TOKEN_FILE",
  "violations": {
    "raw_font_system":      $(scan '\.font\(\.system\('),
    "raw_padding_int":      $(scan '\.padding\([0-9]+(\.[0-9]+)?\)'),
    "raw_corner_radius_int":$(scan '\.cornerRadius\([0-9]+(\.[0-9]+)?\)'),
    "raw_color_hex":        $(scan 'Color\(hex:' yes '/Models/'),
    "raw_color_rgb":        $(scan 'Color\(red:[ 0-9.,a-z]+,'),
    "font_custom":          $(scan 'Font\.custom\('),
    "raw_shadow":           $(scan '\.shadow\(color:'),
    "stack_int_spacing":    $(scan '(HStack|VStack|LazyVStack|LazyHStack)\(spacing:[ ]*[0-9]+(\.[0-9]+)?\)'),
    "raw_animation":        $(scan '\.(easeInOut|easeIn|easeOut|spring|interactiveSpring)\(')
  }
}
JSON
