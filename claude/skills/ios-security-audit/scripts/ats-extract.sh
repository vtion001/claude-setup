#!/usr/bin/env bash
# ats-extract.sh — Read Info.plist's NSAppTransportSecurity block, emit JSON.
#
# Usage:
#   ats-extract.sh <Info.plist>

set -eu
PLIST="${1:?Info.plist path required}"

if [ ! -f "$PLIST" ]; then
    echo '{"error": "Info.plist not found"}'
    exit 1
fi

# Use python3 + plistlib for proper parsing (vs grepping plutil output)
python3 <<PY
import plistlib, json, sys
with open("$PLIST", "rb") as f:
    p = plistlib.load(f)
ats = p.get("NSAppTransportSecurity", {})
print(json.dumps({
    "allows_arbitrary_loads": ats.get("NSAllowsArbitraryLoads", False),
    "allows_arbitrary_loads_in_web_content": ats.get("NSAllowsArbitraryLoadsInWebContent", False),
    "allows_local_networking": ats.get("NSAllowsLocalNetworking", False),
    "exception_domains": ats.get("NSExceptionDomains", {}),
    "raw": ats
}, default=str, indent=2))
PY
