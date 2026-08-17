# ALTO Property — delivery report template

Client-specific variant of the `writing-delivery-reports` skill for **ALTO Property**
(`altoproperty-main`). Use this instead of the generic weasyprint auto-brand-extraction
path (`~/agents/report-orchestrator/report_orchestrator.py pdf-export`) whenever the
client is ALTO — that path pulls CSS tokens from `app/globals.css` and produces a
brown/cream document that does not match ALTO's actual brand.

Picked 2026-08-11 after presenting 3 HTML cover variants (full-bleed editorial, minimal
letterhead, bold/magazine) via Telegram — the client chose **minimal letterhead**.

## Brand rules (non-negotiable, verified against the real logo asset)

- **Background: white only.** No brown/cream/off-white — that was the old
  report-orchestrator auto-extraction and is explicitly rejected for ALTO reports.
- **Accent color: `#a52c10`.** Sampled directly from the dominant opaque pixel color in
  `assets/alto-logo-red.png` (96k+ pixel sample) — **not** the site's `brand-red-600`
  Tailwind token (`#d23f1f`), which is a noticeably brighter/more orange shade used in
  the live UI. This is the deeper, true logo red. Re-sample if the logo file ever
  changes (`scripts left inline in git history of this file — dominant-color histogram
  over non-white, fully-opaque pixels`).
- **Body text:** near-black (`#1a1614`) / grey (`#6b625d`) for readability — red is
  reserved for headings, table headers, rules, status badges, and the logo itself. Pure
  red paragraph copy was explicitly tried and rejected as unreadable at length.
- **Logo:** top-left corner, small, on the plain white letterhead band. Source of truth
  is `altoproperty-main/public/images/alto-logo-red.png` — `assets/alto-logo-red.png`
  here is a cached copy; re-copy it if the live logo is ever updated.
- **Cover photo:** a real ALTO listing photo pulled from the live `properties` table
  (synced from REX CRM), never a stock photo. See "Pulling a cover photo" below.
- **Font:** Inter (matches the live site, not the old serif/Georgia PDF heading font).

## Files

- `template.html` — tokenized HTML (`{{TOKEN}}` placeholders), letterhead layout:
  logo band → red rule → title/meta/status → contained rounded-corner cover photo with
  caption → content sections (exec summary, system snapshot, delivered-this-period,
  in-progress, upcoming, risks & mitigations, decisions/approval, milestone/acceptance
  ledger). Section *headings* are tokenized too (`{{SEC_*}}`) so the same visual system
  serves more than one document genre — see "Document kinds" below. Follows the parent
  skill's Part 1 structure — Part 2 (system docs) is omitted by design for stakeholder
  status updates; add it manually if this ever needs to go to a technical audience.
- `render.mjs` — fills the template from a data JSON + logo + photo, then renders to
  PDF via Playwright Chromium (`page.pdf()`), plus a `-preview.png` of page 1 for a
  quick visual check before sending. **Not a standalone npm package** — it resolves
  `playwright-core` from `altoproperty-main`'s own `node_modules` via an absolute-path
  ESM import (`PROJECT_DIR` constant at the top of the file; override with
  `PLAYWRIGHT_CORE_PROJECT` env var if the repo ever moves).
- `example-data.json` — the 11 Aug 2026 "AI Systems Progress Report" (period status,
  default section headings) — worked example / field reference for every key
  `render.mjs` expects.
- `example-data-gameplan-approval.json` — the 11 Aug 2026 "Development Gameplan"
  (approval-request document — see "Document kinds" below) — worked example of the
  `sections` override + `approval` block.
- `assets/alto-logo-red.png` — cached logo, see Brand rules above.

## Document kinds

The template supports more than one genre of report through two optional `data.json`
keys — same visual system (letterhead, colors, tables), different content framing:

- **Period progress report** (default) — "what shipped this period." Omit `sections`
  and `approval` entirely; the built-in headings ("Delivered this period", "Decisions
  needed from you", etc.) apply automatically. See `example-data.json`.
- **Gameplan / approval request** — "here's everything in flight and what's next,
  please sign off." Set `data.sections` to retitle headings (e.g. `delivered` →
  "What's already built", `decisions` → "Approval requested") and set `data.approval =
  { ask: "..." }` to render a bordered sign-off box (Approved by / Date line) right
  after the approval-ask list. See `example-data-gameplan-approval.json`. Use this kind
  whenever the document's job is to get an explicit yes/no from the client on
  recognising scope or greenlighting a specific next build — not just to report status.

Both kinds share `render.mjs` — the only difference is what you put in `data.json`.

## Usage

1. **Pull a cover photo** (see below), save it locally.
2. **Write a `data.json`** for this report — copy `example-data.json` and fill it in.
   Every field maps 1:1 to a `{{TOKEN}}` in `template.html`. Keep the parent skill's
   non-negotiable rules in mind while writing it: outcomes not activities, verified-only
   claims, every delivered item gets an evidence PR/commit/test.
3. **Render:**
   ```bash
   node render.mjs --data /path/to/data.json --photo /path/to/photo.jpg --out /path/to/report.pdf
   ```
   (`--logo` defaults to the cached asset here; pass it explicitly only if testing a
   logo change.) Read the generated `-preview.png` (or the PDF itself) before sending —
   don't assume the render matches the data without looking.
4. **Deliver** per the parent skill's Delivery section — Telegram via
   `python3 ~/.claude/scripts/tg_send.py --file report.pdf --caption "..."` to the
   operator's own chat for review; never straight to the client without explicit
   go-ahead on content.

## Pulling a cover photo

Query the live `properties` table directly (already synced from REX CRM by the
existing cron — see `altoproperty-main/CLAUDE.md` → REX API section) rather than using
a stock image:

```bash
cd altoproperty-main
SUPA_URL=$(grep '^NEXT_PUBLIC_SUPABASE_URL=' .env.local | cut -d= -f2-)
SUPA_KEY=$(grep '^SUPABASE_SERVICE_ROLE_KEY=' .env.local | cut -d= -f2-)
curl -s "${SUPA_URL}/rest/v1/properties?select=address,suburb,images&status=eq.available&order=updated_at.desc&limit=1" \
  -H "apikey: ${SUPA_KEY}" -H "Authorization: Bearer ${SUPA_KEY}" | python3 -m json.tool
```

`images` is an array of REX-CDN URLs in upload order — the first 1-2 are usually
aerial/drone shots with a marketing boundary-line overlay (fine for context, less clean
as a cover). Look a few entries in for a plain street-level exterior shot (clear sky,
no overlay) — that reads better as a report cover than a listing thumbnail. Download it
locally (`curl -o photo.jpg <url>`) before passing to `render.mjs` — do not reference
the remote CDN URL directly, since the render is base64-embedded for portability and
the CDN URL may not stay live indefinitely.

## Common mistakes

| Mistake | Fix |
|---|---|
| Running `report_orchestrator.py pdf-export` for an ALTO report | Wrong template — brown/cream, wrong red, no logo/photo. Use this folder instead. |
| Using `brand-red-600` (`#d23f1f`) instead of `#a52c10` | That's the site's UI accent, not the logo's actual color — sample the logo, don't assume the Tailwind token matches. |
| Using a stock/generic property photo | Always pull a real, current ALTO listing from the `properties` table. |
| Making body paragraph text red | Reserve red for headings/accents only; body text is `#1a1614`/`#6b625d` for readability. |
| Referencing a remote REX-CDN photo URL in the HTML instead of downloading + embedding it | CDN URLs aren't guaranteed to stay live; always download and base64-embed. |
| Running `render.mjs` from outside a place where it can reach `altoproperty-main/node_modules` | It resolves `playwright-core` via an absolute path already — no `cd` or `NODE_PATH` needed, just run `node render.mjs ...` from anywhere. |
