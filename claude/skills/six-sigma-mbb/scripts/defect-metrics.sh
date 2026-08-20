#!/usr/bin/env bash
# defect-metrics.sh — derive defect/quality signals from git history + test artifacts.
# Usage: defect-metrics.sh [TARGET_DIR] [SINCE]
#   TARGET_DIR defaults to current dir; SINCE defaults to "90 days ago" (git --since format).
# Read-only. Prints a markdown report. These are the raw numbers for the Measure phase.
# NOT -e: best-effort; missing data must not abort.
set -uo pipefail

DIR="${1:-.}"
SINCE="${2:-90 days ago}"
cd "$DIR" || { echo "cannot cd to $DIR"; exit 1; }

if [ ! -e .git ]; then
  echo "# Defect metrics — no git repo at $DIR"
  echo "Git-derived signals unavailable. Use test results / Sentry / Linear instead (see data-sources.md)."
  exit 0
fi

echo "# Defect metrics — $DIR"
echo "_Window: since \"$SINCE\" · generated from git history (read-only)_"
echo

# ---- Commit volume (a proxy for 'units' of change) ----
TOTAL=$(git rev-list --count --since="$SINCE" HEAD 2>/dev/null || echo 0)
echo "## Change volume"
echo "- Commits in window: **$TOTAL**"
echo "- All-time commits: $(git rev-list --count HEAD 2>/dev/null || echo '?')"
echo

# ---- Bugfix-commit ratio (a proxy for defect density) ----
# Count commits whose subject signals a fix. Conventional-commits + common words.
FIX=$(git log --since="$SINCE" --pretty=%s 2>/dev/null | grep -ciE '^(fix|bugfix|hotfix)(\(|:|!)|\b(fix|fixed|fixes|bug|hotfix|patch|regression|revert)\b'); FIX=${FIX:-0}
echo "## Bugfix signal (defect proxy)"
echo "- Fix-type commits in window: **$FIX**"
if [ "$TOTAL" -gt 0 ] 2>/dev/null; then
  RATIO=$(awk "BEGIN{printf \"%.1f\", ($FIX/$TOTAL)*100}")
  echo "- Bugfix-commit ratio: **${RATIO}%** of commits"
  echo "  - Interpretation: higher = more rework (a DOWNTIME 'Defects' waste signal)."
fi
REVERTS=$(git log --since="$SINCE" --pretty=%s 2>/dev/null | grep -ciE '^revert|\brevert(ed|s)?\b'); echo "- Reverts in window: ${REVERTS:-0}"
echo

# ---- Churn hotspots (files changed most often → fishbone 'Material/Method' candidates) ----
echo "## Churn hotspots (top 10 most-changed files)"
echo "_High-churn files concentrate defects — prime Pareto/fishbone candidates._"
git log --since="$SINCE" --name-only --pretty=format: 2>/dev/null \
  | grep -vE '^\s*$' \
  | grep -vE '(^|/)(vendor|node_modules|dist|build|writable|\.git)/' \
  | sort | uniq -c | sort -rn | head -10 \
  | awk '{printf "- %s  (×%s changes)\n", $2, $1}'
echo

# ---- Files most associated with fixes (defect concentration) ----
echo "## Files most touched by fix commits (defect concentration)"
git log --since="$SINCE" --name-only --pretty='format:%s' 2>/dev/null \
  | awk '
    /^(fix|bugfix|hotfix)(\(|:|!)/ || /[Ff]ix|[Bb]ug|[Hh]otfix|[Pp]atch|[Rr]egression/ { infix=1; next }
    /^[A-Za-z0-9]/ && !/\// { infix=0 }   # likely a new subject line, reset
    infix && /\// { print $0 }
  ' \
  | grep -vE '(^|/)(vendor|node_modules|dist|build|writable|\.git)/' \
  | sort | uniq -c | sort -rn | head -10 \
  | awk '{printf "- %s  (×%s fix-touches)\n", $2, $1}'
echo "_(Heuristic: files appearing under fix-commit changesets. Verify before drawing conclusions.)_"
echo

# ---- Test counts (measurement-system size) ----
echo "## Test inventory (MSA context)"
PHPT=$(grep -rlE 'extends.*TestCase|use PHPUnit' --include='*.php' . 2>/dev/null | grep -vE '/vendor/' | wc -l | tr -d ' ')
JST=$(find . -type f \( -name '*.test.*' -o -name '*.spec.*' \) -not -path '*/node_modules/*' 2>/dev/null | wc -l | tr -d ' ')
PYT=$(grep -rlE 'def test_|import pytest' --include='*.py' . 2>/dev/null | wc -l | tr -d ' ')
echo "- PHPUnit test files: ${PHPT}"
echo "- JS/TS test/spec files: ${JST}"
echo "- pytest files: ${PYT}"
echo "- (Run the suite separately to get pass-rate & coverage — those are the real MSA numbers.)"
echo

echo "## How to use these"
echo "- **Defect count** for DPMO: prefer prod errors (Sentry) or labeled bugs (Linear); the bugfix-commit"
echo "  count here is a fallback proxy — label it 'Indicative'."
echo "- **Units/opportunities:** commits or deploys (change-based) or requests/sessions (Sentry/PostHog)."
echo "- **Churn + fix-concentration** feed the Pareto and fishbone in the Analyze phase."
