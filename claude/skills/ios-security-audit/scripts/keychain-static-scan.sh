#!/usr/bin/env bash
# keychain-static-scan.sh — Grep-based scan for Keychain usage patterns.
#
# Emits JSON tallying:
#   - keychain_call_sites (file, line, api)
#   - deprecated_accessibility (Always*)
#   - silenced_errors (try? on SecItem* calls)
#   - uses_access_control (bool)
#   - uses_access_groups (bool)

set -eu
ROOT="${1:?project root required}"
cd "$ROOT"

# Helper: emit JSON-escaped string
json_str() { python3 -c "import json,sys;print(json.dumps(sys.stdin.read().rstrip()))"; }

# Call sites
CALL_SITES=$(grep -rn --include='*.swift' \
    -E 'SecItem(Add|Update|Copy|Delete|CopyMatching)' . 2>/dev/null \
    | head -200 \
    | python3 -c "
import sys, json, re
items = []
for line in sys.stdin:
    m = re.match(r'^(\./)?(.+?):(\d+):(.*)', line)
    if not m:
        continue
    file, lineno, snippet = m.group(2), int(m.group(3)), m.group(4).strip()
    api = re.search(r'SecItem(Add|Update|Copy|Delete|CopyMatching)', snippet)
    items.append({'file': file, 'line': lineno, 'api': 'SecItem' + (api.group(1) if api else '?'), 'snippet': snippet[:120]})
print(json.dumps(items))
")

DEPRECATED=$(grep -rn --include='*.swift' \
    -E 'kSecAttrAccessibleAlways(ThisDeviceOnly)?' . 2>/dev/null \
    | head -50 \
    | python3 -c "
import sys, json, re
items = []
for line in sys.stdin:
    m = re.match(r'^(\./)?(.+?):(\d+):(.*)', line)
    if m:
        items.append({'file': m.group(2), 'line': int(m.group(3)), 'snippet': m.group(4).strip()[:120]})
print(json.dumps(items))
")

SILENCED=$(grep -rn --include='*.swift' -B 1 -A 1 \
    -E '(SecItemAdd|SecItemCopyMatching|SecItemUpdate)' . 2>/dev/null \
    | grep -E 'try\?|_ =' \
    | head -50 \
    | python3 -c "
import sys, json, re
items = []
for line in sys.stdin:
    line = line.lstrip('-:')
    m = re.match(r'^(\./)?(.+?):(\d+):(.*)', line)
    if m:
        items.append({'file': m.group(2), 'line': int(m.group(3)), 'snippet': m.group(4).strip()[:120]})
print(json.dumps(items))
")

USES_ACL=$(grep -rln --include='*.swift' \
    -E 'SecAccessControlCreateWithFlags|kSecAttrAccessControl' . 2>/dev/null \
    | head -1)
USES_ACL_BOOL=$([ -n "$USES_ACL" ] && echo true || echo false)

USES_GROUPS=$(grep -rln --include='*.entitlements' \
    'keychain-access-groups' . 2>/dev/null | head -1)
USES_GROUPS_BOOL=$([ -n "$USES_GROUPS" ] && echo true || echo false)

cat <<EOF
{
  "keychain_call_sites": $CALL_SITES,
  "deprecated_accessibility": $DEPRECATED,
  "silenced_errors": $SILENCED,
  "uses_access_control": $USES_ACL_BOOL,
  "uses_access_groups": $USES_GROUPS_BOOL
}
EOF
