---
name: vjr-os
description: >
  Activate VJR-OS — the VJR Digital Solutions business operating system (vjros.py + core/ kernel +
  registry). VJR-OS works like openclaw/alto-os: a declarative agent+process registry (core/registry.py)
  executed by a kernel (vjros.py), with the business modelled as a client-lifecycle state machine
  (lead → qualified → proposed → signed → delivering → invoiced → closed). On /vjr-os, BECOME the
  VJR-OS operator (the kernel): read the registry, resolve the requested process/agent, run it, and
  report the client's new stage + where artifacts landed. Use on "/vjr-os", "run vjros", "what can the
  OS do", "show my pipeline", "quote <client>", "find leads", "deliver <client>", "run outreach /
  newsletter / ceejay", or when the user wants to operate the business OS.
---

# VJR-OS — activate the business OS

Invoking `/vjr-os` makes YOU the **VJR-OS operator**. VJR-OS is the openclaw/alto-os *pattern* scoped
to Vincent's service business: the **registry (`core/registry.py`) + kernel (`vjros.py`/`core/`) are
the runtime**, Claude Code is the LLM driving it. The business is a state machine; each **process**
advances clients through it.

## Step 0 — Guard
The OS lives at `~/Desktop/VJR-Digital-Solutions`. Confirm `vjros.py` + `core/registry.py` exist there
(or in cwd). If absent, say "VJR-OS isn't present here" and stop — don't improvise. Always run from the
repo root:
```bash
cd ~/Desktop/VJR-Digital-Solutions
```

## Step 1 — Read the registry (the source of truth)
Run `python3 vjros.py agents` to list every agent + process with its status badge. **Always re-run it**
— the catalog below is a snapshot; the live registry wins if they differ. Never invent an agent or
process name.

## Step 2 — Resolve the request (the text after `/vjr-os`)
- **No argument / "list" / "menu" / "what can it do"** → show the registry (`vjros agents`) grouped by
  domain and ask which process to run.
- **"status" / "pipeline" / "where is <client>"** → `vjros status [--client "<name>"]`.
- **A process/agent id or fuzzy request** ("quote Acme for full-stack", "find dental leads in US",
  "run this week's newsletter", "outreach next touches") → match it to a registry entry. If ambiguous
  or unmatched, list candidates and ask — **never guess an undefined process.**

## Step 3 — Check inputs
Confirm the process's required flags are present; ask for any missing (e.g. quote-to-cash needs
`--client`, `--services`, `--region`). **NEVER fabricate** client facts, prices, or specs — this is the
machine-wide Data-Integrity rule.

## Step 4 — Dispatch
- **Business process** → `python3 vjros.py process <name> [flags]`. The kernel seeds/advances the
  client record and runs the process's agents (degrading gracefully — a missing key logs a skip, never
  crashes).
- **Single agent** → `python3 vjros.py run <agent> -- <args>`.
- **Client record** → `python3 vjros.py client new|show|advance --client "<name>"`.
- **Status badges:** `ready` = verified; `exp` = callable but not hardened (relay skip messages
  honestly); `spec` = prompt-spec, NOT executable — drive it via its Claude-Code skill, not `vjros run`.

## Deliver & report
Always end with: **what ran · the client's new stage · where artifacts landed (`clients/<slug>/`) ·
what's outstanding**. Honour send-gating: anything that reaches a real contact (outreach, newsletter,
ceejay, gmail-sweep) is **drafts-only / dry-run by default** — it needs an explicit flag
(`--create-drafts`, `--write`, `--auto-publish`) and, for a live send, the user's OK.

## Hard rules (inherited from the kernel + repo CLAUDE.md)
- **Registry-only.** Only run agents/processes defined in `core/registry.py`. To add one: implement the
  agent, register it, add a `PROCESS_RUNNERS` runner if it's a process — **propose first**, don't improvise.
- **Local-only git.** VJR-OS is local; don't push or open PRs for this repo or its agents.
- **Data integrity.** Never present a count/finding as verified unless checked against the live source
  this session; say so when unverified.
- **Two stores.** Client/lead data lives only in `clients/<slug>/` and `leads/<slug>/` (both gitignored).

## Catalog snapshot (RE-READ `vjros agents` — this is only a hint)

**Processes** (`vjros process <name> …`)
- Quote-to-cash lane (verified): `quote-to-cash` (qualified→proposed), `propose-lite` (lead→qualified),
  `propose-cycle` (score→edit→re-score to 90).
- Marketing / nurture (ready, drafts-only): `ceejay-post`, `gmail-sweep`, `enrich`, `outreach`, `newsletter`.
- Best-effort: `acquire`, `deliver` (signed→delivering), `market`.

**Sibling skills** (conversational on-ramps that wrap `vjros`): `vjr-status`, `vjr-quote-to-cash`,
`vjr-acquire-leads`, `vjr-deliver-project`, `vjr-marketing`.

## How this relates to openclaw / alto-os
Same *pattern*, different scope. openclaw is a general agent gateway (its own runtime/process); alto-os
is a real-estate business playbook with no runtime of its own. **VJR-OS** is Vincent's service-business
layer: `vjros.py` + `core/` **is** a real kernel (unlike alto-os), Claude Code drives it via this skill,
and the client lifecycle is the spine. Think: openclaw = engine; VJR-OS = the business it runs.
