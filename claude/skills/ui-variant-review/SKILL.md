---
name: ui-variant-review
description: >
  Generate N (default 3) distinct mockups of an existing UI page or component for
  stakeholder comparison — grounded in the real app (real source, real design tokens,
  real data), verified to actually render before delivery, and sent to a channel
  (Telegram, a file, or an Artifact) with an explicit "no code changed" framing. Two
  modes, always clarified up front before generating anything: layout-only (same
  fonts/colors/components, different information architecture — e.g. "what could we
  add or improve here") or reskin (a genuinely different visual aesthetic, e.g. "show
  me bold alternative directions"). Composes with ui-audit/ux-audit (an optional deeper
  audit pass before proposing changes), frontend-design (reskin-mode aesthetic
  guidance), and brainstorming/writing-plans (the handoff once a variant is picked —
  the chosen mockup answers most of brainstorming's design questions up front). This
  skill should be used when the user asks to "show me some layout options", "generate
  UI variants", "mockup alternatives for this page", "give me 3 directions for this
  design", "what could we improve about this screen", "compare redesigns", "explore
  layouts before we build", or wants concrete visual options to react to before
  committing to an implementation.
---

# UI Variant Review

Produce concrete, comparable mockups of an existing page — not a single redesign, not
an abstract discussion, not real changes to the app. The output is N self-contained
HTML files a stakeholder can open and react to, verified to actually render correctly
before they're sent.

## Prerequisites

- Playwright MCP (`browser_navigate`, `browser_evaluate`, `browser_resize`,
  `browser_take_screenshot`) — to visually verify every mockup before delivery.
- Read access to the target app's source (design tokens/theme file, the component
  being explored, its data model).
- A way to reach real data for that page — the project's own CRUD/API skill if one
  exists (e.g. `agshub-crud`), otherwise direct DB/API access or seed data. Never
  lorem-ipsum a mockup when real content is one call away — generic placeholder
  content is the fastest way to make a mockup look like it wasn't actually designed
  for this app.
- A delivery channel: Telegram (`scripts/send-telegram-variants.sh`, needs `BOT`/`CHAT`
  from the workspace's `CLAUDE.md`), `SendUserFile`, or the `Artifact` tool.

## Workflow

### Phase 0: Clarify mode — ALWAYS, before generating anything

This is the single highest-value step in this skill. Ask (don't assume):

> "Two ways I can do this: **(A) Reskin** — a genuinely different visual aesthetic for
> this page (different fonts, colors, tone — think 'show me 3 bold directions').
> **(B) Layout-only** — same interface you already have (same fonts, colors,
> components), just different structure/organization/what's surfaced (think 'same
> app, better arranged'). Which one?"

Getting this wrong wastes a full generation-and-delivery cycle — it did, once, before
this skill existed. If the request already unambiguously states one ("keep the actual
interface" / "show me some wild alternatives"), you can skip asking, but the default
when unstated is to ask, not to guess.

Also confirm at this point: which page/component, how many variants (default 3), and
where to send them.

### Phase 1: Ground in the real app

- **Read the target component's actual source** (the file that renders this page
  today) — its current structure, section order, what data it does and doesn't show.
- **Read the app's real design tokens** — its theme/CSS-variable file (light AND dark
  values if it has both), its font stack, its spacing/radius scale. In layout-only
  mode these get pasted into every variant's `<style>` verbatim; in reskin mode they're
  the baseline you're deliberately diverging from (know what you're replacing).
- **Read the app's icon system** — if it's a hand-drawn SVG set (no icon library),
  reuse the *exact* path data for any icon already needed; only draw new ones (in the
  same technique — same viewBox, stroke-width, cap/join style) for genuinely new
  concepts, and say so explicitly if the variant were real ("this is a new icon,
  matching the existing hand-drawn set").
- **Pull real data.** For layout-only mode especially — a "properties panel" mockup
  showing an actual project's actual identifier/dates/member names reads as a real
  proposal; showing "Project Name" / "John Doe" reads as a template. If a genuinely new
  field is proposed (data that doesn't exist in the app today), mark it clearly (a
  small "New" / "Proposed" badge inline) so a reviewer isn't misled about what's
  already there versus what would need building.
- **Optional deeper pass:** if the user wants a systematic audit first rather than your
  own read of the source (e.g. "audit this page properly, then show me improvements"),
  invoke `ui-audit` and/or `ux-audit` (`--quick` for a faster pass) and let their
  findings drive what each variant addresses, instead of improvising from a code read
  alone.

### Phase 2: Generate the variants

Each variant is one self-contained `.html` file — inline `<style>`, no external JS
framework, no build step, opens correctly with no other files present (Telegram
delivery sends each one alone). Give each a `<title>` and a top "mock ribbon" banner
identifying it as a concept (e.g. `fixed` top bar: "Layout concept — real interface, no
reskin · 1 / 3 · <variant name>") so nobody mistakes it for the live app if opened
standalone.

- **Reskin mode:** invoke `frontend-design` for aesthetic guidance — commit to a bold,
  distinct direction per variant (its own type pairing, palette, tone), not three
  timid variations on the same idea.
- **Layout-only mode:** reuse the real tokens/fonts verbatim (`prefers-color-scheme`
  dark block too, if the app has one — a layout mockup that breaks in dark mode
  undersells the proposal). Vary structure: single-column vs. two-column-with-sidebar,
  card-grid vs. stacked-list, everything-expanded vs. grouped-and-collapsible are
  reliably distinct starting points. Flag every added element inline ("New" / "New
  panel" / "Proposed field") so the diff from today's real page is visible at a glance
  without a separate legend.

### Phase 3: Verify before delivering

Playwright's `browser_navigate` blocks `file://` URLs — serve the directory locally
first:

```bash
cd <variants-dir> && python -m http.server <port> > /tmp/httpserver.log 2>&1 &
```

For each variant: navigate to `http://localhost:<port>/<file>.html`, check console
errors (a bare `favicon.ico` 404 is harmless and expected — anything else isn't),
resize to a reasonable desktop width, screenshot full-page. Read the screenshot back
and actually look at it — a missing font import, a broken CSS variable, or unreadable
contrast is much cheaper to catch here than after delivery. Kill the server
(`pkill -f "http.server <port>"`) once every variant is confirmed.

### Phase 4: Deliver

Write a short header (what's attached, which mode, one line per variant naming its
direction) and send. For Telegram:

```bash
export BOT="<from CLAUDE.md>" CHAT="<from CLAUDE.md>"
~/.claude/skills/ui-variant-review/scripts/send-telegram-variants.sh <variants-dir> <header.txt>
```

The script pairs `name.png` (preview) with `name.html` (the real file) by basename and
verifies `"ok":true` on every send — see the script's own header comment for why the
header text must go through a file, not an inline `-F`/`--data-urlencode` string
(Telegram has rejected inline non-ASCII with a UTF-8 error on some shells even though
the same text works fine from a file).

State plainly that no code was changed — this is the easiest thing to leave ambiguous
and the most important not to.

### Phase 5: Handoff once a variant is picked

The chosen mockup already answers most of what `brainstorming` would otherwise need to
ask from scratch — treat it as a strong starting proposal, not a blank slate. Still run
`brainstorming`'s process (it may surface real implementation questions the mockup
can't answer — where does a new property's data actually come from, does a new field
need a backend change, what's out of scope), but expect a shorter Q&A than a
from-scratch design. From there, spec doc → `writing-plans`, same as any other feature.

## Important rules

- **Never skip Phase 0.** Reskin and layout-only produce visually similar-looking
  deliverables (both are "3 HTML files") but represent completely different asks — the
  clarifying question costs one message; a wrong-mode generation costs a full redo.
- **Never skip Phase 3.** An unverified mockup that fails to render (missing font,
  broken token reference) undermines every variant sent alongside it, not just the
  broken one.
- **Never invent data** a reviewer can't tell is invented. Real data or an explicit
  "New"/"Proposed" flag — nothing presented as-if-real that isn't.
- **This produces zero changes to the app.** No file in the actual codebase is ever
  touched by this skill — only new, standalone mockup files outside it (a scratch/temp
  directory, not the project tree).

## Files

| File | Purpose |
|------|---------|
| `scripts/send-telegram-variants.sh` | Pair preview screenshots with their HTML files and send both to Telegram, verifying each send. |
