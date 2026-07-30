---
name: doctor-health-check
description: >
  Runs a full operational health check of a web app AND its ops surface, then (optionally)
  remediates. Layers the check the way SRE does — build gates → frontend (Playwright) →
  dependency audit → downstream integrations → schedulers/agents/cron — and fans the deep
  read-heavy work out across parallel subagents via a Workflow, each finding adversarially
  verified before it lands. Produces a severity-weighted scorecard (Critical→Low) with
  file:line evidence, then remediates with TDD on a PR branch (web-app) while keeping
  gitignored ops config (.claude/, alto-os/, cron, agents) strictly local. Enforces hard
  data-integrity rules: a Critical/negative finding is only reported after being verified
  firsthand against the authoritative source. Use when the user says "do a health check",
  "health check the app", "is everything up and running", "check the code/agents/cron/
  integrations", "doctor", or asks to audit operational health end-to-end. Scales from a
  quick pulse to a full multi-domain sweep + fix.
---

# Doctor — Operational Health Check

## Overview

A health check answers one question: **is this system actually healthy right now — code,
runtime, dependencies, integrations, and the jobs that keep it alive — and if not, where and
how bad?** It is not a fresh security audit (see `audit-orchestrator` for that) and not a
code review. It is a *liveness + readiness* sweep that ends in a ranked, evidence-backed
scorecard and, when asked, a verified fix.

**Methodology** (crawl-the-internet-then-apply, baked in here so you don't re-derive it):

- **Golden Signals** (SRE): latency, traffic, errors, saturation — the axes that actually
  predict user pain.
- **Liveness vs readiness**: *liveness* = "is the process up?" (shallow, no external deps).
  *readiness* = "can it serve real traffic?" (checks every downstream dependency: DB, cache,
  external APIs, OAuth, webhooks). Health = both, per layer.
- **Layer the check** so a failure localizes: build → runtime/frontend → dependencies →
  downstream integrations → schedulers/agents. A red layer doesn't invalidate the greens.

## When to use

"do a health check", "health check the app", "is everything running", "check the code +
agents + cron + integrations", "investigate backend/integrations", "doctor". Scale to the
ask: a quick pulse is Phases 0–1; the full sweep is Phases 0–5; add Phase 6 only when the
user wants fixes.

## Hard rules — Data Integrity (never pretend)

These override the urge to sound certain. Violations are the worst failure mode of a health
check — a confident wrong "X is broken / X doesn't exist".

1. **Verify every Critical / High / negative finding firsthand** before it enters the report
   or drives a fix. Open the actual file at the cited line; run the actual curl; query the
   actual live source with the right identifiers. A subagent's "CONFIRMED" is a lead, not
   proof — re-verify the severe ones yourself.
2. **"Not found locally" ≠ "doesn't exist."** A missing row in a local DB/sync/cache means
   the copy is stale. Re-check the upstream/live source before concluding absence.
3. **Cross-validate negatives** ("the cron is dead", "the count is 0") a second independent
   way (logs + `launchctl`, API + a second endpoint) before stating them settled.
4. **Say what you did NOT verify.** If you couldn't hit the live DB, write "did NOT query
   live Supabase — treat as unverified", never a plausible guess dressed as fact.
5. **Distinguish dev-mode transients from real bugs.** A first-paint `ERR_ABORTED`, a
   hot-reload hydration blip, or a `500` that clears on settle is often a dev artifact —
   reload/settle and re-check before flagging. (Real example: an embedded-map iframe that
   looked broken on first paint rendered fine once the iframe settled.)

## The pipeline

```
Phase 0  Discovery & scope      → stack, package manager, dev server, env presence, ops surface
Phase 1  Build gates            → typecheck, lint, test, build (record real exit codes)
Phase 2  Frontend (Playwright)  → render + console/CSP + network on the key pages
Phase 3  Dependencies           → audit (prod vs all), advisory ranges, safe overrides
Phase 4  Deep multi-domain scan → Workflow fan-out: codebase, api/auth, integrations, agents, cron
Phase 5  Scorecard              → severity-weighted, evidence-backed, what-needs-the-operator
Phase 6  Remediation (optional) → TDD, PR branch for app code, local-only for ops config
```

Run Phase 0 once and reuse it. Phases 1–3 you run inline (fast). Launch Phase 4 as a
**background Workflow** and do Phase 2 (Playwright) in the main thread while it runs — the
browser is a single shared resource, so it must NOT be driven from parallel subagents.

---

## Phase 0 — Discovery & scope

Lock `PROJECT_ROOT = cwd`. Never scan `node_modules/`, `.git/`, `.next/`, `dist/`, `build/`,
`vendor/`, `test-results/`, `output/`.

- **Stack**: package.json / composer.json / requirements.txt / Gemfile. Note framework + version.
- **Package manager**: presence of `pnpm-lock.yaml` vs `package-lock.json`. Deploys and local
  dev can differ (e.g. Vercel builds with pnpm, local uses npm) — audit with the one that ships.
- **Dev server**: start it in the background early so it's warm for Phase 2
  (`PORT=<p> npm run dev > dev.log 2>&1 &`); poll `curl -s -o /dev/null -w "%{http_code}"`
  until 200. Create the scratchpad dir first if the redirect target doesn't exist.
- **Env presence** (names only, never values): `grep -oE '^[A-Z_]+=' .env.local`. Watch for
  `export KEY=` forms — a naive `^[A-Z]` grep misses them and gives a false "0 keys".
- **Ops surface**: enumerate agents (`.claude/agents/`), cron (`.claude/cron/`, launchd
  plists in `~/Library/LaunchAgents/`, any `runtime/schedule.json`), and API routes
  (`find app/api -name route.ts`). Check `launchctl list | grep <prefix>` — the middle column
  is the **last exit status** (non-zero = a lead to chase in the logs, NOT a conclusion).

## Phase 1 — Build gates

Run each and **record the real exit code** — beware pipes masking it (`| grep` returns
grep's exit, not the command's; use `cmd 2>/dev/null; echo EXIT=$?` or `${PIPESTATUS[0]}`).

- typecheck (`tsc --noEmit`), lint, unit tests, and a production `build`. Don't run `build`
  while the dev server is compiling against the same `.next` — stop one first.
- Report each as ✓/✗ with counts. These are the liveness signal for the code itself.

## Phase 2 — Frontend (Playwright, main thread)

Load the Playwright MCP tools. For the homepage + 2–3 key pages (a data-driven page, an
auth surface):

- `browser_navigate` → `browser_console_messages(level: warning/error)` →
  `browser_network_requests(filter: "/api/|...")`. Screenshot when a visual claim matters.
- **Look for**: CSP violations ("Refused to..."), hydration mismatches, `4xx/5xx` on XHRs
  (e.g. a public page POSTing to an endpoint that 401s = a silently-broken integration),
  un-nonced inline scripts if the app uses a CSP nonce.
- Confirm the flagship feature actually renders (settle first — see data-integrity rule 5).
- **Independently reproduce** anything suspicious with `curl` (e.g. confirm the 401 and grep
  middleware for the allowlist) so the finding doesn't rest on the browser alone.

## Phase 3 — Dependencies

- Run the audit **prod-scoped** (`pnpm audit --prod` / `npm audit --omit=dev`) — that's what
  ships — and note the all-deps count separately (dev-only moderates are lower priority).
- Advisory ranges move: read the *exact* `Vulnerable`/`Patched` range per advisory before
  writing an override. Use **range-selective, same-major** overrides so you bump only the
  vulnerable versions without a breaking major jump
  (`"pkg@<X.Y.Z": "X.Y.Z"`). Re-install + re-audit + **build** to prove no breakage.

## Phase 4 — Deep multi-domain scan (Workflow)

Fan out read-heavy analysis across parallel subagents, then adversarially verify the severe
findings. Launch it in the **background** and do Phase 2 meanwhile. Use the bundled template
`health-check-workflow.template.js` (next to this file) as the script — adapt the `DOMAINS`
prompts + paths to the project. The shape:

- **Domains**: `codebase` (latent bugs, error handling, dead code, hook misuse), `api-backend`
  (auth-guard *consistency* across every route — the classic bug is an incomplete sweep that
  guards some siblings and leaves others open; input validation; error-swallowing),
  `integrations` (per-integration status: configured/degraded/broken, missing env guards,
  fail-open webhooks, wrong/legacy IDs, hardcoded secrets), `agents` (frontmatter valid?
  referenced scripts/paths exist? tool grants sufficient for the agent's job?),
  `cron-scheduling` (reconcile launchd ↔ schedule/registry ↔ real endpoints; read the logs).
- Each finder returns **structured JSON** (`{domain, score, summary, findings[]}` with
  `severity, title, location(file:line), evidence, remediation`) and is told: **report only
  what you verified by reading the file; cite file:line; omit speculation.**
- **Pipeline (not barrier)**: each domain's Critical/High findings get an independent
  **adversarial verify** agent ("try to refute this; default to `confirmed:false` if the
  evidence doesn't hold when you open the file") as soon as that domain's scan completes.
- Tell every agent what **recent PRs already fixed** so it flags regressions, not settled work.

Then **you re-verify** the survivors that are Critical/High (data-integrity rule 1) before they
reach the report.

## Phase 5 — Scorecard

Merge everything (inline gates + Playwright + workflow) into one report. De-duplicate
cross-domain overlaps (keep highest severity, list `sources`). Score each domain 0–100;
overall is severity-weighted (a Critical dominates). Format:

```
# 🏥 <App> — Health Check Report
Methodology: golden signals + liveness/readiness (layers).

## Scorecard
| Domain | Score | State |
| Build gates | .. | ✅/⚠️/🔴 |
| Frontend | .. | .. |
| Dependencies | .. | .. |
| Codebase | .. | .. |
| API / backend | .. | .. |
| Integrations | .. | .. |
| Agents | .. | .. |
| Cron / scheduling | .. | .. |
| **Overall** | .. | .. |

## 🔴 Critical  (file:line + one-line fix)
## 🔴 High
## 🟡 Medium (grouped)
## 🟢 Confirmed healthy
## Needs the operator (things you cannot do in-repo — with what you did/didn't verify)
```

Lead with what you verified live. Every finding carries `file:line` (or log path) evidence.

## Phase 6 — Remediation (only when asked)

Present the scorecard first and let the user pick scope (surgical vs everything). Then:

**Branch strategy** — never push to `main`; PR-only.
- **App code** → new branch off `origin/main` (`git switch -c fix/<x> origin/main`), so
  pre-existing routes are present and you don't inherit an unrelated open branch.
- Stash operator WIP first (`git stash push -m .. <paths>`) so the branch is clean; restore
  it at the end. Note pre-existing unrelated stashes and never touch them.
- **Gitignored ops config** (`.claude/agents`, `.claude/cron`, `alto-os/`) is **local-only** —
  edit in place, do NOT commit, and flag it. Verify tracked-vs-ignored per branch
  (`git check-ignore` reads the *working-tree* .gitignore, which a stash can change — some of
  these files may still be *tracked* from prior leaks; don't `git rm --cached`, just flag).

**TDD** (mandatory for auth/API logic): extend the existing regression test (e.g. a
`api-get-auth.test.ts` that asserts sensitive GETs return 401 unauthenticated) — add the new
routes (RED, watch them fail), then add the guard (GREEN). Pure helpers (allowlists, signature
checks, URL builders) get their own RED→GREEN unit test.

**Stage explicitly, never `git add -A`** — keep `alto-os/`, `.claude/`, screenshots, and
`.playwright-mcp/` out of the diff. Commit in logical chunks with clear messages.

**Verify each fix live** before claiming it: re-run the gate, and curl the endpoint
(Critical route → 401, the previously-broken public POST → 200, etc.). Re-run the full suite +
build after all edits.

**Risk discipline on live external surfaces** (phone/webhooks/payments): prefer a
zero-flow-risk fix that fully closes the severe hole (e.g. a host **allowlist** on a
credential-carrying fetch closes SSRF/credential-leak with no call-flow risk), and ship the
higher-risk "correct" fix (e.g. webhook signature enforcement) **opt-in / warn-first** behind
an env flag so an untested check can't drop live traffic. Document the switch.

## Common finding classes (pattern library)

- **Incomplete auth sweep**: middleware only gates mutating methods → sensitive **GET** routes
  rely on handler-level `requireAdmin`; a prior fix guarded some and missed siblings. Grep
  every sensitive GET for the guard.
- **Middleware-gated public endpoint**: a browser-fired endpoint (analytics CAPI, public form)
  sits behind the admin gate → silent 401s for real traffic. Catch it in Phase 2 (network tab).
- **Public webhook, no verification**: an intentionally-public webhook (Twilio/REX) with no
  signature check + a sink that forwards attacker-controlled input to a credentialed fetch =
  SSRF/credential-leak. Allowlist the sink host; add signature verify (opt-in strict).
- **Framework version footgun**: `NextResponse.redirect('/relative')` throws under Next 15.5 —
  needs `new URL(path, request.url)`.
- **Cron silently dead**: a launchd job whose interpreter lost macOS **Full-Disk-Access/TCC**
  (EPERM reading a `~/Desktop` path after a Homebrew upgrade). Durable fix: have **bash** open
  the file via `<` redirect and pipe to `jq` (bash keeps the grant; jq never opens the
  protected path), removing the python/FDA dependency. Add a wrapper-level failure alert —
  pre-agent failures otherwise fire zero notifications.
- **Agent can't do its job**: `.claude/agents/*.md` frontmatter `tools:` omits the MCP family
  the agent's whole purpose depends on → add `mcp__<server>__*` to `tools:`.
- **Secrets in logs**: OAuth callback `console.log(tokenJson)` / reflecting token JSON into a
  redirect URL. Log status only.

## Flags

- `--quick` → Phases 0–1 only (build pulse).
- `--code-only` → skip the dev server + Playwright; static + deps + workflow only.
- `--fix` → include Phase 6 (else stop at the scorecard and offer to remediate).

## Related skills

`systematic-debugging` (root-cause before fixing), `test-driven-development` (Phase 6 tests),
`audit-orchestrator` (deeper security/perf/a11y audit), `playwright` (browser driving).
