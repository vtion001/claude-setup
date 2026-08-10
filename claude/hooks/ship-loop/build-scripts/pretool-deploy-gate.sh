#!/usr/bin/env bash
#
# PreToolUse (matcher: Bash) — blocks deploy-shaped Bash commands unless a
# fresh (<4h) passing GATE marker exists for this working directory.
# Backstop only — the primary control is the ship-loop skill's own GATE step
# and the user confirmation in its SHIP step.
# Ported from claude-setup's ship-loop/build-scripts/pretool-deploy-gate.ps1.
input="$(cat 2>/dev/null || true)"
[ -z "$input" ] && exit 0

cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null)
cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)

printf '%s' "$cmd" | grep -qiE '(vercel[[:space:]]+.*--prod|render[[:space:]]+deploy|artisan[[:space:]]+migrate.*--force|git[[:space:]]+push[[:space:]]+(origin|upstream)[[:space:]]+(main|master)|npm[[:space:]]+publish|firebase[[:space:]]+deploy)' || exit 0

# md5 -q is macOS/BSD; md5sum is Linux — try both so this runs on either.
hash=$(printf '%s' "$cwd" | md5 -q 2>/dev/null || printf '%s' "$cwd" | md5sum | cut -d' ' -f1)
marker="${TMPDIR:-/tmp}/ship-loop-gate-${hash}.marker"

if [ -f "$marker" ]; then
  now=$(date +%s)
  # stat -f (BSD/macOS) vs stat -c (GNU/Linux) mtime syntax.
  mtime=$(stat -f %m "$marker" 2>/dev/null || stat -c %Y "$marker" 2>/dev/null)
  age=$(( now - mtime ))
  if [ "$age" -lt 14400 ]; then
    exit 0
  fi
fi

echo "ship-loop: deploy-shaped command blocked - no fresh passing quality gate recorded for this directory in the last 4 hours. Run the ship-loop GATE stage first, or tell Claude explicitly to bypass this check." >&2
exit 2
