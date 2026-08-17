---
name: sales-information-memorandum
description: Draft or update a commercial property Information Memorandum for ALTO Property. Gathers real data locally (REX API) and from the ALTO Mac-mini (Josh's email, WhatsApp) — never fabricates a figure — then renders the branded PDF by calling the Mac-mini's existing design-system pipeline over SSH. Use for "build an IM for <address>", "chase the missing data for <address>'s IM", "update the information memorandum".
---

# Sales — Information Memorandum

Produces ALTO's commercial-property Information Memorandum (IM) PDFs. This
skill is a **local orchestrator only** — the actual template, brand tokens,
and PDF renderer live in the `design-system` skill on the ALTO Mac-mini and
are never edited or reimplemented here. See `connecting-to-alto-mac-mini`
for the SSH connection details this skill depends on.

**Hard rule, same as every other data-facing skill in this workspace: never
fabricate a number.** Every field that isn't independently confirmed from a
real source goes in as `TBC`, exactly like the existing 146 Scotts Road
draft. A polished-looking IM with guessed figures is a liability, not a
deliverable.

## Step 0 — Read `trail-history.md` first

Before touching a property that's been through this skill before, read
`trail-history.md` in this skill's directory — it's a running log of every
real render sent to Josh, every template/pipeline change, and the reasoning
behind judgment calls (data mappings, address discrepancies, rejected
approaches) that aren't obvious from the code or a fresh context.json
alone. Skipping this risks re-litigating a settled decision, re-fetching
data that was already found and recorded, or repeating a fix that was
already tried and reverted (e.g. the `--variant editorial` approach for
146 Scotts Road — tried, wrong, documented why).

After any run that sends something to Josh, changes the template/manifest,
or makes a judgment call a future session would otherwise have to
re-derive, **add a dated entry to `trail-history.md`** — short and
factual, with real artifact references (wacli message IDs, file paths)
where they'd help a future session verify a claim instead of trusting it
blindly.

## Step 1 — Gather real data (do this every time, don't skip)

For a given address, check every source below and keep a running tally of
what was found vs. not found — this becomes the evidence trail if you need
to report back what's still missing:

1. **REX** (local, `scripts/rex-api/client.mjs` in altoproperty-main) —
   search `Listings` for the address (scan all pages' `property.system_search_key`
   for a substring match, since exact-field search is unreliable — see
   `probing-integration-endpoints` skill history). If a listing exists, pull
   price/tenancy/title data from it. If CoreLogic/RP Data is reachable via
   REX for this address (see `alto-twilio-ops`-adjacent `rex-corelogic`
   tooling), check there too.
2. **Josh's email** (`joshua.kim@altoproperty.com.au`, via SSH + IMAP on the
   Mac-mini — see `connecting-to-alto-mac-mini`'s email gotchas) — search
   **every folder** (Inbox, All Mail, Sent, Important, Starred, Spam, Trash,
   Drafts), not just Inbox, for the street name and suburb.
3. **`sales@altoproperty.com.au`** — this is a Google Group with real
   collaborative mail (vendor docs, photographer emails) that never reaches
   Josh's personal inbox and has **no IMAP login**. It can only be checked
   via a browser session that already has it added as a Google account
   (account switcher, not a fresh sign-in — a fresh MCP browser tab will
   hit a password prompt; don't enter one, ask the user to check it or
   share an already-authenticated tab instead).
4. **Josh's WhatsApp** (local `wacli messages search "<term>" --chat
   61467048837@s.whatsapp.net --json`) — check for the address and for any
   prior IM thread about it (past drafts you sent him carry useful context:
   what was already flagged TBC, what he was asked for). **This includes any
   PDF attachments already sent** — download them (`wacli media download
   --chat <jid> --id <msgID> --output <path>`) and read them back. A prior
   draft can carry real data (historical lease figures, cadastral detail,
   even site photos baked into the PDF via `pdfimages -all`) that a rebuilt
   context.json can otherwise silently drop — cross-check, don't just
   re-derive from scratch. This is exactly what happened 2026-08-07: an
   earlier one-off draft ("Variant A") had richer data than a from-scratch
   rebuild did, and its embedded photos were the *only* copy of them
   anywhere — extracting straight from the PDF was the only way to recover
   them.

Report the evidence trail plainly: source checked, what was searched, what
was found (or "nothing found"). Don't silently omit a source that came back
empty — an omitted source reads as "verified clean" when it might just be
unchecked.

## Step 2 — Build `context.json`

The remote template (`information-memorandum.html`, manifest key
`information-memorandum`) takes one JSON context — see
`templates/samples/information-memorandum.json` on the Mac-mini, or the
manifest's own `required_fields` array, for the exact current field list
(fetch it fresh if unsure; don't rely on memory, the manifest is the source
of truth — it's what `generate-media.sh` actually validates against before
rendering). As of the 2026-08-07 rebuild (see "Format" below) the field set
is: `doc_title`, `cover_title`, `cover_suburb_state_postcode`,
`cover_subtitle`, `cover_photo_abs`, `cover_stats_html` (4-item stat strip:
asking price / occupied tenancies / building area / gross annual rent),
`cover_lead_paragraph`, `cover_prepared_date`, `running_header_text` (the
small centered running header on every inner page — include or drop
"(Review Draft)" depending on whether this is still a working draft),
`exec_summary_html`, `exec_summary_stats_html` (4-item strip: asking price /
gross yield / gross annual rent / active tenancies), `exec_summary_photo_left_abs`,
`exec_summary_photo_right_abs`, `tenancy_profile_intro`,
`tenancy_schedule_rows_html`, `tenancy_total_annual`,
`tenancy_schedule_footnote`, `historical_lease_rows_html`,
`historical_lease_combined_label`, `historical_lease_combined_value`,
`historical_lease_footnote`, `prop_address_full`, `prop_type`,
`prop_title_reference`, `prop_lot_plan`, `prop_parish_county`,
`prop_building_area`, `prop_zoning`, `prop_occupancy`,
`property_description_html`, `location_connectivity_items_html`,
`property_photo_left_abs`, `property_photo_right_abs`,
`investment_highlights_items_html`, `investment_highlights_outstanding_note`,
`disclaimer_property_address`.

- **Every field is dynamic — none of it is copy-pasted from a prior
  property.** The 146 Scotts Road context.json is an example of the
  *shape*, not a template to clone values from. Each run starts from
  Step 1's findings for *that* address and nothing else. Field → source:

  | Field(s) | Source (in order of preference) |
  |---|---|
  | `cover_title`, `cover_suburb_state_postcode`, `prop_address_full`, `disclaimer_property_address` | The address as given/confirmed |
  | `cover_stats_html`, `exec_summary_stats_html` (asking price, gross yield, gross annual rent, tenancy count, building area) | REX/CoreLogic listing data → Josh's email/WhatsApp for vendor-supplied figures → `TBC` badge if none found anywhere |
  | `prop_title_reference`, `prop_lot_plan`, `prop_parish_county`, `prop_zoning` | REX/CoreLogic title & property lookup → executed lease/title documents found in email |
  | `prop_building_area`, `prop_type`, `prop_occupancy` | Site photography + any listing/lease documents on file |
  | `cover_photo_abs`, `exec_summary_photo_*_abs`, `property_photo_*_abs` | Real site photography — Josh's own phone/email, or a professional-photography vendor email in `sales@` (e.g. a "Media 44"-style photographer invoice/delivery) — see Step 1.4 for recovering photos baked into a prior sent PDF. Never reuse another property's photos, and never leave a photo field pointing at a placeholder image. |
  | `tenancy_schedule_rows_html`, `tenancy_total_annual`, `tenancy_profile_intro` | Ground-floor signage read from current site photography for tenant names/uses; rent figures from the live rent roll (ask Josh) — `TBC` badge until confirmed |
  | `historical_lease_rows_html`, `historical_lease_combined_label`, `historical_lease_combined_value`, `historical_lease_footnote` | Executed lease PDFs actually found in email/attachments during Step 1. **If no historical lease documents exist for this property, don't fabricate this section** — set `historical_lease_rows_html` to a single explanatory row (e.g. `<tr><td colspan="5">No executed historical lease documentation on file for this property.</td></tr>`), and the combined fields to `"—"`. This section exists because 146 Scotts Road happened to have two lapsed leases on file; most properties won't. |
  | `property_description_html`, `location_connectivity_items_html`, `investment_highlights_items_html` | Written prose/bullets, but every factual claim inside must trace to something confirmed in Step 1 — no invented amenities, no assumed zoning intent |
  | `investment_highlights_outstanding_note` | Dynamically generated from whatever is *still* `TBC` after Step 1 for this specific run — not a fixed sentence copied from a prior property |
  | `running_header_text` | Address + current document status — drop "(Review Draft)" once Josh has actually signed off, don't leave it there by habit |
  | `cover_prepared_date` | The actual month/year this render was produced |

- For anything unconfirmed after checking every source in Step 1, use the
  literal string `TBC` — wrap it in `<span class="badge">TBC</span>` inside
  table cells (matches the template's bordered-badge styling for
  outstanding figures), plain `TBC` elsewhere. Never a plausible-sounding
  guess, and never a value carried over from a different property's run.
- **Photos are real filesystem paths on the Mac-mini, not embeddable data.**
  `cover_photo_abs`, `exec_summary_photo_left_abs`,
  `exec_summary_photo_right_abs`, `property_photo_left_abs`, and
  `property_photo_right_abs` must each be an *absolute path that exists on
  the Mac-mini* (Chrome renders there, not locally) — scp real site photos
  up to `media-inbox/information-memorandum/<address-slug>/photos/` first,
  then point the context fields at those remote paths. There's no
  auto-fetch step; if you don't have real photos for a property, ask for
  them rather than reusing another property's images.
- Every disclosed fact needs a one-line source note somewhere in the
  document (site photography date, lease document reference, REX pull,
  etc.) — this skill inherits the same "Data Sources Checked" discipline as
  `outreach-campaign-brief`.
- Do your working edits to the context JSON in your scratchpad, not this
  skill's directory — but see Step 5 below: the moment a version is
  actually rendered and worth keeping, snapshot it into this skill's
  `outputs/` directory before editing it further. Scratchpad is temporary
  by design (session-specific, gets wiped) — don't let the only copy of a
  real context.json live there past the session that created it.

## Step 3 — Render via the Mac-mini (never render locally)

```bash
~/.claude/skills/sales-information-memorandum/render-remote.sh \
  /path/to/scratchpad/context.json \
  /path/to/scratchpad/output.pdf
```

This script (a) scp's the context up, (b) runs
`design-system/scripts/generate-media.sh information-memorandum --context
<ctx> --out <path>` **unmodified, remotely** (brand validation included —
the manifest's `validate_profile: brochure` gate runs automatically unless
you pass `--draft`, which this wrapper doesn't expose on purpose — a failed
brand gate should surface, not be silently skipped), (c) scp's the PDF back,
(d) cleans up the remote temp files. Do not SSH in and hand-run
`render-pdf.sh`/`render-template.py` directly — `generate-media.sh` is the
documented canonical entry point and is what applies the brand-validation
gate.

## Format — matches "Variant A", not the shared variant-CSS system

`information-memorandum.html` is a **fixed, bespoke design**: Georgia serif
throughout, cream (`#faf8f5`) background on every page, brand red
(`#d23f1f`) section headings and stat figures, a small centered running
header instead of a logo bar on inner pages, bordered `TBC` badges in
tables, and a two-column spec-sheet layout on the Property Description
page. It does **not** use the shared `classic`/`bold`/`editorial`
`--variant` CSS system that other design-system templates use (there's no
`{{ALTO_VARIANT_CSS}}` link in this template at all) — there is exactly one
canonical look for this document type.

This was a full rebuild done 2026-08-07. The registered template had
drifted from what Josh had actually already reviewed and approved: a
one-off document called "Variant A — Classic ALTO style", sent via wacli
2026-08-03 and never folded back into `design-system`. That PDF (font
confirmed via `pdffonts` = Georgia, colours confirmed via pixel-sampling,
copy confirmed via `pdftotext -layout`, photos recovered via `pdfimages
-all`) is now the source of truth for this template's look — if the
rendered output ever looks visibly different again (wrong font, wrong
background colour, missing the Historical Lease Reference section, etc.),
that's the same class of bug as 2026-08-07, not a style preference to
negotiate: re-diff against a `wacli media download` of the last
Josh-approved PDF before touching anything.

## Step 4 — Verify and report

Read the rendered PDF back (visually, page by page) before telling the user
it's done — confirm every field you supplied actually landed, and that any
remaining `TBC`s are the ones you expected, not new gaps from a schema
mismatch. Report: what got filled in this run, what's still TBC and why
(which source(s) you checked and came up empty), and where the PDF landed
locally.

## Step 5 — Archive the output (don't skip this)

Scratchpad directories are session-specific and get wiped between
sessions — this is not hypothetical, it happened to a real render on
2026-08-07 and had to be reconstructed from conversation memory. Before
moving on to anything else:

1. Copy the rendered PDF into
   `~/.claude/skills/sales-information-memorandum/outputs/<address-slug>/`
   (create the folder if it's a new property), named with its version.
2. Copy the context.json that produced it into the same folder, named
   `context-vN.json` — **do this before making any further edits to that
   context.json**, not after. Editing a file in place and only
   snapshotting it later loses the exact state that produced the version
   you already sent someone, which is precisely the gap recorded in
   `outputs-log.md` for this property's v9 and v10.
3. Add a row to `outputs-log.md` (version, date, snapshot path, PDF path,
   wacli message IDs if it was sent, one-line summary of what changed).
4. Add the corresponding narrative entry to `trail-history.md` per Step 0.

`outputs-log.md` is the structured index (what exists, where);
`trail-history.md` is the narrative log (why a decision was made). Keep
both current — a future session should be able to read `outputs-log.md`
to find the latest real artifact for a property without re-rendering, and
`trail-history.md` to understand why it looks the way it does.

## What this skill does NOT do

- Does not invent a second/parallel IM template, or fork the render
  pipeline — there is exactly one live `information-memorandum.html` on the
  Mac-mini and this skill always renders through it via `generate-media.sh`.
  "Variant B/C" style one-off explorations referenced in old drafts were
  never part of the registered pipeline; don't resurrect them without the
  user asking.
- Genuinely does edit `design-system`'s template/manifest on the Mac-mini
  when the *format itself* is wrong or has drifted from an approved
  reference (confirmed via a real prior artifact, not a stylistic guess) —
  this happened 2026-08-06 (missing header/footer chrome, footer overlap)
  and 2026-08-07 (full rebuild to match Variant A). Always back up the file
  first (`cp foo.html foo.html.bak-<date>`), diff after, and re-render +
  visually re-verify every page, not just the automated brand-validation
  PASS.
- Does not auto-send the PDF anywhere — sending to Josh (WhatsApp) or
  anyone else is a separate, explicit action requiring the user's go-ahead,
  same as any other external send in this workspace.
