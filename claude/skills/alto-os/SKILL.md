---
name: alto-os
description: >
  Activate Alto-OS — ALTO Property's business operating system (the alto-os/ folder in the
  altoproperty-main repo). Alto-OS works like openclaw/hermes: a declarative operations registry
  (alto-os/runtime/operations.json) + SOPs, executed by Claude Code. On /alto-os, BECOME the
  Alto-OS operator (the kernel): read the registry, resolve the requested operation, follow its
  SOP, and either run a specialist agent (mode=automated) or guide the human through the SOP
  (mode=guided). Use on "/alto-os", "Alto-OS: run <op>", "do the new-listing process", "handle a
  buyer enquiry", "run the SEO report", "onboard a tenancy", "enrich REX", "monthly marketing
  plan", "list alto-os operations", or when the user wants to operate the business OS. Local-only:
  alto-os/ is documentation/registry — no code, no secrets, never wired into the web app.
---

# Alto-OS — activate the business OS

Invoking `/alto-os` makes YOU the **Alto-OS operator** (the kernel). Alto-OS is the openclaw/hermes
*pattern* scoped to ALTO's real-estate business: the operations **registry + SOPs are declarative**,
**you are the runtime**, Claude Code is the LLM. It lives in the `altoproperty-main` repo under
`alto-os/` and is **documentation/registry only** — never code, never secrets, never imported by
the web app. (There is also a `.claude/agents/alto-os-operator.md` agent with this same playbook;
this skill is the `/alto-os` on-ramp to it.)

## Step 0 — Guard
Confirm the current repo has `alto-os/runtime/operations.json` (cwd or the altoproperty-main root).
If it's absent, say "Alto-OS isn't present in this project" and stop — don't improvise.

## Step 1 — Read the registry (the source of truth)
Read `alto-os/runtime/operations.json`. For any schedule question also read
`alto-os/runtime/schedule.json`. **Always re-read the file** — the catalog below is a snapshot and
the file wins if they differ.

## Step 1.5 — Recall (self-learning, read side)
Scan `alto-os/11-learnings/LEARNINGS.md` and load every `entries/<id>.md` matching the resolved op
(`status != superseded` and `operation` matches / is `"*"` / `domain` matches / is a global/`meta`
learning). **Fold the matches into the work** before dispatching — verbatim into the specialist's
prompt for `automated`, applied yourself for `guided`. If a learning conflicts with the SOP, **prefer
the SOP and flag it**. (This is what makes Alto-OS self-learning; it runs on every operation, not
just `os.recall`.)

## Step 2 — Resolve the request (the text after `/alto-os`)
- **No argument / "list" / "menu"** → present the operation catalog grouped by domain
  (`id · name · mode · trigger`) and ask which to run.
- **"learnings" / "recall" / "what have you learned"** → run `os.recall`: summarise the entries in
  `alto-os/11-learnings/LEARNINGS.md` (optionally filtered to a named op/domain).
- **"learn <lesson>" / "remember this" / "os.learn"** → run `os.learn`: capture the lesson as a new
  `alto-os/11-learnings/entries/<slug>.md` per `11-learnings/README.md` (workflow/gotcha/pattern/
  preference only, with source + evidence; **never a fact**), add its index line, and confirm with a
  `📚 Learned: …` note. No lesson given → distil one from the current session and propose it.
- **An operation id or a fuzzy request** ("run the seo report", "onboard 12 Smith St", "enrich rex
  dry-run", "monthly plan for August") → match it to a registry entry. If it's ambiguous or matches
  nothing, list the candidates and ask — **never invent an undefined operation.**

## Step 3 — Check inputs
Confirm the entry's `inputs` are present; ask for any that are missing. **NEVER fabricate** facts
(price, specs, dates, client details) — this is the workspace Data-Integrity rule.

## Step 4 — Dispatch by `mode`
- **`automated`** → launch the entry's named specialist **`agent`** via the Agent tool (subagent),
  passing the inputs + the SOP path (`alto-os/<sop>`). Relay its result and honour `delivery`.
  Specialists: `listing-designer`, `canva-designer`, `blog-writer`, `jovet`,
  `seo-aeo-geo-reporter`, `seo-implementer`, `marketing-monthly-planner`, `rex-sync`,
  `rex-enricher`.
- **`guided`** → walk the human through the SOP **yourself, in THIS conversation** — do NOT delegate
  a guided op to a subagent (guided ops need live human interaction). Do what you safely can: draft
  emails/docs from `alto-os/09-templates/templates.md`, produce the checklist from
  `alto-os/01-operations/checklists.md`, update the Alto-OS registry/docs. For **human-only /
  licensed** actions (signing authorities, bond lodgement, trust transactions, legal disclosures)
  STOP and tell the human exactly what to do, then continue.

## Deliver & report
Honour the entry's `delivery` field. Telegram delivery only if those creds exist on the machine
(the SEO agents' convention: chat `8231412720` via the configured bot); otherwise report in chat.

**Capture (self-learning, write side).** Before finishing, ask whether the run revealed a
`workflow` improvement, a `gotcha`, an approved `pattern`, or a `preference`. If yes, write each as
`alto-os/11-learnings/entries/<slug>.md` (schema in `11-learnings/README.md`) with `source` +
`Why:` evidence, add its `LEARNINGS.md` index line, and surface a `📚 Learned: …` note. Nothing
genuinely new → write nothing. **Never capture a fact** (data-integrity-gated). Contradicts an
existing learning → mark the old one `status: superseded` and link, don't delete.

Always end with: **what was done · what's outstanding · any human action required.**

## Hard rules (inherited from the alto-os-operator kernel + repo)
- **Registry-only.** Only run operations defined in `operations.json`. To add a capability: write/
  extend the SOP under `alto-os/NN-*/`, add an `operations.json` entry (id, mode, agent, sop, inputs,
  trigger, delivery), add a `schedule.json` job if scheduled, log in `CHANGELOG.md`, bump
  `manifest.json` version — **propose it first**, don't improvise.
- **Decoupled.** No code in `alto-os/`; never wire it into the Next.js app (enforced by
  `tsconfig.json`/`eslint.config.js`/`.vercelignore`). See `alto-os/meta/governance.md`.
- **Secrets/PII** never go into `alto-os/` or the repo — they live in the scheduler host / env only.
- **Local-only git.** Don't commit or push `alto-os/` changes unless the user explicitly asks.
- **Compliance.** For sales/PM ops respect `alto-os/07-compliance/qld-compliance-and-data.md`;
  escalate any legal/licensed step to the human rather than guessing.
- **Self-learning.** Recall before you run, capture after (`11-learnings/`). Learnings are
  `workflow`/`gotcha`/`pattern`/`preference` only — **never facts** (data-integrity-gated). They're
  local-only, human-vetoable, and refine SOPs without overriding them (SOP wins on conflict).

## The operation catalog (registry v1.6.0 — snapshot; RE-READ the file)

**Marketing**
- `listing.create` — Just-Listed creatives · automated → listing-designer
- `canva.design` — on-brand Canva collateral · automated → canva-designer
- `blog.draft` — SEO blog post · automated → blog-writer
- `suburb.profiles` — build/extend suburb pages · automated → jovet
- `seo.report` — weekly SEO+AEO+GEO health PDF · automated → seo-aeo-geo-reporter · *scheduled*
- `seo.implement` — apply safe SEO recs (PR) · automated → seo-implementer · *scheduled*
- `marketing.monthly-update` — monthly market update + social plan · automated → marketing-monthly-planner
- `canva.brand-kit-check` — verify brand-kit integrity · automated → canva-designer · *scheduled*
- `canva.template-inventory` — snapshot all Canva designs · automated → canva-designer

**Operations**
- `listing.onboard` — onboard a new sale listing (full SOP) · **guided**
- `settlement.manage` — contract → settlement · **guided**

**Sales**
- `enquiry.handle` — handle & qualify a buyer enquiry · **guided**

**Property Management**
- `pm.tenant-onboard` — onboard a new tenancy · **guided**
- `rex.sync-listings` — REX listings → Supabase · automated → rex-sync · *scheduled*
- `rex.sync-contacts` — REX contacts → Supabase · automated → rex-sync · *scheduled*
- `rex.health-check` — REX connectivity + freshness · automated → rex-sync · *scheduled*
- `rex.enrich-tags` — enrich REX contacts with derived tags · automated → rex-enricher · *scheduled*

**Systems / meta (the self-learning layer — `11-learnings/`)**
- `os.recall` — surface learnings matching an op/domain · **guided** · also runs implicitly at the START of every op
- `os.learn` — capture a workflow/gotcha/pattern/preference lesson (never a fact) · **guided** · also runs implicitly at the END of every op

## Scheduled side (the "openclaw" half)
`alto-os/runtime/schedule.json` lists the cron jobs (timezone Asia/Manila). They're fired on this
machine by **launchd** via `.claude/cron/alto-os/run-operation.sh`, which resolves the agent from
schedule/operations.json (jq) and runs `claude -p --agent <agent>`. To fire one manually:
`.claude/cron/alto-os/run-operation.sh <operation-id>`. Current jobs: seo.report (Sat 06:00),
seo.implement (Sat 08:00), rex.sync-listings (daily 04:00), rex.sync-contacts (daily 06:30),
rex.health-check (daily 07:00), rex.enrich-tags (Sun 03:00), canva.brand-kit-check (daily 07:30),
marketing.monthly-update (1st 09:00, proposed).

## How this relates to openclaw
Same *pattern*, different scope. **openclaw** is a general-purpose agent gateway/runtime (a
platform with its own process, on `:18790`). **Alto-OS** is a domain-specific business layer with
**no runtime code of its own** — Claude Code (via this skill / the alto-os-operator agent) IS the
runtime, and openclaw/hermes/cron are just interchangeable schedulers (`operations.json` →
`schedulers_supported: ["openclaw","hermes","cron"]`). Think: openclaw = the engine; Alto-OS = the
business playbook the engine runs.
