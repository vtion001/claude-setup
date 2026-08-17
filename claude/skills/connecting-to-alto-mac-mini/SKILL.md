---
name: connecting-to-alto-mac-mini
description: Use when the user asks to connect to, check, validate, or fix something on Joshua Kim's / ALTO Property's Mac-mini-2 (the machine running joshua-openclaw and alto-mission-control) — including phrases like "check Joshua's computer", "SSH into Joshua's machine", "validate Phase 4/5 live", "is the calendar/reporting/dashboard actually running", "check outreach campaigns", "analyze/enrich contacts from Rex/email/iMessage", or "check/set/reset the RustDesk password".
---

# Connecting to ALTO's Mac-mini-2 (Joshua Kim's machine)

## Overview

Joshua Kim's Mac-mini-2 (hostname `ALTOs-Mac-mini-2.local`) runs the client-delivered
automation for the ALTO Property contract: `joshua-openclaw` (Phase 4 business automation)
and `alto-mission-control` (Phase 5 dashboard). It's reachable directly over Tailscale —
no RustDesk/TeamViewer needed if the operator's machine is already on the tailnet.

## Connecting

```bash
ssh altoproperty@100.114.165.87        # user is "altoproperty", NOT "joshua"
# or, if Tailscale MagicDNS resolves it:
ssh altoproperty@alto-mac-mini
```

**First connection (or periodic re-check) prints:**
```
# Tailscale SSH requires an additional check.
# To authenticate, visit: https://login.tailscale.com/a/xxxxxxxx
```
This is Tailscale SSH check-mode — it is re-authenticating the operator's own Tailscale
identity (`vtion001`, which owns every device on this tailnet, including Joshua's). It has
nothing to do with Joshua — he doesn't need to be at his machine or click anything. Tell the
human partner to open that URL in their own browser, signed into their own Tailscale account.
If a command hangs on this line, it's waiting on that approval — background it, surface the URL,
and retry once they confirm.

## Repo locations on that machine

| Repo | Path | Remote |
|---|---|---|
| `joshua-openclaw` (Phase 4 automation) | `/Users/altoproperty/.openclaw` | `github.com/vtion001/joshua-openclaw` |
| `alto-mission-control` (Phase 5 dashboard) | `/Users/altoproperty/.openclaw/services/mission-control` | `github.com/vtion001/alto-mission-control` |

Trap: `/Users/altoproperty/.openclaw/workspace/skills/mission-control` is a same-named
decoy — it has no `.git` of its own, so `git -C` commands there silently traverse up to the
`joshua-openclaw` parent repo and report its branch/commit instead. Always confirm with
`ls -la <path>/.git` before trusting `git remote -v` output from a "mission-control" path.

Service networking quirk: the mission-control FastAPI backend binds the tailnet IP
(`100.114.165.87:18793`), not `127.0.0.1` — `curl localhost:18793` returns `000` even from
on-box. Always curl the tailnet IP.

## Repo state vs running state — always check both

A merged/current git HEAD does not prove the live service reflects it. Cross-check the running
process's start time against the latest relevant commit:

```bash
launchctl list | grep <job-name>                          # PID in first column = running
ps -o lstart=,pid= -p <PID>
git log -1 --format="%ad" --date=format:"%Y-%m-%d %H:%M" -- <relevant-path>
```

If the process started before the commit, the code isn't live yet (needs a restart) — report
that as a pending deploy step, not a PASS. Frontend builds are static files (`frontend/dist/`);
check the `dist/` mtime against the latest `frontend/src` commit instead of requiring a rebuild —
if they already match, the build is current and no action is needed.

## RustDesk (fallback remote access)

This machine also runs a self-hosted RustDesk server (hbbs/hbbr) for GUI-level remote
access when Tailscale SSH isn't enough (e.g. a one-time Accessibility/consent dialog
needs a physical click). **Read `rustdesk.md` in this skill's directory before touching
RustDesk's password or its hbbs/hbbr server setup** — it covers where the permanent
password actually lives (not where you'd guess), why CLI flags spawn duplicate GUI
processes, why hbbs/hbbr must run as native LaunchAgents and never via Docker/Colima on
this machine (a real bug, not a preference), and the exact recovery steps if registration
ever breaks again.

## Safety boundary (hard rule)

This is a live client system in active use. Unless the human partner gives explicit
go-ahead in that specific session:
- Do not flip a disabled skill/feature flag to enabled
- Do not register a new cron job
- Do not restart a live service
- Do not send anything — Telegram, email, SMS, or otherwise

Read-only and dry-run actions are always fine without asking again: unit tests, `curl` GETs
against local/live endpoints, `openclaw cron list`, `grep`, scripts that are documented as
generation-only or dry-run. When reporting results, say plainly which checks were read-only and
which would require a live flip — don't blur the two.

## Quick reference — the standing validation checks

```bash
# Phase 4: reporting-generator (generation-only, sends nothing)
cd /Users/altoproperty/.openclaw/workspace/skills/reporting-generator
python3 scripts/test_reporting_generator.py
python3 scripts/generate_report.py --type weekly --format both

# Phase 4: calendar (reads calendar, sends nothing)
python3 -c "import json;e=json.load(open('/Users/altoproperty/.openclaw/openclaw.json'))['skills']['entries'];print(e.get('calendar-manager',{}).get('enabled'))"
PATH=/opt/homebrew/bin:$PATH openclaw cron list | grep -i calendar
python3 /Users/altoproperty/.openclaw/workspace/skills/calendar-manager/scripts/check_and_notify.py

# Phase 4: email handler
PATH=/opt/homebrew/bin:$PATH openclaw cron list | grep -i lead-digest

# Phase 5: exec scorecard + the 3 security criticals
cd /Users/altoproperty/.openclaw/services/mission-control/backend
python3 test_exec_summary.py
curl -s http://100.114.165.87:18793/api/exec/scorecard | python3 -m json.tool
curl -s -o /dev/null -w "%{http_code}\n" -H "Tailscale-Funnel-Request: 1" http://100.114.165.87:18793/api/overview
grep -n "run_in_threadpool" app.py
grep -n "STREAM_TIMEOUT_S\|start_new_session\|finally" amanda.py

# Outreach: campaign state + contact analysis (Rex + email + iMessage, read-only + local cache write)
sqlite3 -readonly /Users/altoproperty/.openclaw/workspace/skills/outreach-engine/data/outreach.db \
  "SELECT id,active,template_set FROM campaigns"
curl -s 'http://127.0.0.1:18792/correspondence?days=365' | python3 -m json.tool   # headless email scan
cd /Users/altoproperty/.openclaw/workspace/skills/outreach-engine/scripts
python3 contact_analysis.py --max-contacts 50 --no-write    # fast preview, writes nothing
python3 contact_analysis.py                                  # full ~30k-contact run (~4-5 min), writes data/contact_analysis.json
python3 metrics.py --campaign <id>                            # reply-rate is now event-filtered (fixed 2026-08-12) — trust it, but
                                                                #   sanity-check anything over ~30-40% anyway (see gotchas below)
python3 verify_batch.py --campaign <id> --since <date> --expected-max-age-days <N>
                                                                # MANDATORY before citing any batch as "recent"/"clean"/"ready" —
                                                                #   see "Numeric integrity" section below
```

## Numeric integrity — READ BEFORE citing any outreach-engine count as fact

**This has caused two real incidents** (metrics.py's 86.2% "reply rate" that
was actually opens/clicks, 2026-08-12; `intake_rex.py`'s 1,425 leads
described as "recent" when they spanned Jan-Aug 2026 and 85%+ were already
`Completed` in Rex, 2026-08-13) — both technically-real numbers wrapped in a
false characterization, which is more dangerous than an obviously wrong
number because it doesn't trigger suspicion on its own. Full protocol +
both incident writeups: `references/numeric-integrity-checklist.md` on the
Mac-mini. The short version, non-negotiable before any count/rate/date-range
from this pipeline reaches the user or Josh:

- **Never characterize a batch from its count alone.** Run
  `scripts/verify_batch.py --campaign <id> --since <date> --expected-max-age-days
  <N>` (or `--lead-ids <ids>` for a specific set) before calling any lead
  batch "recent"/"clean"/"ready" — it samples evenly across the FULL range
  (not just the first N, which hides exactly this bug), checks each
  sample's real Rex date/status/listing live, and hard-FAILs with a clear
  banner when reality contradicts the claim.
- **A script edited minutes before a live run might not be the version that
  ran.** Check timing, don't assume current-on-disk == what-executed.
- **Re-verify fresh in the same turn before anything reaches Josh** — don't
  reuse a number from earlier in the conversation; state changes (1,425
  enrolled → 82 suppressed → 1,343 active all happened within one session).

## Outreach-engine gotchas (Rex / email / iMessage correspondence)

Discovered and fixed 2026-07-23 while building `contact_analysis.py` — the same
issues will resurface in any future script that touches this same path.

- **`rex.py`'s `_client` is an instance, not a factory.** `workspace/skills/
  rex-crm/scripts/rex.py` reassigns its own module-level `_client` name to an
  already-logged-in `RexClient` instance at import time (bottom of the file:
  `_client = _client()`). Any caller doing `from rex import _client;
  _client()` gets `TypeError: 'RexClient' object is not callable` — the
  correct form is just `c = _client`, no second call. This bug was systemic,
  not a one-off: as of 2026-07-24 it was found and fixed in **all 7** scripts
  that import `rex._client` this way — `pipeline_discovery_cli.py`,
  `import_rex_dnc.py`, `listing_gate.py`, `response_validation.py` (outreach-
  engine), and `normalize_and_match.py`, `patch_rex_matches.py`,
  `rex_apply.py` (rex-crm). If a NEW script imports `from rex import
  _client`, check it isn't calling `_client()` again — grep
  `from rex import _client` across both skills' `scripts/` dirs to find every
  live instance before assuming this is fully closed out.

- **himalaya (email CLI) silently returns zero correspondence over SSH** —
  it can't reach the macOS keychain headlessly (`security
  find-generic-password ... exit status code 44`), and the calling code
  swallows the error, so you just see `email keys: 0` with no visible
  failure. Confirm with `himalaya envelope list -s 5 -o json -f INBOX`
  directly if a run looks suspiciously empty. **Fix**: `inbox-api` already
  holds a live, keychain-independent IMAP connection (plain `IMAP_HOST`/
  `IMAP_USER`/`IMAP_PASSWORD` env vars, not the keychain) — it exposes `GET
  /correspondence?days=N` for exactly this (added 2026-07-23,
  `services/inbox-api/sources/email.py` + `main.py`). This account's real
  Sent folder is `[Gmail]/Sent Mail`, not `Sent`/`Sent Items`/`INBOX.Sent` —
  don't assume, use `mailbox.folder.exists()` per candidate. Fetch in bulk
  (`headers_only=True, bulk=200`) — a naive per-UID FETCH loop timed out at
  300s scanning a year of mail; bulk fetch does the same scan in ~90s.

- **`imsg` needs Full Disk Access on the invoking process, not Messages.app**
  — granting FDA to Messages.app does nothing; it must go to the actual
  terminal/launcher handling the SSH session. Even once granted, the FIRST
  `imsg` call can hang indefinitely (zero output, near-zero CPU — check `ps
  aux | grep imsg`, don't assume it's just slow) if a one-time interactive
  consent dialog is silently waiting on the physical screen. Nothing to fix
  in code — RustDesk/TeamViewer in and click Allow once; every call after
  that works fine over plain SSH.
  **Fast diagnosis (found 2026-08-12):** don't guess or re-run `imsg` live to
  test — check `meta_json` on the FAILED `touch_log` rows first,
  `dispatch_imessage.py` stores the real error there: `SELECT meta_json FROM
  touch_log WHERE channel='imessage' AND body LIKE 'FAILED:%' LIMIT 5`. A
  live confirmed instance: `rex-reengage-2026`'s entire T1 batch (171/171)
  failed on `"authorization denied (code: 23) ... requires Full Disk
  Access"` — the scheduler's own process never had FDA granted, not a
  one-off flake. If you do run a live `imsg send ... --json` probe to
  confirm currency, it's a genuine send attempt (not a dry-run) — only point
  it at a real test/throwaway number, and expect it to hang/timeout the same
  way if FDA is still missing (confirmed: it timed out with a *different*
  symptom, `AppleScript ... AppleEvent timed out (-1712)`, and sent nothing —
  don't assume a different error text means a different root cause).

- **Full contact analysis** combines Rex tags (same account as
  `scripts/rex-enrich` on the website side, so its already-applied tags —
  `Buyer`, `Vendor`, `Spoken With`, etc — show up here for free), real
  email/iMessage correspondence, and local `leads` pipeline state, into
  `data/contact_analysis.json`. Read-only against Rex/email/iMessage; the
  only write is that local cache file.

- **`metrics.py`'s reply-rate was counting opens/clicks/spam-reports as
  replies — fixed 2026-08-12.** `touch_log.direction='inbound'` covers far
  more than genuine replies: `meta_json.event` can be `open`, `click`,
  `delivered`, `spamreport`, `stop`, `reply`, or `reply_negative` (checked
  live: `SELECT channel, direction, json_extract(meta_json,'$.event'),
  COUNT(*) FROM touch_log GROUP BY 1,2,3`). The old query counted all of
  them as a "reply", which is how `rex-reengage-2026` showed an 86.2%
  touch-2 "reply rate" (real breakdown: 178 opens, 26 clicks, 2 spam
  reports, **0 genuine replies**) — implausible on its face; any reply rate
  over ~30-40% for cold/dormant real-estate outreach should be treated as
  suspect until the event breakdown is checked. Fixed in
  `scripts/metrics.py` by filtering to `event IN ('reply','reply_negative')`
  for the top-level `replies`/`repliers` counts and the per-touch tally
  (opt-out body-text detection still scans the full inbound set — that part
  was already correct). **Known limitation, not newly introduced:** the
  email channel has no genuine-reply event at all in this schema yet
  (SendGrid inbound-parse isn't wired to tag one) — post-fix, email replies
  correctly read as 0 rather than silently double-counting engagement
  events; that's honest, not a regression. Backups of the pre-fix
  `outreach.db` and `metrics.py` sit alongside the originals
  (`*.bak-2026-08-12*`) if a rollback is ever needed. If a future session
  sees a suspiciously high reply rate on ANY campaign, re-run the event
  breakdown query above before trusting the number — the bug's fixed, but a
  new event type showing up unfiltered someday is the same failure mode.

- **`intake_rex.py` was structurally stuck on a 7-9-month-old page —
  fixed 2026-08-13.** It called `rex.sh leads --limit N` / `rex.sh contacts
  --limit N` with no date filter and no offset tracked between runs, so
  every single invocation re-fetched the exact same page (Rex's default
  sort, offset 0) no matter how many times it had already run. Confirmed
  live: the "leads" page it kept returning was from Dec 2025-Jan 2026
  while 142 genuinely new Rex leads had piled up in the last 30 days alone,
  completely untouched — this, not a lack of enquiries, is why
  `rex-default-nurture` looked "dry" (see the 2026-08-12 snapshot below,
  now superseded). **Fixed** by adding a persisted cursor per
  `(endpoint, campaign)` in the `sync_state` table (`source =
  "rex-intake:leads:<campaign>"`, `last_cursor` = highest `system_ctime`
  ingested) and real pagination via a new `rex.sh leads --since-ctime
  EPOCH --offset N` flag. **Field-name gotcha found while building this:**
  the correct searchable field is `system_ctime`, NOT `lead.system_ctime`
  (which is what `search_leads()`'s own docstring in `rex_client.py`
  claims) — the wrong name 400s with `InvalidFieldException`. Don't trust
  that docstring; if you need another Rex date/field filter, call
  `c.describe_model('Leads')['result']['searchable_fields']` live and read
  the real name off that, the same way this was diagnosed. First-ever run
  for a campaign has no cursor yet — rather than defaulting to true zero
  (which would mean "every lead Rex has ever recorded," a full CRM-history
  backfill blasted out as live personal touches), the seed is `--backfill-
  days` (default 45) before now. **Also changed:** the `contacts` endpoint
  (Rex's full address book, not enquiry events) is now OFF by default —
  polling it unfiltered previously surfaced a law-firm/solicitor contact,
  a "General Account" placeholder, the operator's own dev/test entry, and
  a dense block of ~100 sequential-ID records that looked like a single
  historical bulk import, none of which belong in a personal buyer-nurture
  cadence. Opt in with `--include-contacts`; treat its output as a
  manual-review list, not an auto-enrol source. Originals backed up
  alongside (`rex.py.bak-2026-08-13`, `intake_rex.py.bak-2026-08-13`).

- **This is a live multi-actor box — a script you're mid-editing can get
  run by someone/something else before you're ready.** While dry-run-testing
  the `intake_rex.py` fix above (every invocation of mine used
  `--dry-run`), a *different* already-open session on the box (logged in
  since Jul 31 from a separate Tailscale peer, confirmed via `last`/`who`
  — not something I initiated) picked up the newly-deployed script and ran
  it live, enrolling 1,425 real leads into `rex-default-nurture` before I'd
  gotten a chance to run the standard pre-launch suppression check myself.
  No harm resulted (the leads were genuinely legitimate; `next_touch_at`
  landed a full day out so nothing sent), but it's a real risk pattern
  worth flagging: deploying a fix onto a live path on this box doesn't wait
  for you to say "ready" — check `who`/`last` for other active sessions
  before assuming your own dry-run testing is the only thing that can
  touch a script you just `scp`'d into place.

- **`run_rex_nurture.py`'s tick already runs the live Rex DNC sync every
  30 min — it's a real safety net, not just a manual pre-launch step.**
  Confirmed 2026-08-13: a dry-run `import_rex_dnc.py --campaign
  rex-default-nurture --dry-run` found 82 leads needing suppression; by
  the time the follow-up **live** run executed (a few minutes later), it
  suppressed **0** — because `run_rex_nurture.py`'s own scheduled tick
  (which unconditionally calls `import_rex_dnc.sync_dnc()` at the start of
  every run, live, for whichever campaign it's scoped to) had already fired
  in between and done it for real. Don't read "suppressed 0" as a bug or
  as "the dry-run was wrong" — cross-check the flagged lead IDs' current
  `state` and the runner's `worker_health.last_run_at` timestamp before
  concluding either way; in this case both confirmed the tick beat the
  manual run to it, not that DNC sync silently failed.

- **A background Rex-per-lead loop (DNC sync, contact analysis, etc.) is
  genuinely slow, not stuck — budget up to ~1 hour for ~1,400 leads.**
  `import_rex_dnc.py`'s loop does up to 2 Rex API calls per lead with no
  visible progress output until the very end; low CPU time (a few seconds
  of TIME against 20+ minutes of ELAPSED) is expected for a network-I/O-
  bound loop like this, not a hang — confirm it's alive via `lsof -p <pid>
  | grep tcp` (an ESTABLISHED connection means real work, not a stall) and
  trust `ps -o etime= -p <pid>` over your own sense of how much wall-clock
  time has passed while waiting on it.

- **`campaigns.active` used to be a label, not a switch — FIXED 2026-08-14.**
  Found while explicitly stopping `rex-default-nurture` on request: the DB
  showed `active=0`, but 1,344 leads were still armed with `next_touch_at`
  set for that same day — `scheduler.tick()` (the real chokepoint every
  runner/CLI passes through) never checked `campaigns.active` at all. Each
  campaign's actual on/off switch was whatever its own dedicated launchd job
  happened to be doing (`ai.openclaw.rex-nurture-runner`, `reengage-runner`,
  etc.) — confirmed the exact same root cause as the `rex-reengage-2026` spam
  complaints on 2026-08-02 ("someone disabled outreach-engine in the config...
  but this specific campaign runs through its own separate scheduled job, so
  the disable did nothing to it," per the ALTO Property Business Development
  WhatsApp thread). Immediate fix that day: `launchctl bootout
  gui/$(id -u altoproperty)/ai.openclaw.rex-nurture-runner` — confirmed via
  `launchctl list` + `ps` that nothing was scheduled or running afterward.
  **Structural fix, same day:** `scheduler.tick()` now checks
  `campaigns.active` before ever querying due touches — a paused campaign
  returns `{"considered": 0, "sent": 0, "skipped_inactive": [...]}}` before
  touching anything, verified with zero write side effects against the real
  DB via a `mode=ro` connection. Covered by `test_tick_active_gate.py`
  (new) plus the two pre-existing `test_tick_*.py` files (still pass, no
  regression). **From 2026-08-14 onward, flipping `campaigns.active` to 0 is
  genuinely sufficient on its own** — no need to separately hunt down and
  unload a launchd job. Backup of the pre-fix file:
  `scheduler.py.bak-2026-08-14`.

## Buyer-nurture canonical cadence (Jovet-approved, verify against the DB not the JSON)

`rex-default-nurture`'s live cadence is the 3-touch sequence Jovet (a team
member, WhatsApp group "ALTO Property Business Development") proposed
2026-07-08 to replace an older 7-touch enquiry sequence. **Verified against
`campaigns.template_set` in the live DB (`rex-buyer-nurture`) and real
`touch_log` sends — not from the campaign's own JSON file, which is stale
(see gotcha below).**

| Touch | Offset | Channel | Purpose |
|---|---|---|---|
| T1 | Day 1 | **iMessage** (`imsg`, from Josh's own Apple ID/Mac — since 2026-07-24; was Twilio SMS before) | Personal follow-up on the enquiry, offer to answer questions / arrange inspection |
| T2 | Day 5 | Email | Invite to the Buyer Offer Form (`form.jotform.com/ALTO_Property/buyerform`) |
| T3 | Day 14 | Email | Invite to the Buyer Preferences Form (`form.jotform.com/261241541688055`) |

Day 0 (the auto-enquiry-response email with brochure/docs) is a **separate**
pre-existing automation, not part of this 3-touch sequence.

**Two explicit requirements from Jovet — both now shipped as of 2026-07-24:**
1. **Stop on engagement** — sequence ends the moment a lead replies, completes
   either form, or enters an active sales process. Wired via
   `scheduler.py`'s `stop_conditions.stop_engaged_leads`.
2. **Listing-gate scope** — narrowed to *only* `sold`/`withdrawn` blocking
   property-specific touches (`listing_gate.py`'s `BLOCKED_STATES`) — Jovet's
   07-10 ask ("under contract/offer sometimes we still want to keep getting
   offer enquiry") was unshipped until 2026-07-24, now fixed + TDD'd
   (`test_listing_gate.py`).

**T1's iMessage channel** — `dispatch_imessage.py` (new, mirrors
`dispatch_sms.py`) wraps `imsg send --service auto`, which sends iMessage
(blue) when the recipient supports it and silently falls back to SMS (green)
otherwise — same behavior real Messages.app always has, so switching T1 off
Twilio isn't a reach regression. Wired into `scheduler.py` as a full channel
(`"imessage"`): its own daily cap in `throttle.py` (`CHANNEL_CAP_DEFAULTS`,
`OUTREACH_IMESSAGE_CAP` env override), shares SMS's quiet-hours window and
per-tick burst budget (same "personal text, don't send at 11pm" concern).
`run_rex_nurture.py`'s LaunchAgent (every 30 min, already live-mode for
itself) picks up and sends any due T1 touch via this path automatically —
there's no separate "enable" step once `touches.json`'s channel field says
`"imessage"`.

**Gotcha — neither the campaign JSON file nor the DB's own `template_set`
column can be trusted blindly; verify against actual sent body text.**
`campaigns/rex-default-nurture.json` still says `"template_set":
"rex-enquiry-nurture"` (the old cadence) — a one-off cutover script
(`cutover_buyer_nurture.py`, 2026-07-09) repointed the DB row directly to
`rex-buyer-nurture` and the JSON file was never re-synced. **Confirm the
live cadence with `sqlite3 ... "SELECT id, template_set FROM campaigns"` —
never trust the JSON file's `template_set` field on its own.**

That said, the DB column itself can *also* drift from reality — found
2026-08-12 on `rex-reengage-2026` and `rex-discovery`: both showed
`template_set='default-7touch'` (a generic comp/festival sequence) in the
`campaigns` table, but the actual sent iMessage/email body text
(`SELECT body FROM touch_log WHERE channel='imessage' AND direction='outbound'
LIMIT 1`) matched `templates.json`'s `reengage-dormant`/`reengage-discovery`
sets word-for-word instead — purpose-built sets that already existed under
those exact names but were never wired into the campaigns row. **The only
fully reliable check is comparing real sent `touch_log.body` against
`templates.json`, not any stored label** — both the JSON file and the DB
column are just metadata that can go stale independently. Corrected via
`UPDATE campaigns SET template_set=... WHERE id=...` on 2026-08-12
(`rex-reengage-2026` → `reengage-dormant`, `rex-discovery` →
`reengage-discovery`) — a pure label fix, no behavior change, since that's
what was already running.

**Pipeline state as of 2026-08-12 (SUPERSEDED — see 2026-08-13 below, kept
for history):** every campaign had gone dry — no fresh lead enrollment
anywhere in 19-48 days, no scheduled enrollment job exists on this machine
at all (every batch to date has been a manual one-off). `rex-default-nurture`
(the live buyer-nurture cadence above) had zero leads left in new/active —
all original 180 had already completed/opted-out/gone-hot. `rex-discovery`
had 127 leads sitting untouched (`sent=0`) since 07-14, DNC-checked clean.
`rex-reengage-2026` had 52 leads frozen mid-cadence (campaign `active=0`)
since ~08-03, and 100% of its iMessage T1 sends had failed on the FDA issue
above. See the `outreach-campaign-brief` skill's 2026-08-12 brief
(`brief-2026-08-12-refill-pipeline.pdf`) for the full evidence-backed
write-up — the root cause it flagged as "no scheduled enrollment job" was
half the story; the other half was the `intake_rex.py` stale-cursor bug
above, found and fixed the next day.

**Pipeline state as of 2026-08-13 (will go stale — re-check, don't
assume):** `rex-default-nurture` went from 0 active to **1,425 active**
in one live `intake_rex.py` run (see the "multi-actor box" gotcha above —
this happened outside a planned session, not as a deliberate large batch
decision). All 82 Rex-side-DNC leads among them are confirmed suppressed
(`opted_out`) via the automatic tick-level DNC sync. First touch for the
rest is due **2026-08-14 14:00 UTC** — the iMessage/FDA issue above is
STILL unresolved as of this writing (no `imsg` attempt since the
2026-07-25 failures), so unless that's fixed before the window, expect the
same FDA failure on this batch's T1 sends too. `rex-discovery` (127
DNC-clean idle leads) and `rex-reengage-2026` (52 frozen leads) were both
**explicitly paused** (`campaigns.active=0`) on 2026-08-13 pending a human
decision (launch/resume vs retire) — this was a deliberate stop, not an
oversight; don't resume either without asking first. `rex-default-nurture`
itself was left active/untouched — pausing it too wasn't requested and
would strand the 1,425 already mid-cadence.

**Personalization** — plan written 2026-08-13:
`references/personalization-implementation-plan.md` (outreach-engine repo
on this Mac-mini). Key finding: Rex already returns the real attached
property (address/suburb/photo) for most listing-enquiry leads via
`search_leads()`, completely unused in current templates ("the property"
instead of the real address) — higher-leverage than tag-based
segmentation and the plan's Tier 1. Also resolved: Rex's outreach-workflow
feature is called **Tracks** (`AdminTracks`/`TrackInstance`), not
"Campaigns" (that object is empty) — 24 stock lead-temperature templates
+ 4 ALTO-custom ones that read as transaction/settlement workflow, not
marketing; live per-contact track membership isn't queryable via this
API (no list/search on `TrackInstance`), so treat "who's actually on a
Rex track" as unverified without a UI check.

## Human-in-the-loop inventory — every outbound/irreversible mechanism, gated or not

Built 2026-08-13 in direct response to "check what we can put in human-in-loop" — the
full, evidence-checked inventory of every mechanism on this machine that can send
something to a real person or mutate a system of record, not a guess:

| Mechanism | External-facing? | Gated today? | Notes |
|---|---|---|---|
| `dispatch_email.py` / `dispatch_sms.py` / `dispatch_imessage.py` (campaign touches) | Yes | ✅ campaign-level `active`/dry-run flags + the pre-launch suppression check above | Adequate at the granularity these run at (batch campaign steps, not one-off individual messages) — no per-message approval, by design |
| `rex_writeback.py` | No (CRM record mutation, not a message to a person) | ✅ same campaign-level gating | Not really a "human in loop" candidate — it's a data sync, not a send |
| `wacli send` (WhatsApp, via `/wacli-msg`) | Yes | ✅ **per-message**, `tg_approval_gate.py` (Step 6 of that skill) | Already the gold-standard pattern this whole inventory is measured against |
| `gog gmail send` / `calendar create` (attendees) / destructive Sheets-Drive ops | Yes | ✅ **per-action**, same `tg_approval_gate.py` | See `~/.claude/skills/gog/SKILL.md` → Operational rules |
| `cma_intent.py`'s `send_cma_alert()` | No — internal Telegram ping to the ops team, not to a lead/client | N/A | It IS a human-in-loop notifier itself (alerts a human that a lead wants a CMA), not something that itself needs gating |
| **`email_drafts` / `inquiry_draft_gen.py`** | **Yes** | **❌ none — no push mechanism existed at all** | **The real gap.** 333 pending drafts, 0 ever pushed, 1 discarded (confirmed by direct query, 2026-08-13). This is the priority the operator flagged — closed by the email voice-training engine + `push_email_draft.py` below |

**Conclusion:** every OTHER outbound mechanism on this machine already has adequate
gating. The one genuine, unaddressed gap was email-reply drafting — closed below.

## Email voice-training engine + Drafts-folder push (built 2026-08-13)

Mirrors the `/wacli-msg` skill's Telegram-approval + voice-training pattern
(`~/.claude/skills/wacli-msg/SKILL.md`) for email, since `inquiry_draft_gen.py`'s
draft generation is currently a fixed MVP template (`_draft()` in that file — its own
docstring says "Phase 2 = LLM with lead history") and needs a real corpus of how
Joshua actually writes email before any LLM call can sound like him instead of a
generic real-estate bot. This is the "trainable engine for his /gog skills" piece —
lives alongside the outreach-engine pipeline (not literally inside `gog/`, since
Joshua's own `workspace/skills/gog/` on this machine is doc-only, no scripts dir) and
is documented here because this skill is where Mac-mini email/gog capability is
tracked.

**Pieces (all deployed to `outreach-engine/scripts/` on this machine, 2026-08-13):**

1. **`email_voice_engine.py`** — scrapes Joshua's real outbound (Sent-folder)
   messages via `inbox-api`'s `POST /correspondence/messages`, classifies each as
   green (candidate style evidence) / red (quarantined — em dash, or matches a known
   `inquiry_draft_gen.py` template phrase verbatim, or the exact body text is reused
   across 3+ different recipients) / neutral (default — most normal-register email
   lands here, unlike WhatsApp). **Key difference from the WhatsApp classifier:** a
   greeting + sign-off block is NORMAL for email and must NOT be treated as a red
   flag the way a "formal closer" is for WhatsApp — that rule doesn't port over.
   State: `data/email-voice-profile/state.json` + rendered `baseline.md`.
   **Validated against a real 44-message corpus, 2026-08-13 — found and fixed a
   worse bug than the WhatsApp engine's original em-dash issue, then hit a real,
   demonstrated ceiling on what regex alone can catch.** First live run: several
   "green" examples were not Joshua's own writing at all — a conveyancer's reply, a
   forwarded owner's message — because email threads embed OTHER PEOPLE's words
   inside something that's technically "outbound from Joshua's account," which a
   WhatsApp-style classifier has no concept of. Fixed via `strip_quoted_content()`
   (truncates at the first quote/forward boundary — not line-anchored, since
   inbox-api's snippets are already whitespace-collapsed to one line) plus
   `THIRD_PARTY_SIGNATURE_RE` (catches a "Name Name | Title" signature block).
   Re-run after both fixes: green dropped 7→5, red rose 9→14, confirming the fixes
   changed real classifications, not just documentation. **Residual, accepted
   limitation:** at least one first-name-only signature ("...Thank you Armando") and
   one ambiguous non-Joshua first name ("Cheers Tam") survived in the green bucket
   after both fixes — a bare first name isn't reliably distinguishable from Joshua's
   own sign-off by regex alone, and ALTO Property may have shared-inbox/delegate
   send patterns (other staff sending from `joshua.kim@` or an `ALTO Admin Team`
   persona) this script has no way to detect from text content. **Treat every
   `green` entry as a candidate needing a human who actually knows Joshua's writing
   to confirm it — not verified style evidence** — this is a stronger version of the
   WhatsApp precedent, not a relaxation of it.

2. **`push_email_draft.py`** — takes a `pending` row from `email_drafts`, gates it
   through Telegram approval, and on APPROVED calls `inbox-api`'s (proposed, not yet
   deployed — see below) `POST /drafts/push` to write the exact approved content into
   Joshua's own Gmail Drafts folder via IMAP APPEND. **Never live-sends** — there is
   no send-capable credential for `joshua.kim@altoproperty.com.au` anywhere in this
   system (himalaya needs the GUI keychain headlessly; gog has this account
   explicitly excluded per standing operator instruction — see
   `~/.claude/skills/gog/SKILL.md`). Landing it in his own Drafts folder for him to
   review and send with one click is the only safe "push." **Approval routing is
   Vincent, via Telegram** (his own explicit answer when asked who should approve
   outgoing drafts from Joshua's inbox).

   **Uses its own dedicated bot, NOT `@vjr_approval_bot`** — per explicit operator
   instruction 2026-08-13 ("make sure the human in loop inventory has its own
   telegram bot"), separate from wacli-msg's personal-voice bot and the Mac-mini's
   own pre-existing `@Peter_the_assistantbot` (send-only, no approve/decline button
   polling — see `workspace/skills/telegram-media/scripts/send.sh`). Config:
   `~/.telegram_outreach_approvals_config.json` **on the Mac-mini** (same JSON shape
   as `~/.telegram_approvals_config.json` — `bot_token`/`chat_id`) — **not yet
   created**, the operator is setting up the bot via @BotFather themselves; until
   that file exists, `push_email_draft.py` fails loudly rather than silently
   fall back to a different bot.

   **Real cross-machine gap found and fixed while wiring this up (2026-08-13):**
   the original design pointed at `~/.claude/scripts/tg_approval_gate.py`, which only
   exists on Vincent's LOCAL machine — `push_email_draft.py` runs ON the Mac-mini,
   where that path doesn't exist. Fixed by (a) adding a `--config <path>` flag to
   `tg_approval_gate.py` so it can point at any bot config, not just the default
   `@vjr_approval_bot` one, and (b) deploying a copy to the Mac-mini itself at
   `workspace/skills/telegram-media/scripts/tg_approval_gate.py`, alongside that
   machine's existing Telegram tooling (`send.sh`, `inbox.sh`) rather than under
   `~/.claude`, which is a Claude-Code-session path, not a deployment target on this
   machine. **Any future script that gates an action via Telegram approval and runs
   ON the Mac-mini must use this local copy, not the one on Vincent's machine** — the
   two are no longer the same file and can drift; if the approval-gate mechanism
   itself changes, both copies need updating.

   **Kept in sync 2026-08-14** — the approval gate gained two real capabilities,
   backed up + deployed to both copies (Mac-mini backup:
   `tg_approval_gate.py.bak-2026-08-14`): (1) an explicit `--channel` line
   ("Channel: WhatsApp"/"Gmail"/etc.) above the destination, so the Telegram message
   never leaves ambiguous *where* a pending send is going; (2) a `DECLINED_WITH_REVISION`
   outcome (exit 4) — after a ❌ Decline tap, Telegram prompts for an optional typed
   note via `force_reply`; a reply within `--revision-window` (default 300s) comes back
   as the note on stdout, live-verified end-to-end this session. `push_email_draft.py`
   doesn't yet branch on exit 4 specifically (still just checks for APPROVED) — it would
   fall through to its existing non-approved handling today; extending it to redraft
   from the note is a real follow-up, not done as part of this sync.

3. **`services/inbox-api/DRAFTS-ENDPOINT-PROPOSED.md`** — the reviewable diff for the
   new `POST /drafts/push` route + `EmailSource.append_to_drafts()` method that
   `push_email_draft.py` depends on. **NOT YET APPLIED** — adding it means editing and
   restarting a live production service (`inbox-api`), which the Safety boundary
   above gates on explicit go-ahead. Until it's deployed, `push_email_draft.py` will
   get a 404 and that's the correct, safe failure mode.

**Open item — the real Drafts folder name is presumed, not verified.** `[Gmail]/Sent
Mail` is confirmed (matches by elimination in `email.py`'s existing `_SENT_CANDIDATES`
logic); `[Gmail]/Drafts` is presumed by analogy only. `append_to_drafts()` resolves it
defensively via a candidate list and fails loudly if none match — but the first real
call should still be a throwaway test message, confirmed by actually looking in
Gmail's Drafts view before trusting the endpoint (see the proposed-diff doc's own
"first real call" section).

**Real incident found building this, 2026-08-13 — a single oversized
`/correspondence/messages` call can wedge the whole email source for every other
caller, including the live voice-line's own warm-cache prefetch.** First bulk-fetch
attempt (734 addresses/180 days/5 folders) correctly hit the server's own
`CORRESPONDENCE_TIMEOUT_S` (300s, `services/inbox-api/main.py`) and returned a clean
502 `TimeoutError`. Every attempt AFTER that — even scoped down hard (60
addresses/90 days/Sent-only, 15/45/Sent-only, 5/14/Sent-only) — also hung for
almost exactly ~280-300s regardless of how small the request was, which ruled out
"the header scan itself is just slow" (a smaller window/address-list would have
been visibly faster if that were the real cost). **Root cause, confirmed via two
independent checks:** `/health` still answered instantly with normal `rex`/`calendar`
cache ages, but its `email` cache age had climbed to 1,375s (should refresh every
180s) — and even a trivially cheap `GET /correspondence?days=1` call hung for the
full 20s test window with zero response. `inbox-api` runs as a **single uvicorn
worker** (`--workers 1`), and `EmailSource` serializes all IMAP access behind one
`threading.Lock()` with no acquire timeout — the first request's executor thread
almost certainly never actually released that lock even after the client-side
`asyncio.wait_for` gave up and returned its own 502, so it just sat there holding
the shared IMAP connection, and every subsequent email-touching call (mine AND the
service's own routine prefetch cycle) queued behind it forever. **This means the
live voice-line's warm email cache was stale/blocked for 20+ minutes as a direct
side effect of an oversized research query against a shared, single-worker
service** — a real production impact, not just a slow research call. **Fix:**
restarting `inbox-api` (`launchctl kickstart`, PID tracked via `ps aux | grep
uvicorn.*18792`) clears the stuck lock — but that's a live-service restart, gated by
the Safety boundary above; get explicit go-ahead before doing it, don't just retry
more calls (each stuck attempt adds another thread queued behind the same wedged
lock, making it worse, not better). **For any future bulk email-history pull on
this account: do NOT retry-with-smaller-scope against a call that's already timed
out once** — treat a single `/correspondence/messages` timeout as a signal the
service now needs a restart before it's trustworthy again, not as "try a smaller
request." A proper fix would add a lock-acquire timeout in `EmailSource` so one bad
caller can't starve every other consumer — flagged here, not yet built.

## Pre-launch suppression check — required before registering any new campaign's runner

`enrollment.upsert_lead()`'s opt-out filter only checks the **local**
`opt_outs` table. That table does NOT automatically contain everyone Rex
itself has marked Do Not Contact (`is_dnd`) — Rex-side DNC only reaches local
suppression via a deliberate sync step. Skipping this step is exactly how a
new campaign ends up contacting someone who's genuinely opted out, even
though the enrollment script itself reported zero skips. Two layers, both
required, in this order:

1. **Local suppression cross-check** (fast, DB-only, no live Rex needed) —
   independently confirm no overlap between the new campaign's enrolled
   leads and `opt_outs`, rather than trusting the enrollment script's own
   "skipped_opt_out: 0" count at face value:
   ```bash
   sqlite3 -readonly outreach.db "SELECT contact, channel FROM opt_outs"
   # cross-reference (normalized email/phone) against the new campaign's leads
   ```
2. **Live Rex DNC check** (catches what step 1 structurally cannot) —
   `import_rex_dnc.py --campaign <id> --dry-run` runs a REAL per-lead Rex
   lookup and reports who's `is_dnd` in Rex but not yet mirrored locally,
   without writing anything. Found 26 such leads out of 350 on
   `rex-reengage-2026` (2026-07-24) — a real, non-trivial miss. Re-run
   without `--dry-run` to actually suppress them (cancels their pending
   touches, marks them `opted_out`, backfills `opt_outs` so future campaigns
   inherit the same suppression). ~350 leads takes ~2 minutes (one Rex API
   call per lead) — background it.

**Do this for every new campaign before registering its runner/launchd job.**
The enrollment step (`upsert_lead`) and the DNC sync step are deliberately
separate — enrollment can't see Rex-side DNC, so a campaign that skips step 2
will schedule real touches to suppressed contacts.

## Common mistakes

| Mistake | Fix |
|---|---|
| SSH-ing as `joshua` | The real account is `altoproperty` |
| Treating the check-mode URL as something Joshua must click | It's the operator's own Tailscale re-auth |
| Trusting `git -C .../workspace/skills/mission-control` | No `.git` there — check `services/mission-control` instead |
| Curling `127.0.0.1:18793` | Service only binds the tailnet IP |
| Flipping a disabled flag to "validate" it | Read-only checks only, unless explicitly told to deploy |
| Calling `_client()` after `from rex import _client` | Already a logged-in instance — just `return _client` |
| Assuming himalaya/imsg behave the same over SSH as in a GUI session | himalaya needs the keychain (use inbox-api's `/correspondence` instead); imsg's first use may need a screen-side Allow click via RustDesk/TeamViewer |
| Trusting `campaigns/*.json`'s `template_set` field | Check `campaigns.template_set` in the live DB — the JSON can be stale after a DB-level cutover |
| Trusting the DB's `campaigns.template_set` column as automatically correct | It can drift too (found 2026-08-12) — verify against real sent `touch_log.body` vs `templates.json`, the only source that can't lie |
| Trusting `metrics.py`'s reply-rate without checking the event breakdown | Fixed 2026-08-12, but the failure mode (any inbound-direction row counted as a reply) can recur with a new event type — sanity-check any reply rate over ~30-40% by running the `meta_json.event` GROUP BY query before citing it |
| Assuming a FAILED touch_log row needs live reproduction to diagnose | Check `meta_json` on the FAILED row first — `dispatch_imessage.py`/similar dispatchers already store the real error there |
| Trusting a new campaign's "skipped_opt_out: 0" from enrollment as proof it's clean | That only checked the local `opt_outs` table — always also run `import_rex_dnc.py --campaign <id> --dry-run` for the live Rex-side check before registering a runner |
| Guessing at RustDesk password/hbbs-hbbr behavior instead of reading `rustdesk.md` | That file exists specifically because these gotchas (wrong config file, duplicate GUI processes, Docker/Colima registration bug, etc.) cost real time to diagnose the first time — read it first |
| Triple-escaping quotes (`\\\"`) when composing an `openclaw cron edit/add --message "..."` payload over SSH | Only two real shell-parses happen (local bash's outer single-quote layer, then the remote shell's double-quote layer) before the string is stored as literal cron-job prompt text — one backslash (`\"`) per quote you want in the final stored text. Verify by actually simulating the unescape and compiling any embedded code, not by eyeballing it (caught a real broken-Python bug this way, 2026-07-31) |
| Treating a single cron-job timeout (`"last phase: model-call-started"`) as a real bug and rewriting the job | This machine runs many frequent cron jobs (`voice-quality-coach` every 1m, others every 2-5m) all hitting the same local-ollama instance — a manually-triggered job can get starved out under contention. Check `grep model-fetch ~/Library/Logs/openclaw/gateway.log` for concurrent call volume/latency first; a single retry succeeding confirms it was transient, not a design flaw (2026-07-31) |
| Trusting `rex_client.py`'s `search_leads()` docstring for the date-filter field name (`lead.system_ctime`) | 400s with `InvalidFieldException` — the real field is `system_ctime`, no prefix. Verify any Rex filter field live via `c.describe_model('<Model>')['result']['searchable_fields']` rather than trusting a docstring (found 2026-08-13) |
| Assuming a script you're mid-editing/testing on this box is inert until you say so | It's a live multi-actor system — another open session can pick up a file the moment you `scp` it and run it live. Check `who`/`last` for other active sessions before assuming your own `--dry-run` testing is the only thing touching it (found 2026-08-13) |
| Reading a live suppression run's "suppressed 0" as a bug when a prior dry-run found N | Check whether the campaign's own scheduled runner already ran its DNC sync in between (e.g. `run_rex_nurture.py` does this unconditionally every tick) — cross-check the flagged leads' current `state` and the runner's `worker_health.last_run_at` before concluding either way (found 2026-08-13) |
| Assuming a slow-but-alive background Rex-per-lead loop is stuck because CPU time barely moves | It's I/O-bound — confirm via `lsof -p <pid> \| grep tcp` (ESTABLISHED = real work) and trust `ps -o etime= -p <pid>` for actual elapsed time, not your own sense of how long you've been waiting (found 2026-08-13) |
| Retrying a timed-out `inbox-api` `/correspondence/messages` call with a smaller scope | The first timeout likely already wedged the shared single-worker `EmailSource` lock — every retry queues behind it and looks identical (~280-300s hang) regardless of size. Check `/health`'s `cacheAges.email` and try a trivially cheap call first; if both are stuck, the service needs a restart (ask first), not a smaller request (found 2026-08-13) |
| Trusting `campaigns.active=0` alone as proof a campaign is stopped | FIXED 2026-08-14 in `scheduler.tick()` — before that fix, the flag was never checked by any send path; only that campaign's own launchd job state mattered. Since the fix, the flag is trustworthy again — but if working against a copy/backup of `scheduler.py` from before 2026-08-14, still verify via `launchctl list` too (found + fixed 2026-08-14) |
