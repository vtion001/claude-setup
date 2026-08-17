---
name: self-improvement
description: >
  Captures learnings, errors, and corrections for continuous improvement, and
  (on OpenClaw) maintains active proactive state. Use when: a command/operation
  fails unexpectedly, the user corrects Claude ("No, that's wrong..."), the user
  requests a capability that doesn't exist, an external API/tool fails, knowledge
  turns out outdated, or a better approach is found for a recurring task. Also
  review before major tasks. Merged 2026-08-14 from self-improving-agent (file-log
  mechanism) and self-improving-proactive-agent (OpenClaw workspace-state
  mechanism) — both modes kept, not one dropped in favor of the other.
---

# Self-Improvement

Two mechanisms, pick by environment — both log real corrections/learnings, neither
infers a durable rule from silence or vibes alone.

## Mode A — file-log (any agent: Claude Code, Codex, Copilot)

Log to `.learnings/{LEARNINGS,ERRORS,FEATURE_REQUESTS}.md` in the project/workspace
root (create with the standard headers if missing, never overwrite existing files).
Promote broadly-applicable entries to `CLAUDE.md`/`AGENTS.md`/
`.github/copilot-instructions.md`. Full entry format, ID scheme, promotion rules,
and hook-integration details: see `references/file-log-mode.md` in this skill's
directory (ported from the original `self-improving-agent` skill's SKILL.md).

## Mode B — OpenClaw workspace state

`~/self-improving/` (memory.md, corrections.md, index.md, per-project/domain
learnings) + `~/proactivity/` (session-state.md, heartbeat.md, patterns.md).
Route durable lessons to `~/self-improving/`, active task state to
`~/proactivity/session-state.md`, volatile breadcrumbs to
`~/proactivity/memory/working-buffer.md`. Promotion/decay rules (3x/7-day →
HOT, 30-day unused → WARM, 90-day → archive), hard boundaries (never message/
spend/delete/commit without approval), and the full heartbeat spec: see
`references/openclaw-mode.md` in this skill's directory (ported from the
original `self-improving-proactive-agent` skill's SKILL.md).

## Which mode applies

Plain Claude Code / Codex / Copilot session → Mode A. Running inside an OpenClaw
workspace (workspace-injected `AGENTS.md`/`SOUL.md`/`TOOLS.md` present) → Mode B.
If both signals are present, prefer Mode B (it's the superset — it already routes
"tool gotchas" style learnings to `TOOLS.md`, which is Mode A's own promotion target
under a different name).
