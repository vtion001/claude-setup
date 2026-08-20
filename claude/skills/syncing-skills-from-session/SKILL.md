---
name: syncing-skills-from-session
description: >
  Absorb this session's real workflow into the skill(s) or agent file(s) it actually touched —
  finding the closest/related file automatically from session context, editing it in place rather
  than appending, and pruning it back down if it's grown bloated. Use on "update the skills based
  on this session", "sync this into the corresponding skill", "make sure the skill absorbs what we
  did", "can you update the skill for X", or any request to fold session learnings back into
  SKILL.md/agent files rather than leaving them stuck in this one conversation. Global — works the
  same in any project, not just one repo.
---

# Syncing Skills From Session

A session's real work — a new gotcha, a corrected assumption, a command that finally worked, a
decision framework that needed a new branch — is only useful once if it stays in the transcript.
This skill turns it into a durable edit to the actual skill(s)/agent(s) that did the work, without
letting repeated updates bloat those files over time. See [[skill-update-hygiene]] for the pruning
discipline this skill applies on every pass — read that memory (or the relevant durable-memory
equivalent) before editing anything.

## Guardrails — read before touching anything

This skill edits **documentation about a mechanism, never the mechanism itself.** Non-negotiable:

- **Never edit live configuration.** `.env`/`.env.*`, `~/.zshrc` or other shell rc files,
  `~/.claude/settings.json`/`settings.local.json`, MCP server registration (`.mcp.json`, `claude mcp
  add` output, connector config), credentials/token files (`credentials*.json`, `token*.json`,
  keyrings) — any file a SKILL.md merely *documents the location of*. If a session's real fix
  involved changing one of those, that already happened earlier in the session as its own explicit
  action; this skill only updates the documentation to describe the new state, never the config
  itself.
- **Never touch a skill's bundled scripts, hooks, assets, or `references/` files as part of a prune
  pass.** Those are code and templates, not prose — the pruning discipline (compress narrative,
  delete obsolete text, collapse duplication) applies to the SKILL.md body only, never to
  `.py`/`.sh`/`.js` files, template/CSS assets, or packaging metadata (`_meta.json`,
  `.clawhub/origin.json`). If the session genuinely changed a script's behavior and that's part of
  what needs absorbing, treat it as a real code edit — verify against what the session actually ran
  and confirmed, the same care as any other code change — never a documentation tidy-up.
- **Never restructure the skill's actual pipeline** (its Steps, their order, its decision
  framework) as a side effect of pruning verbosity. Pruning trims how much is said within a step,
  never what the pipeline does. If the session's work genuinely means a step should change, merge,
  or reorder, that's a deliberate structural edit — call it out explicitly in Step 4, don't fold it
  in silently under a routine sync.
- **Treat anything config-shaped as load-bearing, not narrative** — an OAuth client ID/name, an MCP
  connector UUID, a `mcp__...` tool name, an environment variable name, a credential file path,
  exact CLI/API syntax. Never "compress" or "delete as obsolete" one of these unless the session has
  direct, verified evidence (something actually run and confirmed this session) that the specific
  value changed. If unsure, leave it untouched and flag it in Step 5 rather than guess-pruning a
  still-correct value.
- **Frontmatter beyond `name`/`description` is config, not prose.** Some skills carry a structured
  `metadata:` block (MCP requirements, `configPaths`, required bins, connector UUIDs, version).
  Never edit that block unless the session's work explicitly changed exactly that field. After any
  edit touching frontmatter at all, re-check it's still valid YAML and `name` still matches the
  folder name — broken frontmatter can silently make Claude Code fail to load the skill at all.
- **When in doubt whether something is safe to touch, don't.** Leave it and flag it in Step 5 rather
  than editing past the boundary "to be thorough."

## Step 1 — Identify the closest/related file(s), grounded in what actually happened

Don't guess from vibes. Build the match from real signals in this session, strongest first:

1. **Skills actually invoked via the `Skill` tool this session** — the single strongest signal.
   If `gog` or `vjr-legal-case-file` was invoked and did the work being absorbed, that's the file.
2. **Skill/agent files already `Read` or `Edit`ed this session** — second-strongest; if you already
   opened a file to check its current state, it's very likely the right target.
3. **Tool/CLI/script names used this session** (`gog`, `wacli`, `tg_approval_gate.py`, a specific
   agent name) — grep for these across candidate frontmatter `description` fields.
4. **Topic/keyword overlap** between what the session did and each candidate's frontmatter `name` +
   `description` — weakest signal, use only to break ties or surface additional candidates.

Search scope, in order:
- `~/.claude/skills/*/SKILL.md` (global, always in scope)
- If working inside a repo: its own skill directories (e.g. this repo's `skills/*/SKILL.md` and/or
  `.claude/skills/*/SKILL.md` — check the repo's own CLAUDE.md for where it keeps them, layouts
  differ per project) and `.claude/agents/*.md`
- Don't limit yourself to one file if the session's work genuinely spans two (e.g. a CLI-tool
  gotcha belongs in the tool's own skill; a domain-specific technique learned while using that tool
  belongs in the domain skill — split the update accordingly, the way `gog` and
  `vjr-legal-case-file` each got a different slice of the same session's lessons).

**If nothing scores a real match, say so.** Don't force an update into a loosely-related file. Tell
the user there's no existing skill for this and offer `skill-creator`/`writing-skills` to build a
new one instead — a bad fit is worse than no update.

## Step 2 — Extract only the durable, generalizable facts

Not a transcript dump. Pull out:
- A gotcha or failure mode discovered, and its actual fix
- An assumption that turned out wrong, and the corrected one
- A command/flag/API call confirmed to work (or confirmed *not* to), with the exact syntax
- A decision-framework nuance the session's real situation didn't cleanly fit into what the skill
  already said — e.g. this session's discovery that a "payment plan against already-visible income"
  sits in its own middle category, not cleanly "settlement" or "full disclosure"

Leave out:
- Anything specific to one client/case/person that doesn't generalize (a real name, a real case
  number, a real account balance) — state the *pattern*, not the instance. If the session involved
  sensitive personal/business/legal detail (as this one did), that discipline is not optional:
  compress it to the reusable mechanism the way this session's own updates did, never carry the raw
  specifics into a file that a future unrelated session will read.
- Narrative about the debugging process itself once you know the fix — future readers need the
  fix, not the path to it (see [[skill-update-hygiene]]).

## Step 3 — Edit in place, applying the anti-bloat discipline

Before writing, skim the target file's current size and structure. Apply, in order:

1. **Does this fact update something already there?** Edit that sentence/table row/section in
   place — don't add a new paragraph next to the old one saying almost the same thing.
2. **Does this fact make something already there obsolete?** Delete the obsolete content. A
   "no longer true" section that survives update after update is exactly the bloat pattern this
   exists to prevent — keep at most one line of "why," not the full old explanation.
3. **Is there a debugging narrative to compress?** Once a fix is confirmed stable, cut it to
   the fix + a short reason. Don't preserve the "tried A, failed, tried B, failed, C worked" path.
4. **Is the same list/table stated more than once in the file?** Collapse to one authoritative
   copy, point to it from elsewhere instead of repeating it.
5. **Is the file now past ~150-200 lines, or did this update push a single section past being
   the file's main content?** That's the cue to do a fuller prune pass right now — or split
   volatile reference data (credential tables, inventories, per-account state) into a
   `references/*.md` the SKILL.md links to — not to just keep appending.

## Step 4 — State what you're about to touch, then do it

Before writing, tell the user which file(s) you're updating and the one-line reason each was
matched (Step 1's signal) — this is a local file edit on their own machine, not an external send,
so it doesn't need per-edit approval the way a message/publish would; it does deserve enough
visibility that a wrong file match gets caught before it's written, not after. If anything from the
Guardrails section applies — a structural change to the pipeline itself, or an edit that touches a
script/hook/asset/frontmatter `metadata` block rather than just body prose — call that out
specifically here rather than folding it into an otherwise routine sync. Then make the edits.

## Step 5 — Report the delta, not just "done"

State plainly: which file(s) changed, what was added, what was pruned, and the line-count
before/after if a prune pass happened — that number is the concrete evidence the discipline is
working, the same way it mattered when `gog/SKILL.md` went from ~270 to 180 lines with nothing
operationally lost. If Step 1 found no good match anywhere, report that too, rather than silently
skipping the request. Also report anything you deliberately left untouched because it was
config-shaped and unverified (Guardrails) — the user may know it's actually safe to update, but
that's their call to make, not a guess to resolve silently.
