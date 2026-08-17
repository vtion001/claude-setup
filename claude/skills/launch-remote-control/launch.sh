#!/usr/bin/env bash
#
# launch.sh — start a remote-controllable `claude` session on this Mac and
# verify it came up. Designed to be triggered when the operator is AWAY from
# the computer (e.g. on their phone) and needs a session they can take over
# from the Claude mobile app.
#
# Usage:
#   ./launch.sh [working-dir]
#
# Exit codes: 0 = remote-control process confirmed running, 1 = not found.

set -uo pipefail

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_DIR="${1:-/Users/archerterminez/Desktop/REPOSITORY/altoproperty-main}"

echo "→ launching new Terminal window → claude → /remote-control (cwd: $WORK_DIR)"
osascript "$SKILL_DIR/start-remote-control.applescript" "$WORK_DIR"

# claude needs a moment to register the --remote-control flag after we type the
# command; poll for up to ~20s.
echo "→ waiting for the remote-control process to register..."
for i in $(seq 1 10); do
  if pgrep -fl 'claude --remote-control' >/dev/null 2>&1; then
    echo "✓ remote-control session is live:"
    pgrep -fl 'claude --remote-control'
    echo
    echo "Now open the Claude mobile app and pair with this session."
    exit 0
  fi
  sleep 2
done

echo "✖ no 'claude --remote-control' process found after ~20s."
echo "  The Terminal window may still be loading claude — re-run, or check the"
echo "  screen for a pairing prompt. Note: this needs Terminal to have"
echo "  permission to run AppleScript (no Accessibility needed)."
exit 1
