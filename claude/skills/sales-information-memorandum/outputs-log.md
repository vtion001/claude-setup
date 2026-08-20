# Outputs Log

Structured, scannable record of every PDF this skill has actually rendered
and sent — one row per version. `trail-history.md` has the narrative
reasoning behind each change; this file is the index of what was actually
produced and where it physically lives now.

**Why this exists:** rendered PDFs and context.json files were previously
only ever written to a session's scratchpad directory, which gets wiped
between sessions — confirmed the hard way on 2026-08-07 when v7/v8 had to
be reconstructed from conversation memory after a session boundary. From
v9 onward, every render's PDF (and, where possible, its context.json) gets
copied into `outputs/<address-slug>/` in this skill's own directory, which
persists.

**Process going forward:** after every `render-remote.sh` call that
produces a version worth keeping, copy the output PDF into
`outputs/<address-slug>/` under its version filename, and — **before
editing the context.json again** — copy it too, as
`context-vN.json` (immutable, not overwritten by the next edit). Add a row
below. If a context.json wasn't snapshotted before being edited for the
next version, don't leave it unrecovered without trying: if the exact
edits made since are still visible in conversation history, replay them
onto the last known state and **verify the reconstruction by re-rendering
it and diffing against the real archived PDF** (text diff, since Chrome
stamps a fresh CreationDate/ModDate into the PDF bytes on every render —
that's expected and not a mismatch; anything beyond the timestamp bytes
differing is a real problem). Only mark a version "not recoverable" once
that's genuinely not possible — see v9/v10 below for what a verified
backfill looks like, and v7/v8 for a version where recovery genuinely
wasn't possible (predates this log, no diff trail survives).

## 146 Scotts Road, Darra QLD 4076

| Version | Rendered | Context snapshot | PDF | Sent to Josh (wacli msg ID) | What changed |
|---|---|---|---|---|---|
| v5 | 2026-08-06 | not preserved (predates this log) | not preserved | yes (see `trail-history.md`) | Header/footer chrome bug fix |
| v7/v8 | 2026-08-07 | not recoverable — session boundary lost the scratchpad before any diff trail was captured; v8's data was rebuilt from scratch for v9 rather than reconstructed | not preserved | v8 sent | Rebuilt to match "Variant A" reference (Georgia serif, real photos, Historical Lease Reference section) |
| v9 | 2026-08-07 | `outputs/146-scotts-road-darra/context-v9.json` — **backfilled 2026-08-07 from conversation history and verified**: re-rendered and text-diffed against the archived PDF, 0 differences (only the PDF's internal timestamp differs, as expected) | `outputs/146-scotts-road-darra/146-scotts-road-im-v9.pdf` | not sent (superseded by v10 same day) | Asking price filled ($4,500,000, from the 39 Railway Parade document); per-tenant rent left TBC on purpose (no confident mapping yet) |
| v10 | 2026-08-07 | `outputs/146-scotts-road-darra/context-v10.json` — **backfilled 2026-08-07 from conversation history and verified** the same way, 0 differences | `outputs/146-scotts-road-darra/146-scotts-road-im-v10.pdf` | text `3EB0FF4EC91F836FB7BE00`, file `3EB0422BEF6DB8B23EEA22` | Every remaining TBC filled with estimates mapped from the old six-lot schedule (see `trail-history.md` for the full mapping table); 5.77% estimated yield |
| v11 | 2026-08-07 | `outputs/146-scotts-road-darra/context-v11.json` (matches the PDF exactly — this is the current live state) | `outputs/146-scotts-road-darra/146-scotts-road-im-v11.pdf` | text `3EB07F67DE71753ECC665D`, file `3EB080956C032A3893DCFA` | Added "Shops 4 & 5 — whole building and land" messaging to cover, exec summary, property description, and investment highlights |

**Current state = v11.** If starting new work on this property, load
`context-v11.json` as the starting point, not any earlier version — and
immediately `cp` it to a new `context-v12.json` (or whatever the next
version is) before making any edits, so this table's next row has a real
snapshot to point to instead of another gap.
