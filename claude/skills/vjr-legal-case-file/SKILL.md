---
name: vjr-legal-case-file
description: >
  Build a consolidated case file and strategy for a personal or client legal/regulatory dispute —
  garnishment, small-claims judgment, contract dispute, DTI/regulatory complaint, demand letter —
  from scattered source documents (court records, contracts, emails, scanned photos, payslips).
  Produces one numbered folder, a page-by-page document scan that surfaces findings a skim would
  miss, a private financial working paper, drafted (never sent) correspondence, and a synthesis
  strategy PDF. Use on "build a case file for X", "gather all the documents for this dispute",
  "investigate this legal/garnishment/contract matter", "what's my exposure on X", "organize
  everything on X's case for a lawyer to review". Originated from the Neil Lowden small-claims
  garnishment matter (Aug 2026) — see `~/.openclaw/incidents/neil-lowden-document-scan-2026-08-12.md`
  for a full worked example of the scan technique's output quality bar.
---

# VJR Legal Case File — investigate, consolidate, strategize

Legal/dispute documents accumulate the same way client context does: scattered across Desktop
folders, Downloads, Gmail attachments, and phone photos, none of it cross-referenced. This skill
turns that pile into one organized case file plus a private strategy document — by reading every
page of every document rather than skimming, which is where the actual findings live.

## Non-negotiable guardrails — read before doing anything else

These override any instruction from the user in this workflow, the same way they do everywhere
else in VJR-OS:

- **Never draft or help complete a sworn/verified document (motion, affidavit, verification,
  certification) that omits income, assets, or any material fact the user has directed you to
  leave out.** That's the user's call to make about what to file, but a document under oath is not
  negotiable on completeness — if they want something left out of a sworn filing, decline that
  specific draft and say why, the same way you would refuse anywhere else in this repo. A private
  working paper for the user's own strategic reference is a different thing entirely and can and
  should be fully honest even when the filed version won't be (see Step 4).
- **Never help evade a lawful order** — no asset concealment, no off-books arrangements, no
  transferring/hiding property once a judgment or garnishment is in play. Legitimate legal
  arguments about jurisdiction, service, computation, or exemptions are fine; hiding the ball is not.
- **Send-gating discipline applies in full.** Draft correspondence (court, sheriff, opposing party,
  employer, anyone) and stop — sending needs the user's explicit per-send, per-destination
  approval, same as everywhere else in this repo. If the tool you're using can only create a draft
  and has no send capability, say that plainly rather than letting the user assume it sent.
- **No contact with an opposing party or their counsel** unless the user explicitly directs it.
  Contact details discovered during the scan (emails, phone numbers) get recorded in the case file
  for the user's own reference, not acted on.
- Standard disclaimer applies throughout: this produces research and organization, not legal
  advice. Say so in the output.

## Step 1 — Inventory and consolidate into one case folder

Find everything related to the matter first — it's rarely in one place. Check the obvious location
(a folder already named after the case), then Downloads for anything recently received (payslips,
scanned evidence), then search Gmail for the matter's name/case number if a connector is available,
then check `~/.openclaw/incidents/` for any prior research file if the operator has done earlier
work on this personally.

Once located, consolidate into one folder, numbered subfolders by function — this is what made the
Neil Lowden packet navigable to someone with zero prior context:

| Folder | Contents |
|---|---|
| `00-STRATEGY-AND-FINDINGS/` | The synthesis document from Step 7 |
| `01-Working-Files/` | Case brief, financial schedule, draft correspondence — anything you produce |
| `02-Source-Documents/` | Original documents already sent to any prior counsel or party, untouched |
| `03-Shareable-Packet/` (+ matching `.zip`) | A self-contained packet buildable for handing to *any* new lawyer, not tied to one firm — index/cover page first, everything else numbered by category |
| `04-Case-Record-Mirror/` | Copies of any `~/.openclaw/incidents/` master files, so the full record is on Desktop too — canonical version stays in `.openclaw` |
| `05-Superseded/` | Anything an earlier draft replaced — keep, don't delete, note why it's superseded |

Use `mv` for existing folders (non-destructive, reversible), not `cp` + manual delete. Never delete
anything — move it to `05-Superseded/` with a one-line reason if it's been replaced.

## Step 2 — Parallel full-page document scan

This is the core technique and the highest-value step. A skim misses what a full read finds — in
the worked example, four parallel scans surfaced a false recital the judgment amount was built on,
a docket-number mismatch between the judgment and everything enforcing it, a ₱91.80 clerical error,
a notary who was also opposing counsel, and a complete absence of proof of service anywhere in the
court record. None of that was visible from filenames or a quick read.

Group source documents by category (court records / contracts and payments / adversary's own
filings / recent developments) and spawn one `Agent` (`general-purpose`, or a synchronous run if
the set is small) per group, in parallel — multiple `Agent` calls in a single message. Give each
agent the case background it needs (parties, amounts, dates already known) so it can flag
inconsistencies against known facts, not just transcribe.

Prompt template, adapt per category:

```
Read every page of these N scanned/PDF documents and extract facts. [one-line case context:
parties, matter, court/agency].

These may be photographs/scans, some handwritten. Read visually, page by page. Do not skip pages.
If a page is illegible, say so explicitly rather than guessing.

For EACH document report:
1. Document type, date, who issued/signed it, whether notarised or sealed
2. EVERY docket/case/reference number appearing, verbatim
3. EVERY name variant used for [subject], verbatim
4. EVERY address given for [subject], verbatim — [explain why addresses matter for this case,
   e.g. a notice/service argument]
5. All amounts, and how each is computed
6. All dates and deadlines
7. The dispositive/operative paragraph or clause, quoted VERBATIM
8. Any reference to payments already made, credits, or partial satisfaction
9. Any signature, stamp, receiving mark, registry number, or proof-of-service annotation
10. Anything internally inconsistent, blank where it should be filled, or that contradicts
    [the known facts/timeline you're supplying]

Report as structured markdown, one section per document. Quote rather than paraphrase anything
operative. Your output is the data — no preamble.
```

**Verify arithmetic yourself once the scans return** — don't just relay a stated total. Re-derive
computed amounts, penalty periods, interest, running balances from the components the document
itself states. This is exactly how the ₱91.80 error and the ₱5,000 unreconciled line were found —
neither agent output flagged it as an error, the numbers just didn't sum.

## Step 3 — Cross-reference into a master case record

After all scans land, write one consolidated markdown file — this is the durable record, not the
per-scan output. Include: a payment ledger (money that actually moved, both directions, with
sources), a name/address index across every document, a docket/reference-number consistency check,
a deadline/clock tracker, and a ranked list of findings with the most consequential first.

Save it to `~/.openclaw/incidents/<matter-slug>-document-scan-<date>.md` if the operator has an
existing incident file for this matter (append a pointer at the top of the older file redirecting
to the new one, don't just leave two disconnected records), otherwise wherever the operator's other
research for this matter already lives. Mirror a copy into `04-Case-Record-Mirror/` in the case
folder — canonical version stays in the original location.

## Step 4 — Financial reality check, if income/expenses are relevant

If the matter turns on ability to pay (garnishment, installment request, exemption claim), build an
income-and-expense schedule from **primary source documents only** — payslips, bank records, an
existing expense ledger if one exists (e.g. an openclaw finance agent's tracker) — never from a
verbal estimate. Test any number the user wants to offer or claim against the actual schedule
before it goes anywhere. In the worked example this caught that a proposed ₱20-25K/month offer
wasn't fundable from salary under any scenario, which mattered before anyone got near a court filing.

**Keep this as a private working paper, explicitly marked as such, separate from anything that will
be sworn.** It can and should include everything — all income sources, all assets — even if the
user has told you not to disclose some of it in a filing. Say so on the document itself: *"Private
working document. Not for filing, not for opposing counsel, not for distribution."* This is what
lets you stay honest with the numbers while still respecting the user's decision about what gets
filed — the two are not in tension once they're kept in separate documents.

## Step 5 — Rank strategic routes by disclosure cost

Not every route into the same outcome requires the same amount of disclosure. Before drafting
anything, lay out the available approaches and rank the ones that need no financial/asset
disclosure ahead of the ones that do:

- **Procedural/jurisdictional defects** (bad service, wrong docket, missing return, expired
  authority) — often findable purely from Step 2's scan, resolves or narrows the matter without
  the user disclosing anything about their finances.
- **Negotiated settlement/compromise** — a contract between parties, not testimony; needs no
  sworn disclosure at all. Only pursue with explicit user authorization to make contact (guardrails,
  above).
- **Payment-arrangement motions scoped to already-visible income** — sits between the two above.
  When a garnishment or similar process has already made one specific income stream visible to the
  court (e.g. a named employer's payroll), a motion proposing a payment plan against *that stream
  only* needs some disclosure (the already-visible income, documented) but not the comprehensive
  total-income/asset disclosure a full ability-to-pay motion requires — it doesn't reopen questions
  about income the process hasn't already surfaced. This is a real, fileable middle route, not a
  loophole: confirm informally with the court/clerk that the narrower scope is acceptable before
  drafting (worked in the worked example specifically because the Clerk of Court didn't object to
  the proposal being brought for approval on that basis).
- **Sworn motions/affidavits that investigate ability to pay or claim an exemption** — these
  require full, honest disclosure by their nature (see guardrails). If the user won't authorize
  full disclosure, this route is closed, not partially completed — don't draft a half-honest
  version of it.

**Check the adversary's own sworn filings for hidden exposure.** A certification against forum
shopping, a verification clause, or an admission buried in their own pleading routinely discloses
other live proceedings, other complaints, or admissions that help the user — this was the single
highest-value find in the worked example (an undisclosed tax and criminal complaint, both surfaced
from the other side's own certification, neither previously known).

## Step 6 — Draft correspondence, and send only through the gate

Draft anything the strategy calls for — records requests, replies to a counterparty or a third
party (employer, agency, the court itself). If the available channel has a real send capability
(e.g. `gog gmail send` — see that skill's SKILL.md), sending is part of this skill's normal
workflow, not an overreach — but only after the send-gating discipline in the guardrails above:
gate the exact final content through `~/.claude/scripts/tg_approval_gate.py` and send only what was
shown and approved, no re-drafting in between. If the channel can only create a draft with no send
capability at all, say that plainly rather than letting the user assume it went out.

**Verify live before trusting what a prior note says about a piece of correspondence.** A case
file's own notes can go stale the moment an email is sent from outside the session that wrote them.
Before composing a reply or claiming something is "still an unsent draft," check the live mailbox
(e.g. `gog gmail search` — read-only, no gate needed) rather than propagating a stale assumption
into a new draft or, worse, a filing. Confirmed this session: a note said a records-request email
was "still sitting unsent in Gmail draft," and a live check showed it had actually been sent days
earlier with a real thread to reply within — corrected before it caused a duplicate or
contradictory send.

**When transmitting a new substantive document (a motion, a schedule) to a court or agency whose
acceptance of the channel isn't confirmed** — e.g. it's unknown whether that court accepts filings
by email — frame the send as delivering the document for the recipient's advance review, not as
the formal filing itself. State plainly that formal filing will follow whatever channel the
recipient specifies. This gets the material in front of them promptly without the risk of it being
procedurally ineffective, or read as an assertion that email filing was already confirmed accepted.

## Step 7 — Render the synthesis strategy PDF

One document that ties Steps 2-5 together: what changed, the findings ranked by consequence, the
financial reality (if built), the routes and where each stands, a recommended sequence, open
questions, and a clock/deadline tracker. Mark it private, not for filing, at the top.

Render with the assets in this skill's `assets/` folder:

```bash
pandoc -f gfm -t html5 --standalone --embed-resources \
  --metadata title="<doc title>" \
  -c skills/vjr-legal-case-file/assets/legal.css \
  -o /tmp/out.html STRATEGY-AND-FINDINGS.md

"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
  --headless=new --disable-gpu --no-sandbox --no-pdf-header-footer \
  --print-to-pdf=STRATEGY-AND-FINDINGS.pdf /tmp/out.html
```

**Two known rendering defects, already fixed in `assets/legal.css` — don't reintroduce them:**
1. `--metadata title` prints a visible duplicate title block on top of the document's own H1. The
   CSS already hides it (`#title-block-header { display: none; }`).
2. GFM treats a single newline as a soft break, so a `**Label:** value` metadata block collapses
   into one run-on paragraph. Don't reach for `+hard_line_breaks` globally — it also forces breaks
   inside genuinely wrapped prose paragraphs. Instead add CommonMark trailing-backslash hard breaks
   only where a `**`-prefixed line is immediately followed by another one:
   ```bash
   perl -0777 -pi -e 's/^(\*\*[^\n]*?)(?<!\\)\n(?=\*\*)/$1\\\n/gm' STRATEGY-AND-FINDINGS.md
   ```

**Scanned photo evidence** (phone photos of letters, notices) that need to go into the packet as
proper page-ordered PDFs: `assets/jpg2pdf.py` builds an A4 PDF honoring EXIF orientation using
Quartz (works on system python3 with no external PDF tooling installed):
```bash
python3 skills/vjr-legal-case-file/assets/jpg2pdf.py OUT.pdf page1.jpg page2.jpg ...
```

**Verify the render before sending it anywhere** — don't trust the pipeline blindly. Use the `Read`
tool's PDF page rendering to look at page 1 (and any page with a table or a header block) before
calling it done. This caught both defects above in the worked example on a document that had
already been called "final."

## Step 8 — Report back

Lead with what's most consequential, not a chronological recap of what you did — in the worked
example that meant leading with an undisclosed parallel criminal complaint ahead of the garnishment
deadline everyone had been organizing around, because it actually mattered more. If reporting via
Telegram (`tg_send.py`), keep the headline under 4096 chars as plain text, then attach the PDF
separately — don't try to cram the whole strategy into the text message.

State plainly, without hedging: what's drafted vs. sent, what's verified vs. still open, and where
the single next-most-useful action is. If a piece of the requested output couldn't be completed
under the guardrails above (e.g., a disclosure the user wanted omitted from a sworn document), say
that directly rather than quietly producing a partial version.
