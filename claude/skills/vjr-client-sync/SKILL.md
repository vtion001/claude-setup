---
name: vjr-client-sync
description: >
  Cross-reference a client's real communication channels (Gmail via gog, WhatsApp via wacli) against
  their clients/<slug>/.state.json record, and update the record with anything that happened but was
  never logged — payments, blockers, new deliverables, decisions. Use on "check my email and wacli for
  <client> and update their record", "sync <client>'s CRM record with what's actually happened", "did we
  miss anything with <client>", "is the pipeline up to date for <client>", or periodically for active
  clients to catch drift between the CRM and reality. Companion to the global
  `client-feedback-cross-reference` skill — that one turns feedback into code changes + a client reply;
  this one turns live channel activity into an accurate internal record, no client-facing output.
---

# VJR Client Sync — CRM record vs. live channels

`clients/<slug>/.state.json` (`ClientStoreService`'s bridge file, also read by `vjros status`) drifts from
reality fast — Mission Control's Pipeline/Dashboard only ever show what's been logged, and nothing logs
itself. This skill pulls the actual conversation history and closes that gap.

## Step 1 — Get known contact info from the record

```bash
python3 -c "
import json
d = json.load(open('clients/<slug>/.state.json'))
print('email:', d.get('contact_email'), d.get('contact_alt_emails'))
print('whatsapp:', d.get('contact_whatsapp'))
print('last history entry:', d['history'][-1]['at'], '-', d['history'][-1]['note'][:100])
"
```

The last history entry's `at` timestamp is your baseline — everything you're looking for happened after
that.

## Step 2 — Pull Gmail (gog)

```bash
gog auth status                       # confirm which account is active — usually vjrodriguez1994@gmail.com
gog gmail search --account=<acct> "from:<contact_email> OR to:<contact_email>" --max 15 --json
gog gmail thread get --account=<acct> <threadId> --full     # human-readable, NOT --json (raw API payload is a pain to parse)
```

`search` results are ordered newest-thread-first, but `thread get --full` prints messages **oldest-first
within the thread**. For a long thread, don't assume the top of the output is current — grep for message
boundaries and read the tail:

```bash
gog gmail thread get --account=<acct> <threadId> --full > /tmp/thread.txt
grep -n "=== Message" /tmp/thread.txt   # find the last one, Read from there
```

## Step 3 — Pull WhatsApp (wacli)

```bash
wacli contacts search "<name>" --json          # find the JID
wacli chats list --query "<name>" --json       # confirms last_message_ts + unread_count — your ground truth for "is there more"
wacli messages list --chat "<jid>" --after "<last-history-at>" --asc --full --json
```

**Gotcha (real, hit this on the first run):** `messages list` defaults to `--limit 50`. If there's more
than 50 messages in your `--after` window, the result silently stops partway through and you'll miss the
most recent messages entirely — the returned set can end days before the chat's actual `last_message_ts`.
Always compare the last message's timestamp in your result against `chats list`'s `last_message_ts`; if
they don't match, re-query with `--after` set to your last result's timestamp (or raise `--limit`) and
keep going until they do.

**Also check group chats**, not just the DM — business context (project status, incidents, team
decisions) regularly lives in a client's team group (e.g. "ALTO Property Business Development") rather
than the 1:1 thread. `wacli chats list --query "<company/project name>"` to find it.

**Media messages:** list views often show a generic "Sent document"/"Sent image" as `DisplayText` for
*any* attachment regardless of whether it has a real caption. Check the `Caption`/`Text`/`Filename` fields
directly (`--full --json` and inspect per-message) before concluding a media message carries no context —
see the global `client-feedback-cross-reference` skill for the fuller version of this gotcha.

**Contact not showing up in `chats list`/`contacts search`?** Try re-syncing before concluding they're
not a real contact: `wacli sync --once --refresh-contacts --idle-exit 20s --json`. **Gotcha:** plain
`wacli sync` defaults to `--follow=true` and never exits on its own — it'll blow past any reasonable
timeout and sit there indefinitely holding the store lock (which then makes `wacli send` fail with
`store is locked`). Always pass `--once` (and `--refresh-contacts` if you're specifically chasing a
missing/renamed contact). If a stray follow-mode `wacli sync` is already holding the lock, `ps aux | grep
"wacli sync"` and `kill` it before retrying a write command. Also: a saved *contact* with no message
history yet won't appear in `chats list` at all (no chat exists) — `contacts search "<phone or name>"` is
the one that finds it.

## Step 4 — Cross-reference and classify

For each new thing found since the baseline:
- **Confirmed fact, no stage change** (payment received, blocker identified, deliverable sent, decision
  made) → append a history entry (Step 5).
- **Implies an actual stage transition** (signed, delivered, invoiced) → use Mission Control's Advance
  Stage UI/API instead of hand-editing `stage` in the JSON — it mirrors to the `deals` DB table too
  (`DealsController::move` → `ClientStoreService::advance`), so Pipeline stays in sync. A same-stage note
  update doesn't need this — the frontend blocks submitting when the new stage equals the current one, so
  direct-JSON-edit is correct for notes-only updates.
- **Something is actively blocking a deliverable and unanswered** (a question sent that never got a
  reply) → flag this prominently in your report back to Vincent, don't just quietly log it — this is the
  actionable part.

## Step 5 — Write the history entry

Preferred: `vjros client note` (added core/state.py `add_note()`, wired into the CLI) — it always
appends and saves, unlike `client advance`, which is a same-stage no-op (see gotcha below):

```bash
python3 vjros.py client note --client "<slug or name>" --note "<what happened, sourced — cite the channel and rough timestamp so it's traceable back to the message>"
```

**Gotcha:** `client advance --to <stage>` only appends/saves when the stage actually changes — calling
it with the client's *current* stage silently no-ops (prints success, writes nothing). Use `client note`
for anything that isn't a real stage transition, even if `advance` looks like the right verb.

Fall back to a direct JSON edit only if you need to backdate the `at` timestamp to the actual event time
(the CLI always stamps "now"). Match the existing schema exactly — `{at, stage, note}`, 2-space indent,
literal (non-escaped) unicode:

```python
import json
with open('clients/<slug>/.state.json', encoding='utf-8') as f:
    d = json.load(f)
d['history'].append({
    "at": "<ISO8601 timestamp of the actual event, not now>",
    "stage": "<current stage, unchanged>",
    "note": "<what happened, sourced>",
})
with open('clients/<slug>/.state.json', 'w', encoding='utf-8') as f:
    json.dump(d, f, indent=2, ensure_ascii=False)
    f.write('\n')
```

Verify after writing: `python3 -c "import json; json.load(open('clients/<slug>/.state.json'))"` (valid
JSON), then reload the client's page in Mission Control and check console/network for errors — the
backend reads this file directly, a malformed edit breaks the client's entire detail page.

**Correcting a client's display name** (e.g. a name mis-transcribed early on): edit the `client` field
via `state.load()`/`state.save()` (or the JSON directly) — but leave `slug` and the `clients/<slug>/`
folder alone. Every future CLI/API lookup (`vjros client note --client "..."`, `vjros status --client
"..."`) slugifies whatever name you pass and looks up that folder, so once the display name and slug
diverge, keep using the *original* name (or the slug itself) for all `--client` args, not the corrected
one — passing the corrected name will slugify to a different folder and fail with "Unknown client."

## Step 6 — Report back

Lead with anything time-sensitive or blocking (an unanswered question sitting on a deliverable, an
invoice that looks unsent, a bug report with no confirmed fix) — that's the actual value of the sweep.
Don't bury it under a chronological recap.
