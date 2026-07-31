#!/usr/bin/env bash
# ~/.claude/statusline.sh — Claude Code mission-control status line (macOS port).
# Reads the statusLine JSON payload on stdin, prints 3 ANSI-coloured rows.
# Ported from claude-setup's statusline.ps1 (Windows/PowerShell original).

input="$(cat)"
[ -z "$input" ] && exit 0

ESC=$'\033'
C()   { printf '%s[38;5;%sm%s%s[0m' "$ESC" "$2" "$1" "$ESC"; }
Dim() { printf '%s[2m%s%s[0m' "$ESC" "$1" "$ESC"; }

# green under 60%, amber under 85%, red above
tcol() { awk -v p="$1" 'BEGIN{ if(p<60) print 78; else if(p<85) print 214; else print 203 }'; }

kfmt() {
  awk -v n="$1" 'BEGIN{
    if (n>=1000000) printf "%.1fM", n/1000000
    else if (n>=1000) printf "%.0fk", n/1000
    else printf "%.0f", n
  }'
}

dfmt() {
  awk -v ms="$1" 'BEGIN{
    s=int(ms/1000)
    if (s>=3600) printf "%dh%02dm", int(s/3600), int((s%3600)/60)
    else if (s>=60) printf "%dm", int(s/60)
    else printf "%ds", s
  }'
}

bar() {
  # pct width full_char empty_char
  awk -v pct="$1" -v w="$2" -v full="$3" -v empty="$4" 'BEGIN{
    f = int((pct/100.0)*w + 0.5)
    if (f>w) f=w; if (f<0) f=0
    out=""
    for(i=0;i<f;i++) out = out full
    for(i=f;i<w;i++) out = out empty
    print out
  }'
}

jqr() { printf '%s' "$input" | jq -r "$1" 2>/dev/null; }

# No Nerd Font detected in ~/Library/Fonts or /Library/Fonts — use the ASCII
# fallback (matches statusline.ps1's $NERD=$false path). Switch these to
# $'' / $'' if a Nerd Font (e.g. MesloLGS NF) gets installed.
gBranch='@'
gPr='PR'

# --- machine metrics, cached 5s so the refresh tick stays cheap -------------
sys_cache="${TMPDIR:-/tmp}/cc-statusline-sys.json"
sys_cpu=""
sys_used_gb=""
sys_tot_gb=""
if [ -f "$sys_cache" ]; then
  age=$(( $(date +%s) - $(stat -f %m "$sys_cache" 2>/dev/null || echo 0) ))
  if [ "$age" -lt 5 ]; then
    sys_cpu=$(jq -r '.cpu // empty' "$sys_cache" 2>/dev/null)
    sys_used_gb=$(jq -r '.usedGb // empty' "$sys_cache" 2>/dev/null)
    sys_tot_gb=$(jq -r '.totGb // empty' "$sys_cache" 2>/dev/null)
  fi
fi
if [ -z "$sys_cpu" ]; then
  sys_cpu=$(top -l 1 -n 0 2>/dev/null | awk -F'[:,%]' '/CPU usage/{ for(i=1;i<=NF;i++){ if($i ~ /idle/){ gsub(/ /,"",$(i-1)); print 100-$(i-1); exit } } }')
  [ -z "$sys_cpu" ] && sys_cpu=0
  mem_total_bytes=$(sysctl -n hw.memsize 2>/dev/null || echo 0)
  sys_tot_gb=$(awk -v b="$mem_total_bytes" 'BEGIN{printf "%.1f", b/1073741824}')
  page_size=$(sysctl -n hw.pagesize 2>/dev/null || echo 4096)
  vmstat=$(vm_stat 2>/dev/null)
  pages_free=$(printf '%s' "$vmstat" | awk '/Pages free/{gsub(/\./,"",$3); print $3}')
  pages_inactive=$(printf '%s' "$vmstat" | awk '/Pages inactive/{gsub(/\./,"",$3); print $3}')
  free_bytes=$(( (${pages_free:-0} + ${pages_inactive:-0}) * page_size ))
  used_bytes=$(( mem_total_bytes - free_bytes ))
  sys_used_gb=$(awk -v b="$used_bytes" 'BEGIN{printf "%.1f", b/1073741824}')
  jq -n --argjson cpu "${sys_cpu%.*}" --arg usedGb "$sys_used_gb" --arg totGb "$sys_tot_gb" \
    '{cpu:$cpu, usedGb:($usedGb|tonumber), totGb:($totGb|tonumber)}' > "$sys_cache" 2>/dev/null
fi
sys_cpu_int=${sys_cpu%.*}
[ -z "$sys_cpu_int" ] && sys_cpu_int=0

# ==============================================================================
# ROW 1 — identity / model / mode
# ==============================================================================
r1=()
r1+=("$(C "$(whoami)@$(scutil --get ComputerName 2>/dev/null || hostname -s)" 45)")

model_name=$(jqr '.model.display_name // empty')
[ -n "$model_name" ] && r1+=("$(C "$model_name" 111)")

effort=$(jqr '.effort.level // empty')
[ -n "$effort" ] && r1+=("$(C "effort:$(printf '%s' "$effort" | tr '[:lower:]' '[:upper:]')" 140)")

fast_mode=$(jqr '.fast_mode // empty')
[ "$fast_mode" = "true" ] && r1+=("$(C 'FAST' 220)")

thinking_enabled=$(jqr '.thinking.enabled // empty')
[ -n "$thinking_enabled" ] && [ "$thinking_enabled" = "false" ] && r1+=("$(Dim 'think:off')")

agent_name=$(jqr '.agent.name // empty')
[ -n "$agent_name" ] && r1+=("$(C "agent:$agent_name" 213)")

remote_id=$(jqr '.remote.session_id // empty')
[ -n "$remote_id" ] && r1+=("$(C 'REMOTE' 51)")

vim_mode=$(jqr '.vim.mode // empty')
[ -n "$vim_mode" ] && [ "$vim_mode" != "INSERT" ] && r1+=("$(C "$vim_mode" 220)")

output_style=$(jqr '.output_style.name // empty')
[ -n "$output_style" ] && [ "$output_style" != "default" ] && r1+=("$(Dim "$output_style")")

r1+=("$(C "$(date +%H:%M:%S)" 244)")

row1=""
for i in "${!r1[@]}"; do
  [ "$i" -gt 0 ] && row1+="$(Dim ' - ')"
  row1+="${r1[$i]}"
done

# ==============================================================================
# ROW 2 — session telemetry
# ==============================================================================
r2=()
cw_size=$(jqr '.context_window.context_window_size // empty')
cw_used=$(jqr '.context_window.total_input_tokens // empty')
cw_pct=$(jqr '.context_window.used_percentage // empty')
if [ -n "$cw_size" ] && [ -n "$cw_pct" ]; then
  col=$(tcol "$cw_pct")
  pctfmt=$(awk -v p="$cw_pct" 'BEGIN{printf "%.0f%%", p}')
  r2+=("$(C 'CTX' 244) $(C "$(bar "$cw_pct" 10 $'█' $'░')" "$col") $(C "$pctfmt" "$col") $(Dim "$(kfmt "$cw_used")/$(kfmt "$cw_size")")")
fi

exceeds=$(jqr '.exceeds_200k_tokens // empty')
[ "$exceeds" = "true" ] && r2+=("$(C 'OVER-200k' 203)")

cost=$(jqr '.cost.total_cost_usd // empty')
if [ -n "$cost" ]; then
  costfmt=$(awk -v c="$cost" 'BEGIN{printf "$%.2f", c}')
  r2+=("$(C "$costfmt" 108)")
  dur=$(jqr '.cost.total_duration_ms // empty')
  if [ -n "$dur" ] && [ "$dur" != "0" ]; then
    r2+=("$(Dim "$(dfmt "$dur")")")
  fi
fi

rl5_pct=$(jqr '.rate_limits.five_hour.used_percentage // empty')
if [ -n "$rl5_pct" ]; then
  col=$(tcol "$rl5_pct")
  pctfmt=$(awk -v p="$rl5_pct" 'BEGIN{printf "%.0f%%", p}')
  r2+=("$(Dim '5h') $(C "$(bar "$rl5_pct" 5 $'▓' $'░')" "$col") $(C "$pctfmt" "$col")")
fi
rl7_pct=$(jqr '.rate_limits.seven_day.used_percentage // empty')
if [ -n "$rl7_pct" ]; then
  col=$(tcol "$rl7_pct")
  pctfmt=$(awk -v p="$rl7_pct" 'BEGIN{printf "%.0f%%", p}')
  r2+=("$(Dim '7d') $(C "$(bar "$rl7_pct" 5 $'▓' $'░')" "$col") $(C "$pctfmt" "$col")")
fi

row2=""
for i in "${!r2[@]}"; do
  [ "$i" -gt 0 ] && row2+="$(Dim ' | ')"
  row2+="${r2[$i]}"
done

# ==============================================================================
# ROW 3 — repo / PR / machine
# ==============================================================================
r3=()
dir=$(jqr '.workspace.current_dir // empty')
[ -z "$dir" ] && dir=$(jqr '.cwd // empty')

branch=""; ahead=0; behind=0; dirty=0
if [ -n "$dir" ] && [ -d "$dir" ]; then
  gs=$(git -C "$dir" status --porcelain=v2 --branch --untracked-files=no 2>/dev/null)
  branch=$(printf '%s\n' "$gs" | awk '/^# branch\.head /{print $3}')
  ab=$(printf '%s\n' "$gs" | awk '/^# branch\.ab /{print $3, $4}')
  ahead=$(printf '%s' "$ab" | awk '{gsub(/\+/,"",$1); print $1+0}')
  behind=$(printf '%s' "$ab" | awk '{gsub(/-/,"",$2); print $2+0}')
  dirty=$(printf '%s\n' "$gs" | grep -cE '^[12u] ')
fi

repo=$(jqr '.workspace.repo.name // empty')
if [ -z "$repo" ]; then
  proj_dir=$(jqr '.workspace.project_dir // empty')
  [ -n "$proj_dir" ] && repo=$(basename "$proj_dir")
fi
if [ -n "$repo" ]; then
  r3+=("$(C "$repo" 117)")
elif [ -n "$dir" ]; then
  r3+=("$(Dim "$(basename "$dir")")")
fi

if [ -n "$branch" ] && [ "$branch" != "(detached)" ]; then
  seg="$(C "$gBranch $branch" 150)"
  [ "$ahead" -gt 0 ] 2>/dev/null && seg+=" $(C "↑$ahead" 220)"
  [ "$behind" -gt 0 ] 2>/dev/null && seg+=" $(C "↓$behind" 220)"
  [ "$dirty" -gt 0 ] 2>/dev/null && seg+=" $(C "●$dirty" 203)"
  r3+=("$seg")
fi

worktree_flag=$(jqr '.workspace.git_worktree // empty')
worktree_name=$(jqr '.worktree.name // empty')
if [ "$worktree_flag" = "true" ] || [ -n "$worktree_name" ]; then
  [ -z "$worktree_name" ] && worktree_name="worktree"
  r3+=("$(C "wt:$worktree_name" 213)")
fi

lines_added=$(jqr '.cost.total_lines_added // empty')
lines_removed=$(jqr '.cost.total_lines_removed // empty')
if [ -n "$lines_added" ] || [ -n "$lines_removed" ]; then
  r3+=("$(C "✚${lines_added:-0}" 78) $(C "✖${lines_removed:-0}" 203)")
fi

pr_number=$(jqr '.pr.number // empty')
if [ -n "$pr_number" ]; then
  seg="$(C "$gPr #$pr_number" 111)"
  review_state=$(jqr '.pr.review_state // empty')
  case "$review_state" in
    approved) seg+=" $(C '✓approved' 78)" ;;
    changes_requested) seg+=" $(C '✗changes' 203)" ;;
    *) [ -n "$review_state" ] && seg+=" $(Dim "$review_state")" ;;
  esac
  r3+=("$seg")
fi

r3+=("$(Dim 'CPU') $(C "${sys_cpu_int}%" "$(tcol "$sys_cpu_int")")")
mem_pct=$(awk -v u="$sys_used_gb" -v t="$sys_tot_gb" 'BEGIN{ if(t>0) printf "%.0f", (u/t)*100; else print 0 }')
r3+=("$(Dim 'MEM') $(C "${sys_used_gb}/${sys_tot_gb}G" "$(tcol "$mem_pct")")")

row3=""
for i in "${!r3[@]}"; do
  [ "$i" -gt 0 ] && row3+="$(Dim ' | ')"
  row3+="${r3[$i]}"
done

# ==============================================================================
rule="${ESC}[38;5;240m"
printf '%s╭─ %s[0m%s\n' "$rule" "$ESC" "$row1"
printf '%s├─ %s[0m%s\n' "$rule" "$ESC" "$row2"
printf '%s╰─ %s[0m%s' "$rule" "$ESC" "$row3"
