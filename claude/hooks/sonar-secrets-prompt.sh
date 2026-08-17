#!/usr/bin/env bash
#
# UserPromptSubmit — block the prompt if `sonar` flags secrets pasted into it.
# Ported from claude-setup's sonar-secrets/build-scripts/prompt-secrets.ps1.
# No-ops if `sonar` isn't installed (same graceful-degrade behavior as the source).
input="$(cat 2>/dev/null || true)"
[ -z "$input" ] && exit 0

prompt=$(printf '%s' "$input" | jq -r '.prompt // empty' 2>/dev/null)
[ -z "$prompt" ] && exit 0

command -v sonar >/dev/null 2>&1 || exit 0

tmpfile=$(mktemp "${TMPDIR:-/tmp}/cc-prompt-secrets.XXXXXX")
printf '%s' "$prompt" > "$tmpfile"

sonar analyze secrets "$tmpfile" >/dev/null 2>&1
exit_code=$?
rm -f "$tmpfile"

if [ "$exit_code" -eq 51 ]; then
  jq -n '{decision: "block", reason: "Sonar detected secrets in prompt"}'
fi

exit 0
