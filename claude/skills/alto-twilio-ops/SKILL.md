---
name: alto-twilio-ops
description: Use when investigating, auditing, or changing anything on ALTO Property's shared Twilio account — checking which phone number is connected to what, searching/buying a new number, or pointing a number's voice/SMS webhook at a new destination. Trigger phrases include "twilio number", "IVR", "call routing", "buy a phone number", "which number is connected to X".
---

# ALTO Twilio Account Operations

## Overview

ALTO Property's Twilio account (Account SID redacted for this export — see the live
`~/.claude/skills/alto-twilio-ops/SKILL.md` or the Twilio console) is **shared
across multiple, unrelated codebases** — altoproperty-main (admin dashboard
dialer), salescrm (a separate React CRM), and Joshua Kim's Mac-mini-2/OpenClaw
voice line. No single repo's code tells you the full picture of what a number
is actually doing — the live Twilio API is the only authoritative source.
This bit hard on 2026-07-26: a number's `.env.local` role in one repo (outbound
caller ID) had nothing to do with its live inbound webhook (pointed at a
different repo entirely).

**Golden rule: investigate the live API before touching any number's config,
every time — never infer from one codebase's env vars alone.**

## No CLI, no action-capable MCP — use the REST API directly

- The Twilio CLI is **not installed** on this machine (`which twilio` → not found).
- The `mcp__twilio-docs__twilio__*` MCP tools (if loaded) are **documentation/
  schema search only** — they cannot execute anything against the live
  account. Use them to look up parameter names/endpoints, then call the real
  API yourself with `curl`.
- All the real work below is plain Twilio REST API calls, authenticated with
  Basic Auth (`AccountSid:AuthToken`).

## Getting a working auth token

`altoproperty-main/.env.local`'s `TWILIO_AUTH_TOKEN` is **known-stale** (its
own comment block says it 401s against the live API — prod Vercel has the
correct value, local just drifted). Always pull fresh from Vercel prod:

```bash
# MUST run from within the linked project dir (altoproperty-main) — cd'ing
# away first breaks the Vercel project link and pull fails with "not_linked".
vercel env pull /path/to/scratchpad/.env.prod.pull --environment=production --yes
```

Extract only what you need into shell variables, use them, then **delete the
pulled file immediately** — never leave credentials sitting in a temp file:

```bash
ENVFILE=/path/to/scratchpad/.env.prod.pull
SID=$(grep '^TWILIO_ACCOUNT_SID=' "$ENVFILE" | cut -d= -f2- | tr -d '"')
TOKEN=$(grep '^TWILIO_AUTH_TOKEN=' "$ENVFILE" | cut -d= -f2- | tr -d '"')
# ... use $SID / $TOKEN in curl calls, piping output through `grep -v "$TOKEN"`
# as a defensive filter so the raw secret never lands in your own output ...
rm -f "$ENVFILE"
```

**Confirmed 2026-08-06: prod Vercel's `TWILIO_AUTH_TOKEN` genuinely is
correct** (`6f...291`, unchanged since at least 2026-06-22 — it has never
actually been rotated). If a `curl` using a freshly-pulled token still 401s
(`{"code":20003,"message":"Authenticate"}`), **do not conclude the credential
itself is stale** — a real live token was extracted-and-401'd earlier the
same day this was confirmed, twice, with no code difference from the
successful check that followed. Before doubting the credential:
1. Sanity-check the extraction: `echo -n "$TOKEN" | wc -c` should be exactly
   32; `echo "$TOKEN" | cat -A` to check for a stray trailing `^M`/`$` from
   line-ending or quoting issues the `tr -d '"'` didn't catch.
2. If still stuck, cross-check directly against the Twilio Console —
   `console.twilio.com` (search "API keys" in the top search bar → "API
   keys & tokens" → Live credentials → click the eye icon to reveal the Auth
   Token) — via `claude-in-chrome` if the user has it open, or ask them to
   read it out. This is ground truth; a `curl` 401 against a
   freshly-extracted value is not enough on its own to conclude the account
   needs `Request a secondary token`/rotation.
3. Don't retry more than ~2 credential variants in a row against Twilio's
   live auth — repeated failed Basic Auth attempts risk real account
   throttling/lockout, and (separately) tends to trip the Claude Code
   permission classifier as a retry-loop pattern. Stop and cross-check via
   the Console instead of guessing a third/fourth combination.

## Step 1 — Always audit before touching anything

List every number on the account and what it's actually configured to do:

```bash
curl -s -u "${SID}:${TOKEN}" \
  "https://api.twilio.com/2010-04-01/Accounts/${SID}/IncomingPhoneNumbers.json?PageSize=50" \
  | python3 -c "
import json,sys
d = json.load(sys.stdin)
for n in d.get('incoming_phone_numbers', []):
    print(n['phone_number'], '|', n.get('friendly_name'), '| voice_url:', n.get('voice_url'), '| sms_url:', n.get('sms_url'))
"
```

**Known assignments as of 2026-07-26** (re-verify — this changes):

| Number | Friendly name | Actually connected to |
|---|---|---|
| `+61468165521` | `61468165521` | **Shared/overloaded.** altoproperty-main uses it as *outbound* caller ID only (via a TwiML Application, not this webhook). Its live *inbound* `voice_url` points to `sales-crm-sigma-eosin.vercel.app` — a completely different repo (`salescrm`). |
| `+61485021452` | `OpenClaw Voice (Joshua)` | Joshua's OpenClaw/Peter voice line, via an ngrok tunnel |
| `+61748022038` | `61748022038` | ElevenLabs AI voice-agent inbound (`api.us.elevenlabs.io/twilio/inbound_call`) |
| `+61748034068` | `ALTO IVR Router` | Purchased 2026-07-26 for the Sales(Josh/Ryan Tso)/Property Management(Connor) two-level IVR — `voice_url` **live and confirmed working**: `https://www.altoproperty.com.au/api/twilio/ivr/welcome`, no fallback URL set (altoproperty-main PRs #117/#118/#120/#121/#126). Verified 2026-08-06 directly against Twilio's own Call Logs + per-call Notifications: the one real bug (405 from an apex-domain redirect, hit Connor's first three test calls 2026-07-27) was fixed same day and every call since — test and real — has completed with zero webhook errors. See that repo's CLAUDE.md for the full write-up. |

## Step 2 — Searching for a new number

```bash
# Filter by locality for something geographically relevant (ALTO is Brisbane-based) —
# a plain AU/Local.json search with no locality filter returns numbers scattered
# across every QLD/WA/VIC rate center, not useful on its own.
curl -s -u "${SID}:${TOKEN}" \
  "https://api.twilio.com/2010-04-01/Accounts/${SID}/AvailablePhoneNumbers/AU/Local.json?VoiceEnabled=true&InLocality=Brisbane&PageSize=30"
```

- **Gotcha**: as of 2026-07-26, no AU *Local* number in current inventory supports voice+SMS together (`SmsEnabled=true` combined with `VoiceEnabled=true` returns zero results) — search voice-only if that's all you need, or use `AU/Mobile.json` instead if SMS matters (mobiles do support both, at a higher price).
- Check real pricing before recommending anything — don't assume a static number:
  ```bash
  curl -s -u "${SID}:${TOKEN}" "https://pricing.twilio.com/v1/PhoneNumbers/Countries/AU"
  # local: $3.00/mo · mobile: $8.25/mo · toll free: $20.00/mo (USD, as of 2026-07-26)
  ```

## Step 3 — Buying a number

**This is a real purchase against the account's payment method — always get
explicit confirmation of the exact number and price before calling this.**

AU numbers require a registered `AddressSid` (regulatory requirement) — check
for an existing one first rather than creating a new Address resource:

```bash
curl -s -u "${SID}:${TOKEN}" "https://api.twilio.com/2010-04-01/Accounts/${SID}/Addresses.json"
# "Alto Real Estate", Durack QLD 4077 — AD21a2c9f4242fbac29c0957a9dcd03414 — already validated, reuse it
```

```bash
curl -s -u "${SID}:${TOKEN}" -X POST \
  "https://api.twilio.com/2010-04-01/Accounts/${SID}/IncomingPhoneNumbers.json" \
  --data-urlencode "PhoneNumber=+61XXXXXXXXX" \
  --data-urlencode "FriendlyName=<descriptive name>" \
  --data-urlencode "AddressSid=AD21a2c9f4242fbac29c0957a9dcd03414"
```

Omitting `AddressSid` fails with a clear error (code 21631) — that's expected
for AU numbers, not a bug; just supply the existing address SID.

## Step 4 — Pointing a number at a new webhook (e.g. an IVR)

```bash
curl -s -u "${SID}:${TOKEN}" -X POST \
  "https://api.twilio.com/2010-04-01/Accounts/${SID}/IncomingPhoneNumbers/<NumberSid>.json" \
  --data-urlencode "VoiceUrl=https://www.altoproperty.com.au/api/ivr/welcome" \
  --data-urlencode "VoiceMethod=POST"
```

Re-run the Step 1 audit query afterward to confirm the change actually took —
never trust a 200/201 response alone as proof; check the live resource.

## Step 5 — Testing a webhook end-to-end without a physical phone

You can't literally dial a phone from this environment. The closest real test:
place a call between two Twilio-owned numbers via the REST API, which genuinely
exercises the "To" number's live inbound routing (not just the webhook URL in
isolation):

```bash
curl -s -u "${SID}:${TOKEN}" -X POST \
  "https://api.twilio.com/2010-04-01/Accounts/${SID}/Calls.json" \
  --data-urlencode "From=+61468165521" \
  --data-urlencode "To=+61748034068" \
  --data-urlencode "Url=https://www.altoproperty.com.au/api/twilio/ivr/welcome" \
  --data-urlencode "Record=true"
```

- Poll `Calls/{CallSid}.json` for `status` until `completed`.
- Fetch `Calls/{CallSid}/Recordings.json`, then download
  `Recordings/{RecordingSid}.mp3` with the same Basic Auth.
- **Don't pass `SendDigits`** unless you mean to actually ring whoever the IVR
  would dial next — an automated test with no human on either end will just
  hit the Gather timeout and loop/hang up on its own after ~15s, which is
  enough to prove the greeting/answer stage without side effects on real agents.

## Step 6 — Diagnosing "a number isn't working" reports

When someone reports a call/IVR problem, **Twilio's own Call Logs and
per-call Notifications are the authoritative record — not the receiving
app's own server logs.** Confirmed 2026-08-06 investigating a real Connor
report: Vercel's runtime-logs tool only surfaces requests that emit explicit
`console.log`/`warn`/`error` output. A genuinely successful, correctly-signed
Twilio webhook hit produces no such output in this codebase (the signature
warning only fires on *unsigned* test calls), so it's **invisible** to
Vercel's own log search — a 7-day "zero requests" reading from Vercel logs
was flat wrong; Twilio's Call Logs for the same window showed dozens of real
completed calls. Don't infer "nothing reached the webhook" from an empty
apphost log search.

```bash
# 1. Real call history for the number in question
curl -s -u "${SID}:${TOKEN}" \
  "https://api.twilio.com/2010-04-01/Accounts/${SID}/Calls.json?To=%2B<number>&PageSize=50"

# 2. For any call, the exact webhook-fetch error (if any) Twilio itself recorded —
#    this is the ground truth for "what went wrong", e.g. error_code 11200 =
#    "Got HTTP 405 response to https://...", far more precise than guessing:
curl -s -u "${SID}:${TOKEN}" \
  "https://api.twilio.com/2010-04-01/Accounts/${SID}/Calls/<CallSid>/Notifications.json"

# 3. If a call Dial'd through to an agent, the child leg (proves it actually
#    connected, and to whom):
curl -s -u "${SID}:${TOKEN}" \
  "https://api.twilio.com/2010-04-01/Accounts/${SID}/Calls.json?ParentCallSid=<CallSid>"
```

**The account-wide Monitor/Debugger Alerts feed
(`monitor.twilio.com/v1/Alerts`) is noisy and NOT scoped to the number
you're investigating** — on a shared account it mixes in every other
project's errors (e.g. salescrm's `sales-crm-sigma-eosin.vercel.app`
webhook throwing unrelated `12200`/`15003` errors dominated the most-recent
50 alerts on 2026-08-06, none of them about the IVR). Don't read the raw
Alerts feed as "these are problems with the number I'm checking" — instead
pull the number's own Call SIDs first (`Calls.json?To=...`), then check
per-call Notifications, which are naturally scoped correctly.

## Picking a `<Say>` voice

The default (no `voice` attribute) is Twilio's Basic/robotic tier. The
installed `twilio` npm SDK's `SayVoice` TypeScript type only covers
Neural2/Wavenet/Standard — Google's newer Generative "Chirp3-HD" voices and
Amazon Polly's "-Generative" voices exist on Twilio's platform but aren't in
this SDK version's type union, so using one requires an unsafe cast. Current
default for AU work: `Google.en-AU-Neural2-C`. Other en-AU Neural2 options:
`-A`/`-C` (female), `-B`/`-D` (male).

## Common mistakes

| Mistake | Fix |
|---|---|
| Trusting one repo's `.env` to know what a number does | Always check the live `voice_url`/`sms_url` via the API — a number can be used by one repo for outbound only while a completely different repo owns its inbound webhook |
| Running `vercel env pull` after `cd`-ing into an unrelated directory | Must run from within the linked project dir, or pass an absolute output path while cwd is still the project root |
| Assuming the local `.env.local` Twilio token works | It's documented as stale (401) — always pull fresh from Vercel prod |
| Buying an AU number without `AddressSid` | Fails with code 21631 — reuse the existing validated "Alto Real Estate" address instead of creating a new one |
| Searching `AU/Local.json` with both `VoiceEnabled` and `SmsEnabled` | Currently returns zero — AU Local inventory is voice-only right now; use `AU/Mobile.json` if SMS is required |
| Leaving a `vercel env pull`'d file on disk | Delete it immediately after extracting the values you need |
| Concluding a token is stale from one `curl` 401 | Verify the extraction first (length check, stray `\r`/quoting), then cross-check via the Twilio Console before assuming rotation — prod Vercel's token was confirmed correct on 2026-08-06 after an earlier 401 wrongly looked like drift |
| Trusting the receiving app's own server logs to prove "nothing hit this endpoint" | A successful, correctly-signed request produces no console output in this codebase and is invisible to Vercel's runtime-log search — use Twilio's own Call Logs + per-call Notifications as the authoritative traffic record instead |
| Reading the account-wide Monitor Alerts feed as being about the number you're investigating | It's shared across every project on the account and gets dominated by unrelated repos' errors — pull the number's own Call SIDs first, then check per-call Notifications |
