#!/usr/bin/env bash
#
# SubagentStop (matcher: sentinal|verity|aesthetica) — appends a line every
# time a ship-loop review subagent finishes, as a deterministic audit trail
# the LLM doesn't have to remember to keep.
# Ported from claude-setup's ship-loop/build-scripts/subagentstop-review-log.ps1.
input="$(cat 2>/dev/null || true)"
[ -z "$input" ] && exit 0

log_dir="$HOME/.claude/hooks/ship-loop/logs"
mkdir -p "$log_dir"

agent=$(printf '%s' "$input" | jq -r '.agent_type // empty' 2>/dev/null)
session=$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null)
cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)
time=$(date -u +"%Y-%m-%dT%H:%M:%S.000Z")

jq -nc --arg time "$time" --arg agent "$agent" --arg session "$session" --arg cwd "$cwd" \
  '{time: $time, agent: $agent, session: $session, cwd: $cwd}' >> "$log_dir/review-log.jsonl"

exit 0
