#!/usr/bin/env bash
# ~/.claude/prompt-boost.sh — stands in for $VISUAL so ctrl+g rewrites the draft
# prompt instead of opening an editor. Claude Code writes the input buffer to a
# temp file, runs this, then reloads the file back into the prompt box.
#
#   <text>        ctrl+g  ->  AI rewrite (fast path, no project-local CLAUDE.md)
#   +<text>       ctrl+g  ->  AI rewrite with project context (slower, sharper)
#   /cmd  #note   ctrl+g  ->  left untouched (slash command anywhere in buffer)
#   [Image #1]    ctrl+g  ->  left untouched (any attachment placeholder)
#   <empty>       ctrl+g  ->  no-op
#
# Ported from claude-setup's prompt-boost.ps1 (Windows/PowerShell original).
# Session + transcript resolution lives in prompt-boost-context.py (JSON/regex
# heavy work is far more robust in Python than bash).
#
# Original text is kept at ~/.claude/prompt-boost.last.txt
# Every invocation appends one line to ~/.claude/prompt-boost.log
#
#   --probe    resolve the session and print the context block, rewrite nothing

set -u

CLAUDE_BIN="/opt/homebrew/bin/claude"
[ -x "$CLAUDE_BIN" ] || CLAUDE_BIN="claude"
MODEL="claude-haiku-4-5-20251001"
REAL_EDITOR="${CLAUDE_REAL_EDITOR:-${EDITOR:-nano}}"
CLAUDE_DIR="$HOME/.claude"
SYS_PROMPT="$CLAUDE_DIR/prompt-boost.system.md"
MCP_CONFIG="$CLAUDE_DIR/prompt-boost.mcp.json"
BACKUP="$CLAUDE_DIR/prompt-boost.last.txt"
LOG_FILE="$CLAUDE_DIR/prompt-boost.log"
CONTEXT_HELPER="$CLAUDE_DIR/prompt-boost-context.py"
SCRATCH="${TMPDIR:-/tmp}/cc-prompt-boost"

ESC=$'\033'
say()  { printf '%s[38;5;%sm%s%s[0m' "$ESC" "${2:-244}" "$1" "$ESC"; }
line() { printf '%s[38;5;%sm%s%s[0m\n' "$ESC" "${2:-244}" "$1" "$ESC"; }

log() {
  printf '%s  %s\n' "$(date +%H:%M:%S)" "$1" >> "$LOG_FILE"
}

get_context_block() {
  python3 "$CONTEXT_HELPER" 2>/dev/null
}

if [ "${1:-}" = "--probe" ] || [ "${1:-}" = "-Probe" ]; then
  start=$(date +%s.%N)
  ctx_json=$(get_context_block)
  end=$(date +%s.%N)
  ms=$(awk -v a="$start" -v b="$end" 'BEGIN{printf "%.0f", (b-a)*1000}')
  text=$(printf '%s' "$ctx_json" | jq -r '.text // empty')
  if [ -z "$text" ]; then
    line 'no conversation context resolved' 203
    exit 1
  fi
  turns=$(printf '%s' "$ctx_json" | jq -r '.turns')
  elided=$(printf '%s' "$ctx_json" | jq -r '.elided')
  session=$(printf '%s' "$ctx_json" | jq -r '.session')
  chars=${#text}
  line "session $session  |  $turns turns  |  $elided truncated  |  $chars chars  |  ${ms}ms" 45
  echo ""
  printf '%s\n' "$text"
  exit 0
fi

FILE="${1:-}"
[ -z "$FILE" ] || [ ! -f "$FILE" ] && exit 0
mkdir -p "$SCRATCH"

# git and friends also honour $VISUAL. If handed a commit message, rebase todo,
# tag message etc, hand straight over to a real editor — rewriting one of those
# would be destructive. ctrl+g itself never reaches this path (Claude Code's temp
# file is never named COMMIT_EDITMSG, and Claude Code pins GIT_EDITOR separately).
leaf=$(basename "$FILE")
case "$leaf" in
  COMMIT_EDITMSG|MERGE_MSG|SQUASH_MSG|TAG_EDITMSG|NOTES_EDITMSG|git-rebase-todo|addp-hunk-edit.diff)
    log "git file '$leaf' -> handing to $REAL_EDITOR"
    "$REAL_EDITOR" "$FILE"
    exit 0
    ;;
esac

orig=$(cat "$FILE")
trimmed=$(printf '%s' "$orig" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')

if [ -z "$trimmed" ]; then
  log 'empty buffer - no-op'
  exit 0
fi

# Things that must never be rewritten, checked anywhere in the buffer:
#  1. Attachment placeholders — Claude Code substitutes real content for these
#     on submit; a rewrite that reworded/dropped one would silently detach it.
#  2. A LEADING slash command — Claude Code only parses "/word ..." as an
#     actual command+args invocation when it's the first token of the whole
#     buffer, so rewriting any part of it (including the "args") risks
#     breaking how that command parses its own arguments.
#  3. '#' memory writes — literal control input.
#
# A slash command merely MENTIONED mid-message ("use /ponytail-audit then fix
# X too") is NOT a leading token, so Claude Code won't parse the buffer as an
# invocation at all — it's safe to rewrite the surrounding prose. That case is
# handled below by asking the rewriter to preserve the mention verbatim
# instead of skipping the whole draft (see prompt-boost.system.md).
attach_re='\[(Pasted text #[0-9]+( \+[0-9]+ lines)?|Image #[0-9]+|Audio #[0-9]+|Image|Image source:[^]]*|Image:[^]]*|\.\.\.Truncated text #[0-9]+[^]]*)\]'
leading_slash_re='^/[a-zA-Z][a-zA-Z0-9_-]*([[:space:]]|$)'

skip=""
if printf '%s' "$trimmed" | grep -qE "$attach_re"; then
  skip="attachment"
elif printf '%s' "$trimmed" | grep -qE "$leading_slash_re"; then
  skip="slash command"
elif [ "${trimmed:0:1}" = "#" ]; then
  skip="memory write"
fi

if [ -n "$skip" ]; then
  log "skip ($skip) - buffer untouched"
  say "╰─ " 240
  line "$skip - left untouched" 244
  sleep 0.9
  exit 0
fi

# --- mode ---------------------------------------------------------------
with_context=false
if [ "${trimmed:0:1}" = "+" ]; then
  with_context=true
  trimmed=$(printf '%s' "${trimmed:1}" | sed -e 's/^[[:space:]]*//')
fi
[ -z "$trimmed" ] && exit 0

printf '%s' "$orig" > "$BACKUP"

# Never let context-gathering break the rewrite: no session, no transcript, or
# a malformed line all degrade to the old context-free behaviour.
ctx_json=$(get_context_block)
ctx_text=$(printf '%s' "$ctx_json" | jq -r '.text // empty' 2>/dev/null)
ctx_turns=$(printf '%s' "$ctx_json" | jq -r '.turns // empty' 2>/dev/null)

echo ""
say "╭─ " 240
say "PROMPT BOOST " 45
say "$MODEL " 111
[ "$with_context" = true ] && say "+context " 213
if [ -n "$ctx_text" ]; then say "$ctx_turns turns " 78; else say "no convo " 214; fi
line "${#trimmed} chars" 244

convo="${ctx_text:-(none available)}"
payload="<recent_conversation>
$convo
</recent_conversation>

<draft>
$trimmed
</draft>"

work_dir="$SCRATCH"
[ "$with_context" = true ] && work_dir="$(pwd)"

start=$(date +%s.%N)
out=$(cd "$work_dir" && CLAUDE_HOME="$HOME/.claude" MAX_THINKING_TOKENS=0 DISABLE_INTERLEAVED_THINKING=1 \
  "$CLAUDE_BIN" -p --model "$MODEL" \
    --system-prompt-file "$SYS_PROMPT" \
    --setting-sources project \
    --strict-mcp-config --mcp-config "$MCP_CONFIG" \
    --disable-slash-commands \
    --allowed-tools "" \
    <<< "$payload" 2>/tmp/prompt-boost-err.$$)
exit_code=$?
err=$(cat /tmp/prompt-boost-err.$$ 2>/dev/null); rm -f /tmp/prompt-boost-err.$$
end=$(date +%s.%N)
secs=$(awk -v a="$start" -v b="$end" 'BEGIN{printf "%.1f", b-a}')

clean=$(printf '%s' "$out" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
# strip a wrapping ```lang fence if the model added one
if printf '%s' "$clean" | grep -qE '^```'; then
  inner=$(printf '%s' "$clean" | sed -e '1d' -e '$d')
  clean="$inner"
fi

# An intentional clarifying question (system prompt's reference-ambiguity
# rule) is marked with a leading "❓" so it can't be confused with meta-
# commentary below — write it straight to the buffer for the user to read
# and answer, skipping the looks_meta filter entirely (which would otherwise
# reject it, since "Which one/of" and similar are deliberately on that list).
if printf '%s' "$clean" | grep -qE '^❓'; then
  printf '%s' "$clean" > "$FILE"
  preview=$(printf '%s' "$clean" | tr -s '[:space:]' ' ' | cut -c1-70)
  log "question ${secs}s: $preview"
  say "╰─ " 240
  say "❓ " 220
  line "clarifying question - read it, then answer" 244
  sleep 0.6
  exit 0
fi

# Last line of defence: writing meta-commentary into the buffer is how a
# clarifying question ends up submitted as a prompt.
looks_meta=false
bad_patterns=(
  '^[[:space:]]*(I need|I.ll need|I cannot|I can.t|To rewrite|Which one|Which of)'
  '^[[:space:]]*(Could|Can) you (please )?(clarify|specify|provide|confirm|tell me|share|paste|elaborate)'
  '^[[:space:]]*Please (provide|clarify|specify|confirm|paste|share)'
  '(need|needs|require|requires|without) (more |additional |further )?(clarification|context|information about)'
  "I.ll rewrite|rewrite your (request|prompt)|your request as a"
  "^[[:space:]]*(Sure|Certainly|Here.s the|Here is the)"
)
for pat in "${bad_patterns[@]}"; do
  if printf '%s' "$clean" | grep -qiE "$pat"; then
    looks_meta=true
    break
  fi
done

if [ "$looks_meta" = true ]; then
  preview=$(printf '%s' "$clean" | tr -s '[:space:]' ' ' | cut -c1-70)
  log "REJECTED meta-output (kept original): $preview"
  say "╰─ " 240
  line 'not a rewrite - original kept' 214
  sleep 1.5
  exit 0
fi

if [ "$exit_code" -ne 0 ] || [ -z "$clean" ]; then
  say "╰─ " 240
  line "boost failed (exit $exit_code) - prompt left untouched" 203
  if [ -n "$err" ]; then
    line "   $(printf '%s' "$err" | head -1)" 240
  fi
  sleep 1.4
  exit 0
fi

printf '%s' "$clean" > "$FILE"
log "ok ${secs}s ${#trimmed}->${#clean} chars  ctx $([ -n "$ctx_text" ] && echo "$ctx_turns turns/${#ctx_text} chars" || echo none)"
say "╰─ " 240
say "✓ " 78
line "${secs}s  ${#trimmed} → ${#clean} chars   (original saved to ~/.claude/prompt-boost.last.txt)" 244
sleep 0.55
exit 0
