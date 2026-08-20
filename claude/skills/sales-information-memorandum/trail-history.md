# Trail History

Summarized log of every real transaction this skill has made — renders sent
to Josh, template/pipeline changes, and the reasoning behind decisions that
aren't obvious from the code alone. Read the relevant property's section
before starting new work on it; add a new dated entry every time you send
something to Josh, change the template/manifest, or make a judgment call
that a future session would otherwise have to re-derive from scratch.

Keep entries short and factual — this is a changelog, not a narrative.
Link to real artifacts (wacli message IDs, file paths) where it helps
future-you verify a claim rather than trust it blindly.

---

## Template & pipeline (applies to all properties)

- **2026-08-06** — Fixed real layout bugs in `information-memorandum.html`
  on the Mac-mini: missing header/footer chrome on Tenancy Schedule and
  Financial Overview pages, disclaimer text overlapping the footer on the
  last page. Root cause: several conceptual sections were bundled into one
  `.page` div; when combined content exceeded 297mm the overflow spilled
  onto a raw continuation sheet with no repeated header/footer. Fix: one
  section per `.page` div, each with its own header and footer. This
  became the standing pattern for every template edit since.
- **2026-08-07** — First attempt at "match the editorial template" was
  **wrong**. Investigated and found `information-memorandum.html` never
  wired in `{{ALTO_VARIANT_CSS}}` at all (every sibling document template
  does), fixed that, rendered with `--variant editorial` (Cormorant
  Garamond serif). User rejected it: the real reference was a *different*,
  one-off document called "Variant A — Classic ALTO style", sent to Josh
  via wacli 2026-08-03, never folded into the registered pipeline. The
  editorial-variant fix wasn't wrong on its own terms, it just wasn't what
  Josh had actually already reviewed.
- **2026-08-07** — Full rebuild of `information-memorandum.html` to match
  "Variant A" exactly, since that's the real approved reference. Downloaded
  Variant A from wacli (`wacli media download`), confirmed its exact spec
  forensically rather than by eye: font via `pdffonts` (Georgia, not
  Cormorant Garamond), colours via pixel-sampling on the rendered pages
  (`#d23f1f` red, `#473c38` ink, `#faf8f5` cream, `#d8cfc8` hairline —
  matches this repo's real brand tokens exactly), copy via `pdftotext
  -layout`, and its 5 embedded real site photos via `pdfimages -all` (no
  separate source files existed anywhere — the PDF was the only copy).
  Added the "Historical Lease Reference" section, the two-column property
  spec sheet, and the small centered running header — none of which
  existed in the registered template before. `manifest.json`'s
  `required_fields`, `expect_pages_min`, and `expect_text` were updated to
  match. The old `classic`/`bold`/`editorial` `--variant` system was
  dropped for this template entirely — it's now one fixed, bespoke design
  with no `{{ALTO_VARIANT_CSS}}` link at all. `render-remote.sh` no longer
  passes `--variant`.
- **Backups on the Mac-mini** (don't delete, they're the recovery path if a
  future edit needs to diff against a known-good state):
  `templates/information-memorandum.html.bak-2026-08-06`,
  `.bak-2026-08-07-variant-editorial-attempt` (the rejected editorial pass),
  `templates/manifest.json.bak-2026-08-06`, `.bak-2026-08-07`,
  `templates/samples/information-memorandum.json.bak-2026-08-07`.

---

## 146 Scotts Road, Darra QLD 4076

- **2026-08-03** — Josh sent three one-off IM variants for this address via
  wacli, built outside the registered pipeline: Variant A (Classic ALTO
  style), Variant B (Modern editorial), Variant C (Compact investor deal
  sheet). Everything financial was TBC at this point. **Variant A later
  became the canonical template reference** (see above) — its exact PDF is
  the ground truth for this document type's look going forward.
- **2026-08-06** — Sent a formatting-corrected render (v5) after the
  header/footer bug fix above.
- **2026-08-07** — Rebuilt to match Variant A (v7/v8), recovering real data
  that had been dropped in an earlier rebuild: the historical Shop 4/Shop 5
  lease tenant uses (an Indian grocery and an Asian BBQ diner, 2015/2016,
  both lapsed) and Parish/County (Oxley, Stanley). Uploaded Variant A's 5
  real site photos to
  `media-inbox/information-memorandum/146-scotts-road-darra/photos/` on
  the Mac-mini (extracted from the PDF via `pdfimages`, no other copy
  existed). Sent v8 to Josh via wacli.
- **2026-08-07** — Ran a live public-data-source research pass for the
  remaining TBC fields (asking price, current rent roll). Real leads
  found: a prior "Sold" listing for this exact property via First National
  Metro (agent Hiep Nguyen, 0414 311 262, Property ID 3107498 — land/build
  area figures there conflict with our REX-sourced 966m² and were never
  reconciled); a dated (Oct 2021, likely stale) rent figure for 4/146 via
  Allhomes. Ruled out: a "$721,252 gym & physio" figure that search results
  initially suggested was for this address — confirmed directly it isn't.
  commercialrealestate.com.au and domain.com.au both block automated
  access outright. Compiled into a branded PDF via
  `~/agents/report-orchestrator/` and sent to Josh.
- **2026-08-07** — User uploaded a photo of an Information Memorandum for
  **39 Railway Parade, Darra QLD 4074** — a different street name AND
  different postcode from this property (146 Scotts Road, 4076) — asking
  to use it to fill this property's TBC fields. Flagged the mismatch via
  AskUserQuestion rather than proceeding blind. **User then confirmed,
  via Josh, that it's the same physical site** — this is secondhand
  confirmation relayed through the user, not something independently
  verified against a primary source (e.g. a title search showing both
  addresses). Treat as real but not iron-clad; the address/postcode
  discrepancy itself has never been independently resolved and is flagged
  in the document as such.
- **2026-08-07** — Filled asking price directly from that document:
  **$4,500,000**, consistent with a real offer on file from an overseas
  (Vietnamese) investor per Josh. This is property-level data and doesn't
  depend on tenant identity, so it was used with high confidence (v9).
- **2026-08-07** — User then asked to fill the remaining TBC (per-tenant
  rent) using the same photo, accepting an estimate. Built a name/use-type
  mapping from the photo's six-lot schedule (Lots 1,2,3,6,7,8 — Shops 4 & 5
  excluded, matching this property's own Historical Lease Reference
  section) onto the five *current* tenants confirmed by July 2026 site
  photography:

  | Old (39 Railway Parade, six-lot schedule) | → Current tenant | Confidence |
  |---|---|---|
  | Lot 1 "ChemPro Chemist" | Darra Chemist | Name/use match |
  | Lot 6 "Legal Office" | A.J. Torbey Solicitors | Use match |
  | Lot 2 "Specialist Dental & Medical Clinic" | DDC Specialist Dental Centre | Closest name match |
  | Lot 7 "Specialist Dental Clinic" | Ocean Dental Care | Use match |
  | Lot 3 "Dental Laboratory" | Darra Medical Centre | **Weakest — assigned by elimination, not a real match** |
  | Lot 8 "Dental Laboratory" ($1,358.07/mo) | *unmatched* | Excluded from the total entirely |

  Resulting total: $259,679.16/yr against $4.5M asking = **5.77% gross
  yield** (not the original document's 6.13%, since Lot 8 dropped out).
  Every figure in the rendered PDF (v10) carries an asterisk and the
  footnote spells out this exact mapping table — **none of this is a
  confirmed current rent roll**, it's Josh's own six-lot schedule for a
  since-turned-over tenant mix, reallocated by best-effort inference. Sent
  to Josh via wacli with an explicit disclaimer message making the same
  point in plain language.
- **Open item, not resolved by any of the above**: the 146 Scotts Road /
  39 Railway Parade address-and-postcode discrepancy. Don't silently drop
  this from future renders of this property — it's noted in
  `property_description_html` and `investment_highlights_outstanding_note`
  in the context.json, and should stay there until Josh actually explains
  it (dual street frontage on a corner lot is the most likely explanation
  but that's a guess, not a confirmed fact).
- **2026-08-07** — User asked to make the Shops 4 & 5 / whole-building-
  and-land option more prominent — it existed in Property Description,
  the Historical Lease footnote, and one Investment Highlights bullet, but
  had been dropped from the Executive Summary when that field was
  rewritten for the asking-price update (v9) and was never on the cover
  at all. Added it in four places for v11: `cover_lead_paragraph` (one
  sentence), a new dedicated bolded paragraph in `exec_summary_html`,
  strengthened wording in `property_description_html`, and promoted +
  bolded the Investment Highlights bullet to 2nd position. Consistent
  phrasing used throughout: "full ownership of the entire building and
  land as one holding" — this is the phrase to keep using for this
  concept in future edits, don't drift to different wording per field.
  Sent to Josh via wacli (text msg `3EB07F67DE71753ECC665D`, file msg
  `3EB080956C032A3893DCFA`) — no other content changed from v10, same
  estimated rent figures and asking price.
- **Latest rendered context**: `scotts-context-v11.json` (v9 → v10 → v11
  were all produced by editing the same file in place; only the render
  filename bumped each time, matching the manifest's non-classic-variant
  naming convention, not a genuinely separate source file per version).
  Scratchpad paths are session-specific and get cleaned up between
  sessions — if you need the actual JSON content and it's not on disk,
  it's in this file's history above in enough detail to reconstruct it,
  or re-derive from the latest PDF sent to Josh via `wacli media
  download`.
- **2026-08-07** — User asked whether there was a log of the actual PDFs
  produced — there wasn't one, this file only narrates *why* things
  changed, not *what exists and where*. Added `outputs-log.md` (structured
  table: version, snapshot path, PDF path, wacli message IDs, one-line
  summary) and an `outputs/<address-slug>/` folder in this skill's own
  directory to durably hold rendered PDFs and context.json snapshots —
  scratchpad was the only place they lived before, and it doesn't survive
  a session boundary. Archived the recoverable v9/v10/v11 PDFs and the
  current (v11) context.json snapshot immediately; v9 and v10's exact
  context.json states had already been overwritten in place by the time
  this was noticed. Step 5 in `SKILL.md` now makes archiving-before-
  further-editing a required part of every future render, to stop this
  specific gap from recurring.
- **2026-08-07** — User asked to backfill the v9/v10 reconstructions
  rather than leave them as a logged gap. Since the exact `Write`/`Edit`
  tool calls that produced both states were still visible earlier in this
  same conversation, replayed them precisely instead of approximating from
  memory: wrote v9 verbatim from its original `Write` call, then applied
  the exact four `Edit` diffs that turned v9 into v10. **Verified, not just
  asserted** — re-rendered both reconstructed context.json files through
  the real pipeline and diffed the extracted text against the already-
  archived v9.pdf/v10.pdf: zero differences (the only byte-level diff in
  the raw PDFs was Chrome's CreationDate/ModDate timestamp, which will
  always differ between any two renders regardless of content — confirmed
  by inspecting those exact bytes directly). Both snapshots in
  `outputs-log.md` are now marked as backfilled-and-verified, not
  reconstructed-and-hoped. Generalized this as the standard recovery
  method in `outputs-log.md`'s process notes: replay known edits, then
  prove it with a re-render + text diff, before ever marking something
  "not recoverable."
