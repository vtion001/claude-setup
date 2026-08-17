---
name: ship-loop
description: Use when shipping a feature or fix end-to-end in any project — plan, build with TDD, parallel security/QA/UX review, a quality gate with bounded retries, a confirmed deploy, and a memory write. Triggers on "ship this", "ship-loop", "run the full loop", "build and ship X", "do the full dev loop".
---

# Ship Loop

A global, stack-agnostic feature-to-deploy loop. It doesn't reimplement anything — it sequences skills and subagents you already have, and enforces the gates between stages. Built from Anthropic's five agent patterns (prompt chaining, parallelization, evaluator-optimizer) rather than an ad hoc process — see `~/.claude/agent-memory/` notes and the design discussion for why each stage is shaped the way it is.

## Stages

### 1. DETECT
Identify the stack and this project's own quality bar before doing anything else:
- Read `package.json` / `composer.json` / `go.mod` / etc. to identify language, framework, test runner.
- Read the project's own `CLAUDE.md` if one exists — it may define its own quality gates (e.g. BOB-AGS's Six Sigma table). Project-specific gates always override the defaults below.
- If no project CLAUDE.md exists, use the defaults in GATE below.

### 2. PLAN
Skip this stage if a plan already exists for the requested work (e.g. the user already brainstormed this in-session).
- Invoke `brainstorming` to clarify scope, then `writing-plans` to produce the implementation plan.
- Don't proceed to BUILD without a plan the user has approved — this is a hard gate, not a formality.

**Website-build template.** When the requested work is a new marketing/portfolio-style website
(not an existing project's feature/fix), check `~/Desktop/REPOSITORY/msrose-website/` first —
it's a working Next.js 16 + React 19 + Tailwind + GSAP codebase (originally built for M1217 Media
Lab, kept as a standalone reference) with a documented set of reusable, content-agnostic motion
components: scroll-reveal, canvas pixel-mosaic image reveal, SPA-style page transitions with a
branded preloader, and a hover text-scramble effect — see its `README.md` for the full component
table, the design-token pattern (swap Tailwind theme + fonts, keep the components), and two
known GSAP/React-effect gotchas (`usePrefersReducedMotion`'s stale-first-render race,
StrictMode's dev-only double-invoke) worth knowing before extending any of them further. Bring
this up as an option during brainstorming rather than assuming it — a from-scratch build is
sometimes the right call — and if used, copy only the pieces the new site actually needs rather
than the whole tree.

### 3. BUILD
- Delegate to the `syntax` subagent with the approved plan as its task.
- Keep this a single subagent, not split further — planning/implementation/testing share too much context to fragment across agents (this is deliberate, not an oversight: see Anthropic's guidance on when multi-agent split helps vs. hurts).
- On a GATE retry, pass `syntax` the condensed failure summary from step 5, not raw logs.

### 4. REVIEW — parallel fan-out
Dispatch these three in a single message so they run concurrently (they're read-only against the diff and don't depend on each other):
- `sentinal` — security review of the diff
- `verity` — QA/regression review of the diff
- `aesthetica` — UI/UX review, only if the diff touches frontend surface (it self-reports "not applicable" otherwise)

Wait for all three before moving to GATE. (A `SubagentStop` hook logs each one's completion for the audit trail — you don't need to do this yourself.)

### 5. GATE — evaluator-optimizer loop
Check the three review reports plus the project's own test suite against the quality bar:
- **Default bar** (no project-specific gates found): tests 100% pass, 0 high/critical security findings, 0 accessibility blockers, build succeeds.
- **Project-specific bar**: use whatever the project's own CLAUDE.md defines (e.g. BOB-AGS: PHPUnit 100%, composer audit 0 high/critical, security scan 0 findings, `npm run build` succeeds).

**If it fails**: condense the failures into a short, specific summary (not raw logs — see the 12-factor-agents "compact errors" principle) and loop back to BUILD. Cap at 3 retries total; on the 3rd failure, stop and hand the findings to the user instead of retrying again.

**If it passes**: write the gate marker so the deploy hook allows SHIP to proceed:

```powershell
$cwd = (Get-Location).Path
$md5 = [System.Security.Cryptography.MD5]::Create()
$hash = [System.BitConverter]::ToString($md5.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($cwd))) -replace '-', ''
New-Item -ItemType File -Path (Join-Path $env:TEMP "ship-loop-gate-$hash.marker") -Force | Out-Null
```

### 6. SHIP
- Summarize what's about to be deployed and ask the user to explicitly confirm — this stays a human-in-the-loop step regardless of how clean the gate result is; deploys are irreversible/outward-facing and are never auto-approved.
- Only after confirmation, delegate to `flow` to execute the deploy.
- A `PreToolUse` hook independently blocks deploy-shaped Bash commands if no fresh gate marker exists (covers the case where SHIP is reached without going through GATE) — this is a backstop, not the primary control.

### 7. LEARN
- `sentinal`, `verity`, and `flow` already maintain their own project-scoped memory (`memory: project` in their frontmatter) and update it as part of their own instructions — nothing extra needed here.
- If anything happened in this run that's worth a *user-level* memory (a process gap, a recurring cross-project pattern, a decision the user made that should stick), write it using the existing global memory conventions (`~/.claude/projects/*/memory/`, frontmatter + `MEMORY.md` index) — but only if it's genuinely new, don't write a memory entry every single run.

## When NOT to use this
For a quick, targeted change that doesn't need review/gate/deploy, just do the work directly — this loop is for shipping, not for every edit. If you're only fixing one thing and staying in conversation with the user, the main thread is faster and cheaper than spinning up the full loop (see the multi-agent-systems guidance on cost: parallel review is ~3-10x tokens vs. single-agent for the same work — worth it here because the specialization is real, but don't invoke it for one-line fixes).
