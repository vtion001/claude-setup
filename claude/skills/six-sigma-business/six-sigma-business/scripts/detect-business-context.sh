#!/usr/bin/env bash
# detect-business-context.sh — identify available business data sources in the workspace.
# Usage: detect-business-context.sh [TARGET_DIR]   (defaults to current directory)
# Read-only. Prints a small markdown report to stdout. Sibling of six-sigma-mbb/scripts/detect-project.sh.
# NOT -e: all best-effort detection — a failing check must not abort the script.
set -uo pipefail

DIR="${1:-.}"
cd "$DIR" || { echo "cannot cd to $DIR"; exit 1; }

have() { command -v "$1" >/dev/null 2>&1; }
exists() { [ -e "$1" ] && echo "$1"; }

echo "# Business-context detection — $DIR"
echo

# ---- CSV / spreadsheet data ----
echo "## Local data files"
data_found=""
for d in data exports crm-export crm_exports csv ops-data; do
  if [ -d "$d" ]; then
    cnt=$(find "$d" -maxdepth 3 -type f \( -iname '*.csv' -o -iname '*.tsv' -o -iname '*.xlsx' \) 2>/dev/null | wc -l | tr -d ' ')
    [ "$cnt" -gt 0 ] && { echo "- $d/ — $cnt data file(s)"; data_found=1; }
  fi
done
# also look for loose CSVs at the workspace root
loose=$(find . -maxdepth 2 -type f \( -iname '*.csv' -o -iname '*.tsv' \) -not -path './node_modules/*' -not -path './.git/*' 2>/dev/null | head -20)
if [ -n "$loose" ]; then
  echo "- Loose CSV/TSV files near root:"
  printf "%s\n" "$loose" | sed 's/^/  · /'
  data_found=1
fi
[ -z "$data_found" ] && echo "  (no local CSV/Excel data found — recommend exporting from CRM/Sheets)"
echo

# ---- Google Sheets via gog ----
echo "## Google Sheets (via gog CLI)"
if have gog; then
  echo "- gog CLI present at $(command -v gog)"
  acct=$(gog account current 2>/dev/null || echo "(unknown — run \`gog account current\` to confirm)")
  echo "  · Authed account: $acct — confirm before --measure"
  echo "  · Tip: \`gog sheets list\` to enumerate; \`gog sheets read <SHEET_ID> <TAB>\` to ingest"
else
  echo "- gog CLI NOT found — Sheets ingestion disabled"
  echo "  · Install: brew install steipete/tap/gogcli"
fi
echo

# ---- Sibling agent outputs ----
echo "## Sibling-agent outputs"
agent_found=""
for hint in business-research lead-generator search-console-analyst website-analyst report-orchestrator; do
  for hit in $(find . -maxdepth 4 -type d -iname "*${hint}*" -not -path '*/node_modules/*' -not -path '*/.git/*' 2>/dev/null); do
    echo "- $hit/"; agent_found=1
  done
done
# also look for markdown outputs that look like agent reports
find . -maxdepth 3 -type f \( -iname '*-report.md' -o -iname '*-analysis.md' -o -iname '*-findings.md' \) -not -path '*/node_modules/*' -not -path '*/.git/*' 2>/dev/null | head -20 | while read -r f; do
  echo "- report: $f"
done
[ -z "$agent_found" ] && echo "  (run /business-research, /lead-generator, /search-console-analyst first for a richer baseline)"
echo

# ---- Existing six-sigma reports (engineering and business) ----
echo "## Existing six-sigma reports (avoid duplication)"
sigma_found=""
for p in six-sigma six-sigma-business; do
  for hit in $(find . -maxdepth 4 -type d -name "$p" -not -path '*/node_modules/*' -not -path '*/.git/*' 2>/dev/null); do
    echo "- $hit/"; sigma_found=1
  done
done
[ -z "$sigma_found" ] && echo "  (no prior six-sigma output — this is a clean baseline)"
echo

# ---- MCP availability hint ----
echo "## MCP availability (probe lightly)"
echo "- Ahrefs MCP: tools start with mcp__claude_ai_Ahrefs__* — probe via /mcp or a list call"
echo "- Linear MCP: tools start with mcp__claude_ai_Linear__* (claude.ai-hosted) or mcp__linear-vjr-dev__* (local)"
echo "- gog Workspace: shell-only, no MCP — drive via the gog CLI in scripts/kpi-pull.sh"
echo "- (This script cannot verify MCP auth; --measure will discover and fall back gracefully.)"
echo

# ---- Git context (process docs / SOPs) ----
echo "## Git / docs"
if exists .git >/dev/null; then
  echo "- git repo · branch: $(git rev-parse --abbrev-ref HEAD 2>/dev/null) · commits: $(git rev-list --count HEAD 2>/dev/null)"
else
  echo "- (not a git repo — process-doc churn signal unavailable)"
fi
# look for SOP / playbook docs
sops=$(find . -maxdepth 3 -type f \( -iname '*sop*.md' -o -iname '*playbook*.md' -o -iname '*runbook*.md' \) -not -path '*/node_modules/*' -not -path '*/.git/*' 2>/dev/null | head -10)
if [ -n "$sops" ]; then
  echo "- Operational docs found:"
  printf "%s\n" "$sops" | sed 's/^/  · /'
fi
echo

echo "Detection complete. Feed this into Define/Measure; then run scripts/kpi-pull.sh under --measure."
