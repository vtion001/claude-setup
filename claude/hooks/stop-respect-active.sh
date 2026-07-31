#!/usr/bin/env bash
#
# Stop-hook safety net.
#
# Claude Code Stop hooks receive a JSON input on stdin. When the harness
# re-invokes after a previous Stop hook blocked the turn from ending, it
# sets `stop_hook_active: true`. This script reads that flag and exits 0
# (success = let the turn end) the moment it's set — preventing the
# 9-block-cap loop the user just hit.
#
# When stop_hook_active is false (the first time a Stop fires in a turn),
# this script also exits 0 — i.e. it never blocks. The intent is: stop
# means stop. Goal-completion enforcement is an external thing the user
# can re-enable per-task if they want.
#
# Reference: https://docs.claude.com/en/docs/claude-code/hooks
input="$(cat 2>/dev/null || true)"
echo "{}"  # empty hook output = no overrides, let the turn end
exit 0
