#!/usr/bin/env bash
# boot-simulator.sh — boot an iOS Simulator by name or UDID. Idempotent.
#
# Usage:
#   boot-simulator.sh "iPhone 17"
#   boot-simulator.sh "<UDID>"
#
# Prints the UDID of the booted simulator on stdout.

set -eu

QUERY="${1:-iPhone 17}"

# Resolve to UDID. If QUERY already looks like a UDID, use it directly.
UDID=""
if [[ "$QUERY" =~ ^[A-F0-9-]{36}$ ]]; then
    UDID="$QUERY"
else
    # NB: `python3 - <<heredoc` would steal stdin from the pipe; use `-c`
    # with the script inline so the pipe reaches sys.stdin.
    UDID=$(xcrun simctl list devices --json | python3 -c '
import json, sys
name = sys.argv[1]
devs = json.load(sys.stdin)["devices"]
for runtime, items in devs.items():
    if "iOS" not in runtime: continue
    for d in items:
        if d.get("isAvailable") and d.get("name") == name:
            print(d["udid"]); sys.exit(0)
' "$QUERY")
fi

if [ -z "$UDID" ]; then
    echo "Simulator not found: $QUERY" >&2
    exit 2
fi

# Boot if not already booted
STATE=$(xcrun simctl list devices --json | python3 -c '
import json, sys
u = sys.argv[1]
for r, it in json.load(sys.stdin)["devices"].items():
    for d in it:
        if d["udid"] == u:
            print(d.get("state", "")); sys.exit(0)
' "$UDID")

if [ "$STATE" != "Booted" ]; then
    xcrun simctl boot "$UDID" >/dev/null 2>&1 || true
    for _ in $(seq 1 30); do
        sleep 1
        s=$(xcrun simctl list devices --json | python3 -c '
import json, sys
u = sys.argv[1]
for r, it in json.load(sys.stdin)["devices"].items():
    for d in it:
        if d["udid"] == u:
            print(d.get("state", "")); sys.exit(0)
' "$UDID")
        [ "$s" = "Booted" ] && break
    done
fi

echo "$UDID"
