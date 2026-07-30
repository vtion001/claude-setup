#!/usr/bin/env bash
# kpi-pull.sh — assemble a per-department KPI inventory from available sources (Tier 1, --measure).
# Usage: kpi-pull.sh [TARGET_DIR]   (defaults to current directory)
# Read-only. Prints a markdown inventory to stdout — the Measure phase scores from this.
# Does NOT directly call Ahrefs/Linear MCPs (those run from Claude, not bash) — flags their
# availability and points the Measure phase to the right tool calls.
set -uo pipefail

DIR="${1:-.}"
cd "$DIR" || { echo "cannot cd to $DIR"; exit 1; }
have() { command -v "$1" >/dev/null 2>&1; }

echo "# KPI inventory — $DIR"
echo "_Generated for the Measure phase. Each row → one measurement input with n/window/source._"
echo

# ---- CSV summary (rows, header sample) ----
echo "## CSV / TSV inputs"
csvs=$(find . -maxdepth 3 -type f \( -iname '*.csv' -o -iname '*.tsv' \) \
  -not -path '*/node_modules/*' -not -path '*/.git/*' -not -path '*/six-sigma*/*' 2>/dev/null | head -40)
if [ -z "$csvs" ]; then
  echo "  (none — recommend exporting CRM/HRIS/billing data into ./data/)"
else
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    # row count (subtract 1 for header), conservative cap to avoid hangs on huge files
    rows=$(wc -l <"$f" 2>/dev/null | tr -d ' ')
    rows=$(( rows > 0 ? rows - 1 : 0 ))
    header=$(head -1 "$f" 2>/dev/null | cut -c1-160)
    echo "- \`$f\` — rows: **$rows**"
    echo "  · header: $header"
  done <<< "$csvs"
fi
echo

# ---- Google Sheets bootstrap via gog ----
echo "## Google Sheets (gog)"
if have gog; then
  echo "- gog present. To enumerate shared sheets and capture a KPI inventory, run:"
  echo "  \`\`\`bash"
  echo "  gog sheets list 2>/dev/null | head -50"
  echo "  # then for each candidate, e.g.:"
  echo "  # gog sheets read <SHEET_ID> <TAB_NAME> --range A1:Z200 > ./data/<dept>-kpi.csv"
  echo "  \`\`\`"
  echo "- Record the SHEET_ID, tab, range, row count (n) and the time window it covers."
else
  echo "- gog CLI not installed — skipping Sheets ingestion."
fi
echo

# ---- Sibling agent outputs ----
echo "## Sibling-agent outputs found"
sibling=""
for hint in business-research lead-generator search-console-analyst website-analyst report-orchestrator; do
  for hit in $(find . -maxdepth 4 -type d -iname "*${hint}*" -not -path '*/node_modules/*' -not -path '*/.git/*' 2>/dev/null); do
    cnt=$(find "$hit" -maxdepth 3 -type f \( -iname '*.md' -o -iname '*.json' -o -iname '*.csv' \) 2>/dev/null | wc -l | tr -d ' ')
    echo "- \`$hit\` — $cnt artifact(s)"; sibling=1
  done
done
[ -z "$sibling" ] && echo "  (none — run /business-research, /lead-generator, or /search-console-analyst first)"
echo

# ---- Department mapping hint ----
echo "## Per-department mapping hint"
cat <<'EOF'
Map each input above to a department. Suggested heuristic (refine per workspace):

| Dept | Look for files like |
|------|---------------------|
| Marketing | leads*, mql*, channels*, ga4*, gsc*, ahrefs*, campaigns*, mqtt*-marketing |
| Sales | deals*, pipeline*, opps*, opportunity*, salesforce*, hubspot-deals* |
| CS / Support | customers*, tickets*, churn*, nps*, csat*, support* |
| Operations | orders*, fulfillment*, shipments*, sla*, wms* |
| Finance | invoices*, ar*, dso*, billing*, accounting* |
| People | hires*, ats*, hris*, attrition*, ramp* |

If a file's department is ambiguous, the Define phase has to resolve it (it likely means the file
is reporting more than one department — a Measurement waste).
EOF
echo

# ---- MCP next-steps (executed from Claude, not bash) ----
echo "## MCP next-steps (run from Claude, not this script)"
cat <<'EOF'
- **Ahrefs MCP** — pull GSC + keyword + brand-radar data for the Marketing CTQs. Look up:
  - `mcp__claude_ai_Ahrefs__gsc-pages`, `gsc-keywords`, `gsc-performance-history`, `keywords-explorer-overview`.
  - For brand: `brand-radar-mentions-overview`, `brand-radar-sov-overview`.
  - Respect each tool's `render_with` metadata.
- **Linear MCP** — pull cross-functional issue counts and cycle time:
  - `mcp__claude_ai_Linear__list_issues` (filter by labels: bug, customer-escalation, ops-incident).
  - `mcp__claude_ai_Linear__list_cycles` for cycle-time signal.
  - File the improvement backlog via `mcp__claude_ai_Linear__save_issue` with label
    `Business / Six Sigma` and sub-label `Dept: <name>`.
- **Privacy:** drop PII columns before aggregation; redact secrets in any quoted config.
EOF
echo

echo "Inventory complete. Use this as the data-inventory table in the Measure phase report."
