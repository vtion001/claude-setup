---
name: audit-orchestrator
description: >
  Runs ALL audit skills together as one pipeline and merges the results. Fans out eight
  parallel audit passes — ui-audit, ux-audit, security-audit, backend-audit, qa-audit,
  code-audit, a Lighthouse performance pass (lighthouse-mcp), and a supply-chain pass —
  against a running app and its codebase. The ux-audit pass includes psychology-informed
  design review (Gestalt/Fitts's/Jakob's/Miller's/Hick's laws, plus a dedicated gamification
  & reward-psychology pass for apps with points/badges/levels/leaderboards) cross-referenced
  against the project's own design-system manifest when one exists. Augmented by MCP scanners
  and production signal: aikido/endor/sonatype (SAST + SCA + safe-version), Sentry (real prod
  errors), Render (prod Postgres EXPLAIN + metrics + logs), serena (symbol graph),
  chrome-devtools (perf + a11y), ui-ux-pro-max (design-intelligence cross-check). De-duplicates
  overlapping findings, boosts prod-confirmed ones, files work items for the serious ones into
  whichever tracker backs the project (agshub-crud or waypoint-crud), and prints a single unified
  scorecard. Supports --quick, --code-only, --no-agshub, --pages, and --authorize flags. This skill should be used when the user
  asks to "run all audits", "full audit", "audit everything", "complete audit sweep",
  "run the audit orchestrator", "do a full audit and file issues", "ui + ux + security +
  perf audit", or wants every audit dimension covered in one shot with a combined report.
---

# Audit Orchestrator

One entry point that runs every audit in parallel and merges their output into a single
de-duplicated scorecard with tracker work items. It **invokes** the six audit skills, the
`lighthouse-mcp` server, the project's CRUD skill (`agshub-crud` or `waypoint-crud` — see Phase 1
step 4), and a set of scanner/observability MCPs (aikido, endor, sonatype, Sentry, Render, serena,
chrome-devtools) — it never re-implements them. Every MCP augmentation is optional and degrades
gracefully when a server is unavailable.

## Scope Lock (CRITICAL — inherited from code-audit)

**ALL operations MUST be scoped to the current working directory (`PROJECT_ROOT`).**

- Every `Glob`/`Grep`/`Read` and every dispatched Agent prompt must carry `PROJECT_ROOT`
  and operate only within it.
- **NEVER** scan `node_modules/`, `.git/`, `dist/`, `build/`, `.next/`, `vendor/`,
  `__pycache__/`, `audit-screenshots/`.
- **NEVER** scan parent directories, sibling repos, or global paths like `~/.claude/`.

## Pipeline

```
Phase 1  Discovery        → lock PROJECT_ROOT, detect stack, resolve localhost URL + routes,
                            resolve tracker workspace/project (agshub-crud or waypoint-crud),
                            auto-authenticate (once, shared by all passes)
Phase 2  Parallel fan-out → dispatch all 8 audit agents in ONE message (Agent tool)
Phase 3  Aggregate        → collect structured findings, de-duplicate cross-audit overlaps
Phase 4  File to tracker  → one work item per Critical/High finding, domain-tagged, deduped;
                            optional client notification if the project tracks an external client
Phase 5  Unified report   → merged scorecard: per-domain scores + ranked findings + issue table
```

`--code-only` drops Phase-1 auth and the runtime-only passes (2, 5, 7). `--no-agshub` skips
Phase 4. `--quick` tells each sub-audit to run automated checks only (skip Tier-2 AI judgment).

## Phase 1 — Discovery (run once, reuse for all agents)

Reuse `~/.claude/skills/code-audit/SKILL.md`'s discovery and authentication procedures —
do not duplicate them here:

1. **PROJECT_ROOT** = current working directory.
2. **Stack detection** — package.json / composer.json / requirements.txt / Gemfile, etc.
3. **Localhost URL + routes** — detect dev server URL (e.g. `http://localhost:5173`,
   Laravel `php artisan serve` on `:8000`) and enumerate routes. If no server is running and
   not `--code-only`, start it (`npm run dev`, `php artisan serve`) or instruct the user.
4. **Tracker workspace/project** — this app's own work is tracked in either `agshub-crud` or
   `waypoint-crud`; check the repo's own CLAUDE.md/README for which one, or ask if neither says.
   Resolve via that skill's `GET /workspaces` then `GET /workspaces/{ws}/projects`, matching by
   name against `PROJECT_ROOT`'s repo/app name. If the workspace is ambiguous (>1 match, or the
   token spans multiple workspaces) or no project matches, stop and ask — never guess (both
   skills share the same confirm-before-you-fire rule). Phase 4 below is written against
   `agshub-crud`'s endpoint shapes but applies unchanged against `waypoint-crud` — verified
   working end-to-end in practice: same work-items/labels/states resolve-then-POST shape, only
   the skill invoked and its auth/base-URL differ.
5. **Authentication** — run code-audit's 4-strategy auto-resolve (DB creds → seed creds →
   bypass → ask). Record any test users / bypasses created so Phase 5 can report cleanup.
   **If the login is an OAuth popup requiring live 2FA** (Google Workspace, Microsoft, etc.)
   and none of the 4 strategies produce usable credentials or a bypass, Playwright-driven
   passes (1 ui, 2 ux, 5 qa, 7 performance) cannot complete it in an isolated browser
   profile — this has recurred across multiple audit sessions on OAuth-gated apps. Fall back
   to `claude-in-chrome` against the user's already-authenticated Chrome session for all
   browser-driven passes rather than reporting them as blocked; note the substitution in
   Phase 5's Notes section.
6. **Runtime handles (optional, skip if absent)** — resolve the **Sentry** org/project
   (`find_organizations`/`find_projects`) and the **Render** service + Postgres instance
   (`list_services`/`list_postgres_instances`) for this app, so the security/qa/backend passes
   can pull real production signal. If neither is configured, continue without them.

Capture this once into a shared `DISCOVERY` context block and pass the relevant slice into
every Phase-2 agent prompt. Skip steps 3 & 5 under `--code-only`.

## Phase 2 — Parallel fan-out (the 8 passes)

Dispatch all applicable agents **in a single message** (`dispatching-parallel-agents`
pattern). Each agent gets: `PROJECT_ROOT`, the target URL + routes, the auth context, any
`--pages`/`--quick` flags, and the **mandatory structured-output contract** below. Each agent
invokes its named audit skill and returns findings — **not prose**.

| # | Agent label | Invokes | MCP augmentation (use if available; skip silently if not) |
|---|-------------|---------|-----------------------------------------------------------|
| 1 | ui          | `ui-audit`        | `chrome-devtools` a11y/contrast tooling for UI-state + visual checks |
| 2 | ux          | `ux-audit`        | `ui-ux-pro-max` design-intelligence cross-check (color/typography/style domains — secondary input only, project's own design-system manifest wins on conflict); auto-runs its Gamification & Reward Psychology pass when the app has points/badges/levels/leaderboards |
| 3 | security    | `security-audit`  | `aikido` (`aikido_full_scan`, `aikido_issues_list`) for SAST/secrets; **Sentry** `search_issues`/`analyze_issue_with_seer` to find security-relevant prod errors. Default `--passive`; active only if `--authorize` |
| 4 | backend     | `backend-audit`   | **Render**: `query_render_postgres` to `EXPLAIN ANALYZE` suspected slow queries, `get_metrics` (CPU/mem/latency), `list_logs` (error rates); **Sentry** for backend exceptions |
| 5 | qa          | `qa-audit`        | **Sentry** `search_issues` to correlate each route with real user-facing errors (a page Sentry shows erroring outranks a theoretical bug) |
| 6 | code        | `code-audit`      | **serena** symbol graph (`find_symbol`, `find_referencing_symbols`) for accurate dead-code / circular-dep / god-file detection. **Audit phases ONLY** — tell it NOT to file agshub work items or write its own report; the orchestrator owns Phases 4 & 5 |
| 7 | performance | `lighthouse-mcp` tools | Lighthouse per route: LCP, CLS, TBT + perf/SEO/best-practices/a11y scores. Fallback to `chrome-devtools` `lighthouse_audit` + `performance_start_trace` if lighthouse-mcp tools aren't loaded |
| 8 | supply-chain | `aikido` + `endor` + `sonatype` | `aikido_full_scan` + `endor` `check_dependency_for_vulnerabilities`/`security_review` for vulnerable & reachable deps; `sonatype` `getRecommendedComponentVersions` to attach a safe upgrade target to each finding |

**Graceful degradation:** every MCP augmentation is optional. If a server's tools aren't
loaded or it errors, the agent falls back to its skill's native Tier-0/Tier-1 behavior and
notes the degradation — a missing MCP never aborts a pass.

Under `--code-only`, run only agents 1, 3, 4, 6, 8 (static-capable) at Tier-0; skip the
Render/Sentry runtime augmentations.

### Structured-output contract (every agent MUST return this)

Return a JSON object:

```json
{
  "domain": "ui|ux|security|backend|qa|code|performance|supply-chain",
  "score": 0-100,
  "summary": "one-line health statement",
  "findings": [
    {
      "severity": "Critical|High|Medium|Low",
      "rule": "short stable identifier, e.g. 'a11y-contrast', 'n+1-query', 'missing-csp'",
      "title": "human title",
      "location": "path/to/file.ext:line  OR  /route",
      "evidence": "what was observed",
      "remediation": "specific fix",
      "agshub_candidate": true
    }
  ]
}
```

If an agent fails, capture the error and continue — a missing pass must not abort the sweep.

**An idle notification is not a result.** Background agents can report `idle`/`available` before
ever delivering their structured JSON — confirmed in practice: 3 of 8 passes in one real run went
idle first, findings arrived later or not at all until prompted. Track each pass as outstanding
until its actual JSON is in hand, not until it goes idle; if a pass has been idle for a while with
no JSON delivered, send it a direct check-in (`SendMessage`) asking for the contract output rather
than assuming silence means a clean pass or that the result is still coming on its own.

## Phase 3 — Aggregate & de-duplicate

Audits overlap by design: accessibility surfaces in **ux + code(Pass D) + performance**;
performance in **backend + code(Pass E) + performance**; component/CSS issues in **ui + code**.

1. Normalize every finding to `(normalized_domain, location, rule)`.
2. Merge duplicates into one entry, keeping the **highest** severity and a
   `sources: [...]` list naming which audits/scanners flagged it (signal strength). When
   aikido + endor + sonatype all flag the same dependency, that's one finding with three
   sources — agreement is confidence, not three tickets.
3. **Production-confirmed boost:** if a **Sentry** issue corroborates a finding (same
   route/error), bump it up one severity and tag `prod-confirmed` — observed beats theoretical.
4. Group surviving findings by domain and by severity for the report.

## Phase 4 — File to the project tracker (skip if `--no-agshub`)

For findings where `agshub_candidate == true` **and** `severity ∈ {Critical, High}` (deduped),
file into whichever CRUD skill Phase 1 step 4 resolved — `agshub-crud` or `waypoint-crud`. The
procedure below is written against agshub's shape; it applies unchanged against waypoint-crud
(same resolve-state → resolve-labels → dedup-by-title → POST work-item shape, just that skill's
own auth/base-URL and confirm-before-you-fire rules):

- Resolve the target project's default open state (`GET .../states`, pick the `unstarted`- or
  `backlog`-group state) and, if the project has them, domain labels matching
  `ui`/`ux`/`security`/`backend`/`qa`/`code`/`performance`/`supply-chain` (`GET .../labels`) —
  create any missing domain label rather than mis-mapping onto an unrelated one that happens to
  exist (e.g. don't fold `security` findings into a generic `backend` label if the project has no
  `security` label yet; add one).
- `GET .../work-items` first and skip any finding whose title already matches an open item —
  don't re-file the same finding on repeat runs.
- `POST .../work-items` per surviving finding: `title` prefixed with the domain label (e.g.
  `[security] Missing Content-Security-Policy`); `description` as **plain text** (both trackers
  render it unmodified — use line breaks/indentation, not markdown headings) containing evidence,
  location, and remediation, plus a `sources:` line when multiple audits flagged the same root
  cause; `priority` = `urgent` for Critical / `high` for High; `label_ids` set to the matched
  domain label(s) when one exists.
- Neither tracker has a work-item attachment path built for this flow — if code-audit captured
  before/after screenshots, reference their local file path in the description instead of
  embedding them.
- Do not open duplicate work items for merged findings.

### Client notification (only when the project tracks an external client, and only if asked)

Skip this whole subsection for internal-only projects. When the resolved tracker project has an
external client as a member (not just the operator) — check `GET .../members` — and the user's
invocation asks for the client to be looped in, extend Phase 4/5 with:

1. Post a plain-text summary to the project's own activity/posts feed (what ran, headline
   findings, what got filed) — this is the durable record even if the client never checks it live.
2. If the tracker has a shared chat channel the client can actually see (e.g. waypoint's
   workspace-level `chat`), post a short message there addressed to them directly — a few
   sentences, not the full report; point them at the filed items for detail.
3. Send a brief external heads-up through whichever messaging skill this workspace uses for that
   client (e.g. `wacli-msg` for WhatsApp) — voice-matched and gated through that skill's own
   send-approval, never a raw auto-send. Keep it short: this is a notification that something ran
   and where to look, not a restatement of the findings.

This is additive, not a replacement for Phase 5's own report to the user — do both.

## Phase 5 — Unified scorecard

Print one markdown report:

```markdown
# Audit Orchestrator — Unified Report
Target: <url>   Project: <root>   Mode: <full|code-only|quick>

## Scorecard
| Domain | Score | Critical | High | Medium | Low |
|--------|-------|----------|------|--------|-----|
| UI | … | … | … | … | … |
| UX | … |
| Security | … |
| Backend | … |
| QA | … |
| Code | … |
| Performance | … |
| Supply-chain | … |
| **Overall** | **…** | … | … | … | … |

## Top Findings (by severity)
- **[Critical] …** — location — sources: [ui, code] — fix: …
- **[High] …** — …

## Work Items Filed
| Item | Domain | Severity | Title |
|------|--------|----------|-------|

## Notes
- Failed/skipped passes (with reason)
- Auth cleanup performed (test users removed, bypasses reverted)
```

Overall score = severity-weighted roll-up across domains (Critical findings dominate).

## Flags

| Flag | Effect |
|------|--------|
| `--quick` | each sub-audit runs automated checks only (skips Tier-2 AI judgment) |
| `--code-only` | static analysis only; drops auth + runtime passes (2, 5, 7) |
| `--no-agshub` | produce the report but file no tracker work items (agshub or waypoint) |
| `--pages <routes>` | restrict runtime passes to the given routes |
| `--authorize` | allow active/intrusive security testing in pass 3 (default is passive) |
