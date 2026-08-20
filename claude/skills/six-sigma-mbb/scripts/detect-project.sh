#!/usr/bin/env bash
# detect-project.sh — identify stack, test setup, CI, and existing audit reports for the target app.
# Usage: detect-project.sh [TARGET_DIR]   (defaults to current directory)
# Read-only. Prints a small markdown report to stdout. Adapted from backend-audit/scripts/detect-stack.sh.
# NOT -e: all best-effort detection — a failing check must not abort the script.
set -uo pipefail

DIR="${1:-.}"
cd "$DIR" || { echo "cannot cd to $DIR"; exit 1; }

have() { command -v "$1" >/dev/null 2>&1; }
exists() { [ -e "$1" ] && echo "$1"; }
scan() { if have rg; then rg -l -i --no-messages -g '!vendor' -g '!node_modules' -g '!.git' -g '!build' -g '!builds' -g '!writable' -g '!dist' -e "$1" . 2>/dev/null | head -1; \
         else grep -rEIl -i --exclude-dir=node_modules --exclude-dir=vendor --exclude-dir=.git --exclude-dir=build --exclude-dir=dist -e "$1" . 2>/dev/null | head -1; fi; }

echo "# Project detection — $DIR"
echo

echo "## Frameworks / languages"
# Monorepo-aware: find manifests at root AND in immediate subdirs (e.g. backend/, frontend/),
# excluding vendored deps. -maxdepth 3 covers root + one nesting level for typical layouts.
findmani() { find . -maxdepth 3 -name "$1" -not -path '*/vendor/*' -not -path '*/node_modules/*' 2>/dev/null; }
gq() { grep -qiE "$2" "$1" 2>/dev/null; }
for cj in $(findmani composer.json); do
  gq "$cj" 'codeigniter4'      && echo "- CodeIgniter 4 (PHP) — $cj"
  gq "$cj" 'laravel/framework' && echo "- Laravel (PHP) — $cj"
  gq "$cj" 'symfony/'          && echo "- Symfony (PHP) — $cj"
done
for pj in $(findmani package.json); do
  gq "$pj" '"react"'                          && echo "- React (frontend) — $pj"
  gq "$pj" '"(next|vue|svelte|@angular/core)"' && echo "- JS framework (Next/Vue/Svelte/Angular) — $pj"
  gq "$pj" '"(express|fastify|@nestjs/core|koa)"' && echo "- Node backend (Express/Fastify/Nest/Koa) — $pj"
done
for req in $(findmani requirements.txt) $(findmani pyproject.toml); do
  gq "$req" 'fastapi|django|flask' && echo "- Python web (FastAPI/Django/Flask) — $req"
done
for gf in $(findmani Gemfile); do gq "$gf" 'rails' && echo "- Rails (Ruby) — $gf"; done
for gm in $(findmani go.mod); do echo "- Go module — $gm"; done
echo

echo "## Test setup (Measurement system)"
exists phpunit.dist.xml >/dev/null || exists phpunit.xml >/dev/null || exists phpunit.xml.dist >/dev/null && echo "- PHPUnit config present"
[ -n "$(scan 'extends.*TestCase|use PHPUnit')" ] && echo "- PHPUnit tests present"
exists vitest.config.ts >/dev/null || exists vitest.config.js >/dev/null && echo "- Vitest config present"
exists jest.config.js >/dev/null || exists jest.config.ts >/dev/null && echo "- Jest config present"
exists playwright.config.ts >/dev/null || exists playwright.config.js >/dev/null && echo "- Playwright E2E config present"
[ -n "$(scan 'def test_|import pytest')" ] && echo "- pytest tests present"
for d in tests test e2e __tests__ spec; do exists "$d" >/dev/null && echo "- test dir: $d/"; done
echo

echo "## Coverage signals"
exists coverage >/dev/null && echo "- coverage/ dir present"
exists clover.xml >/dev/null && echo "- clover.xml (PHP coverage)"
exists coverage/lcov.info >/dev/null && echo "- lcov.info (JS coverage)"
echo

echo "## CI/CD (Control)"
exists .github/workflows >/dev/null && echo "- GitHub Actions: $(ls .github/workflows 2>/dev/null | tr '\n' ' ')"
exists .gitlab-ci.yml >/dev/null && echo "- GitLab CI"
exists .circleci/config.yml >/dev/null && echo "- CircleCI"
exists Jenkinsfile >/dev/null && echo "- Jenkins"
[ -z "$(exists .github/workflows)$(exists .gitlab-ci.yml)$(exists .circleci/config.yml)$(exists Jenkinsfile)" ] && echo "- (no CI config found — Control-phase gap)"
echo

echo "## Existing audit reports (Measurement inputs to ingest)"
found_audit=""
for p in backend-audit code-audit security-audit ui-audit ux-audit six-sigma; do
  for hit in $(find . -type d -name "$p" -not -path '*/node_modules/*' -not -path '*/vendor/*' 2>/dev/null); do
    echo "- $hit/"; found_audit=1
  done
done
# also catch loose scorecard/report markdown
find . -type f \( -iname '*-scorecard.md' -o -iname '*-audit-report.md' \) -not -path '*/node_modules/*' -not -path '*/vendor/*' 2>/dev/null | while read -r f; do echo "- report: $f"; done
[ -z "$found_audit" ] && echo "  (run /backend-audit, /code-audit etc. first for a richer baseline)"
echo

echo "## Git"
if exists .git >/dev/null; then
  echo "- git repo · branch: $(git rev-parse --abbrev-ref HEAD 2>/dev/null) · commits: $(git rev-list --count HEAD 2>/dev/null)"
else
  echo "- (not a git repo — defect-metrics.sh git signals unavailable)"
fi
echo
echo "Detection complete. Feed this into Define/Measure; then run scripts/defect-metrics.sh."
