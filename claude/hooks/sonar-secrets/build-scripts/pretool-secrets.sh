#!/usr/bin/env bash
#
# PreToolUse (matcher: Read) — deny reading a file if `sonar` flags secrets in it.
# Ported from claude-setup's sonar-secrets/build-scripts/pretool-secrets.ps1.
# No-ops if `sonar` isn't installed (same graceful-degrade behavior as the source).
input="$(cat 2>/dev/null || true)"
[ -z "$input" ] && exit 0

tool_name=$(printf '%s' "$input" | jq -r '.tool_name // empty' 2>/dev/null)
file_path=$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null)

[ "$tool_name" != "Read" ] && exit 0
[ -z "$file_path" ] && exit 0
[ ! -e "$file_path" ] && exit 0

command -v sonar >/dev/null 2>&1 || exit 0

sonar analyze secrets "$file_path" >/dev/null 2>&1
exit_code=$?

if [ "$exit_code" -eq 51 ]; then
  jq -n --arg reason "Sonar detected secrets in file: $file_path" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: $reason
    }
  }'
fi

exit 0
