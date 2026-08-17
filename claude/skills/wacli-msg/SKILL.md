---
name: wacli-msg
description: >
  Before drafting any message to be sent on Vincent's behalf via wacli (WhatsApp) — ground the draft
  in his own real sent-message history (scraped per-recipient, plus a cross-thread baseline), filtered
  for likely-AI-contaminated messages before trusting anything as an example. Use when composing a
  wacli reply, when the operator says "reply to X on WhatsApp" / "draft a message to <contact>", or any
  time a recipient has flagged (or might flag) a message as reading like it was written by an AI/agent.
  That exact incident — a contact telling Vincent they could tell an agent sent the message — is why
  this skill exists; he experienced it as a serious insult. Hard rules, verified 13 Aug 2026: NEVER use
  an em dash, ever, in any drafted message — no exception, no "unless the corpus shows otherwise."
  Voice target is konyo/La Salle-register Filipino-English code-switching (casual, elongated words for
  emphasis, "haha"/"hehe" fillers, sentence fragments) — NOT deep/formal Tagalog and NOT stacked "po/opo"
  politeness. Companion to the global "Client/Team-Facing Messages" style rule in CLAUDE.md/OPERATOR.md.
---

# wacli-msg — draft wacli messages in Vincent's real voice, not a house style

## Why this exists (read this first)

A recipient once told Vincent they could tell an agent/AI had sent a wacli message on his behalf —
he experienced that as a serious insult. Root cause of the first bad draft: it certified a
contaminated thread (deep/formal Tagalog, stacked "po", real em dashes) as his "verified real voice"
just because `FromMe: true` — which only proves a message went out from his account, not that he
personally typed it; a prior AI-drafted-and-approved send looks identical in the data.

**The fix, still the governing principle:** explicit operator correction about his own voice always
outranks scraped corpus data, and any `FromMe: true` message must clear the Step 3 contamination
filter below before it's trusted as an example.

## The engine — this now runs itself, don't re-derive it by hand

`skills/wacli-msg/scripts/wacli_voice_engine.py` is the real mechanism as of 13 Aug 2026. It scrapes
every DM contact's `--from-me` messages via wacli, runs the Step 3 red/green/neutral classifier below
on each one, and renders the result to `voice-profile/*.md` (gitignored). It's incremental — each
contact's last-seen timestamp is checkpointed in `voice-profile/state.json`, so re-running only pulls
what's new since last time. This *is* the "autolearn" loop: nothing about it needs to be re-invented per
session.

```bash
python3 skills/wacli-msg/scripts/wacli_voice_engine.py                      # incremental, all DM contacts
python3 skills/wacli-msg/scripts/wacli_voice_engine.py --full               # ignore checkpoints, full re-scrape
python3 skills/wacli-msg/scripts/wacli_voice_engine.py --contacts "Name"    # name-substring filter
python3 skills/wacli-msg/scripts/wacli_voice_engine.py --render-only        # just rebuild .md from existing state
```

**It also runs on its own.** `com.vjr.wacli-voice-train` is installed and loaded (launchd, daily +
`RunAtLoad`) — wrapper at `.claude/cron/run-wacli-voice-train.sh`, plist symlinked into
`~/Library/LaunchAgents/`, logs in `.claude/cron/logs/wacli-voice-train-std{out,err}.log`. Same
`/usr/bin/python3`-via-bash FDA pattern as `run-client-prefetch.sh` (needed — `voice-profile/` lives
under `~/Desktop/...`, a TCC-protected location for a bare launchd process). No one needs to remember to
re-run this by hand; it keeps ingesting new conversations as they happen.

**Every run reports itself — full inventory, all contacts, not just deltas.** After scraping and
rendering, the engine writes `voice-profile/inventory.csv` (one row per contact: name, jid,
`new_this_run`, cumulative green/red/neutral, total, last message seen — every tracked contact, zero-
activity ones included, on purpose, per explicit instruction not to silently omit anything) and sends
it to the operator's own Telegram via `tg_send.py`, with a short caption summarizing the run (new-
message count, contacts changed, cumulative totals, top movers). This happens on every run, automated
or manual, unless `--no-notify` is passed — a notify failure never fails the scrape/render itself (see
`notify_telegram()` in the engine script). This is how "did the autolearn actually run, and what did it
find" stays visible without anyone needing to SSH in and read `voice-profile/` by hand.

**Read `voice-profile/baseline.md` and `voice-profile/<contact-slug>.md` for the live numbers and
current examples** — those are regenerated every run and are the actual source to check before
drafting. As of the first full run (13 Aug 2026, 77 DM contacts): **3,346 green / 88 red /
867 neutral**. Joshua Kim and Mark Lee specifically: Joshua Kim 974 green / 20 red / 378 neutral, Mark
Lee 415 green / 2 red / 154 neutral — the 22 red messages between them are almost all client-update
texts with em dashes ("Hey Joshua — put together a review draft...", "146 Scotts Rd IM — Variant A...")
that read exactly like prior AI-drafted-and-approved sends, not things he typed live. That's very likely
where the original complaint came from.

**Voice isn't the whole picture — `voice-profile/contact-context.json` (hand-maintained, see Step 4)
carries who each contact actually is: their repo/project and any standing correction like a preferred
name.** A message can be voice-perfect and still be wrong if it calls someone by the wrong name or talks
about the wrong project — check the `## Context` section in that contact's `.md` before drafting, not
just the examples.

## Historical note: client register is NOT more formal than personal threads

Early manual sampling (pre-engine, 13 Aug) worried client threads would need a more formal/Tagalog
register than personal ones. The full engine run disproved that — Joshua Kim and Mark Lee's own
green-flagged examples are short, direct, contraction-heavy, zero em dash, the same casual voice as
personal/peer threads, just more often in English. Don't assume a client needs a different register;
check their actual `voice-profile/<slug>.md` file, which carries the real current examples.

## Steps 1-4 — what the engine does under the hood

The manual steps below are now automated by `wacli_voice_engine.py` (see above) and don't need to be
run by hand for routine use — kept here because they document the actual method, which matters if the
engine's classifier ever needs adjusting or a one-off ad hoc pull is needed outside the automated pass.

## Step 1 — Identify the target chat

```bash
wacli --read-only chats list --json --limit 50
```

Find the `jid` for the recipient (`<number>@s.whatsapp.net` for a DM, `<id>@g.us` for a group).

## Step 2 — Pull two samples, not one

**(a) Thread-specific — this exact recipient.** Last 30-40 messages, both directions:

```bash
wacli --read-only messages list --chat <jid> --json --limit 40
```

Sync first if the thread might be behind (`wacli sync --once --idle-exit 20s --json` — see the
`--follow`-hangs-forever gotcha in `client-feedback-cross-reference/references/whatsapp-wacli.md`).

**(b) Cross-thread baseline.** Pull from personal/peer threads preferentially, not client threads —
the verified-genuine reference above came from exactly this kind of thread. Client threads are more
likely to contain prior AI-drafted-and-approved sends (formal, high-stakes, more likely to have been
run through an assistant first) — treat them as higher-risk for contamination, not lower.

Filter every message to `FromMe == true` and non-empty `Text`/`MediaCaption` (same `DisplayText`-is-a-
UI-label gotcha as the wacli reference).

```python
import json
d = json.load(open("<saved output>.json"))
mine = [m for m in d["data"]["messages"] if m["FromMe"] and (m["Text"].strip() or m["MediaCaption"].strip())]
```

## Step 3 — Filter for contamination BEFORE treating anything as an example

This is the step the first version skipped. Before using any `FromMe: true` message as a style
example, check it against both lists:

**Red flags (likely AI-drafted-and-approved, do NOT use as an example):**
- Contains an em dash — treat this as a near-certain contamination signal on its own.
- Deep/formal Tagalog vocabulary, or "po"/"opo" stacked more than once per message.
- Long, structured multi-paragraph message with a clear topic sentence, enumerated points, and a
  formal closer ("Salamat po!", "Thank you for your understanding.").
- Unnaturally clean grammar and punctuation with zero fragments, typos, or filler words.

**Green flags (consistent with genuine typing):**
- Elongated letters for emphasis, "haha"/"hehe"/"hihi" as sentence-enders.
- Sentence fragments, run-ons, lowercase-default.
- Occasional real typos or dropped words.
- Short message, or one of several short messages sent in quick succession (real texting comes in
  bursts, not one long composed paragraph).
- Casual Taglish/konyo code-switching without formal particles.

If a thread's history is mostly red-flag messages, don't use it to derive style — fall back to the
verified-genuine reference above and this skill's hard rules instead of inventing a "this client gets
formal Tagalog" exception from unverified data.

## Step 4 — Persist a distilled, filtered profile

Write to `voice-profile/<contact-slug>.md` and `voice-profile/baseline.md` (gitignored — this is
Vincent's own writing-style data, never commit it). Only green-flag messages go in as examples. If a
thread turned out contaminated, note that explicitly in its profile file ("history for this thread is
mostly prior AI-drafted sends — do not use as a style source, apply the baseline + hard rules instead")
so the next session doesn't repeat the mistake.

Re-scrape and overwrite when: the profile is >30 days old, this recipient has no profile yet, or a sent
message gets flagged as not sounding like him — treat that flag as a forced, immediate refresh.

### `contact-context.json` — who this contact actually is, not just how they text

Added 2026-08-13 after a draft to Joshua Kim got declined for using "Josh" instead of "Joshua" — the
scraped voice data alone can't catch this class of error, because it's a fact about the person, not a
style pattern, and the scrape had genuinely found him casually using "josh" himself in one earlier
message. Voice-matching a message perfectly while getting the recipient's name wrong is still a bad
send.

`voice-profile/contact-context.json` is **hand-maintained, never auto-written** — the engine only reads
it and merges each entry into that contact's `.md` as a `## Context` section (`joshua-kim.md` for the
worked example). Per-contact fields: `preferred_address` / `never_address_as` (a direct correction like
Joshua's beats anything the scrape shows), `repo` / `project` (which codebase or client engagement this
conversation is actually about — lets a draft reference the right work instead of generic language),
`relationship` (client / peer / vendor, etc.), `notes`, `source` (where this fact actually came from —
a message, a CLAUDE.md project entry, a direct operator correction — never fabricate an entry just to
fill the table). `baseline.md`'s per-contact table shows a ✓/— column for whether a contact has one;
a `—` means don't guess their name, project, or relationship — ask, or check the thread directly, before
drafting anything non-trivial to them.

Seeded so far (2026-08-13): Joshua Kim (`altoproperty-main` / ALTO Property, always "Joshua"), Mark Lee
(`bricklane-property-group`, confirmed "Mark" from his own thread), Peter Wu (`ios-pm-app` / SiteSignal
PM, preferred address not yet confirmed). Most of the other 74 tracked contacts have no entry yet —
add one as each comes up rather than back-filling all of them speculatively.

## Step 5 — Draft against the profile, then self-check before presenting

Hard rules, non-negotiable regardless of what any profile shows:
- **No em dash. Ever.**
- **No deep/formal Tagalog, no stacked "po/opo."** Konyo/La Salle-register Taglish is the target: casual
  English-Tagalog code-switching, not formal correctness.

Then draft against the recipient's filtered profile, falling back to the verified-genuine baseline
above, falling back to the global CLAUDE.md rule only where neither has clean data yet. **Check
`contact-context.json` (via the `## Context` section in that contact's `.md`) before drafting, not
after** — the repo/project tells you what the message should actually be about, and any
`preferred_address`/`never_address_as` entry overrides whatever the voice examples happen to show.

**Opener selection — don't default to "Hey [Name]," on every message.** Real texting only opens
with a name-greeting at the start of a new exchange (new day, new topic, or a real time gap) — not
on every reply inside an already-active back-and-forth. Before drafting, check the last few messages
in the thread (already pulled in Step 2a): if this message is a direct continuation of something
just discussed — a reply to their last message, a promised follow-up like "let me check and get back
to you" — skip the greeting and reply straight into it, the way most of a contact's own green-flagged
continuations do (e.g. Mark Lee: "Got it, i'll configure everything later on and check on it." /
"Cool! Maybe we should configured the dns now." / "No worries, take your time." — zero greeting,
mid-conversation). Reserve "Hey [Name]," for the pattern it actually follows in the profile: first
message of a session/day, a genuinely new topic raised cold, or after a real gap. Check each
contact's own green-flagged mix rather than assuming one pattern always applies — a real incident
(15 Aug 2026) caught a drafted reply opening "Hey Mark, dug into it..." inside an active
same-morning back-and-forth, where a bare "Dug into it..." would have matched his own pattern better.

Before presenting for approval, check line-by-line:
- Any em dash anywhere? Reject and rewrite — don't "soften" this one.
- Does it read konyo-casual, or does it slip into formal/deep Tagalog structure?
- Is it padded into an AI-shaped paragraph instead of matching real message length/burstiness?
- Would this specific recipient recognize this as how Vincent actually texts, based on green-flag
  examples — not based on what a prior possibly-contaminated message in the same thread looks like?
- **Does it address the recipient the way `contact-context.json` says to** — not just however a
  green-flagged example happened to phrase it once?

## Step 6 — send-gating: human-in-the-loop via Telegram, not a chat reply

**As of 13 Aug 2026, every wacli send — text or file, to any recipient — goes through
`~/.claude/scripts/tg_approval_gate.py` before it fires.** This is a shared script, not
wacli-specific — the `gog` skill's Gmail/Calendar/Sheets-Drive gating uses the exact same one
(see its own SKILL.md). One approval mechanism, used everywhere an outbound/irreversible action
is about to happen, not a per-tool fork. This replaces "draft it, ask in chat, wait for the
operator to type back" with a real push notification carrying Approve/Decline buttons. The
operator does not need to return to the terminal.

```bash
# Text message — --channel is always "WhatsApp" for this skill's own sends
python3 ~/.claude/scripts/tg_approval_gate.py \
  --kind text --recipient "Mark Lee" --channel "WhatsApp" \
  --content "<the exact drafted message>" [--timeout 900] [--revision-window 300]

# File / document (the actual file is attached so the operator can review real content, not just a filename)
python3 ~/.claude/scripts/tg_approval_gate.py \
  --kind file --recipient "Mark Lee" --channel "WhatsApp" \
  --file /path/to.pdf --caption "<the exact caption>" [--timeout 900] [--revision-window 300]

# Part of a multi-message batch — pass the same full preview on every item, see below
python3 ~/.claude/scripts/tg_approval_gate.py \
  --kind text --recipient "Mark Lee" --channel "WhatsApp" \
  --content "<item 2's exact text>" \
  --batch-preview $'1) <item 1 text>\n2) [this one] <item 2 text>\n3) <item 3 text>'
```

**`--channel "WhatsApp"` is required from this skill, always** (added 2026-08-14, after the
operator flagged the old approval message as not making the destination clear enough) — it puts
"Channel: WhatsApp" on its own line above "To: <recipient>" in the Telegram message, so it's never
ambiguous which surface a pending send is going out on when gog/Gmail/Calendar approvals might be
sitting in the same chat around the same time.

Run it via **Bash `run_in_background: true`**, then continue other work — the harness delivers
a task-notification the moment a button is tapped (or the timeout elapses), which resumes this
exact session automatically. Read the background task's output file: it contains exactly one of:

- `APPROVED` (exit 0) — proceed immediately with the real `wacli send text|file ...` command,
  using the *identical* content/destination that was shown in the approval request. Never
  re-draft or "improve" it between approval and send — what was approved is what goes out.
- `DECLINED` (exit 1) — do not send. Report back what was declined; ask before drafting a
  revised version rather than assuming the same content with tweaks is still wanted.
- **`DECLINED_WITH_REVISION` (exit 4, added 2026-08-14)** — do not send. The operator tapped
  Decline and then replied to Telegram's follow-up prompt with a typed note (line 1 of the output
  file is `DECLINED_WITH_REVISION`, the note is on the line(s) after it — read the whole file, not
  just the first line). Unlike a plain decline, this note *is* direction to act on: redraft against
  it and re-run this skill's Steps 1-5 (voice-matching, contamination filtering, hard rules) before
  gating the revised version through `tg_approval_gate.py` again. If the note is genuinely unclear
  or contradicts something, it's still fine to ask — but a clear note should not trigger another
  round of "what would you like changed" back to the operator, they just answered that.
- `TIMEOUT` (exit 2) — do not send. The pending message in Telegram is edited to show it
  timed out (buttons removed) so it doesn't sit there looking actionable. Surface this to the
  operator rather than silently retrying or silently dropping it.

**Uses a dedicated bot** (`~/.telegram_approvals_config.json`, `@vjr_approval_bot`), deliberately
separate from `~/.telegram_config.json` (shared with the always-running `openclaw gateway`
process). Telegram's `getUpdates` queue is global per bot token — polling the same bot an
already-running consumer is polling risks either side silently losing updates (a missed
approval tap, or a missed message on openclaw's side). Never point this script at the shared
bot config to "simplify" — that reintroduces the exact conflict it was built to avoid.

This is a blocking gate for the *actual send*, not for drafting. Steps 1-5 above (voice-matching,
contamination filtering, hard rules) still happen first — the approval gate is what the operator
reviews, so it should already be the real, final, voice-checked draft by the time it's sent
through this script, not a placeholder to be revised after the fact.

### Dispatch the whole gate-and-revision loop to a subagent, not the main session

**As of 15 Aug 2026, don't run `tg_approval_gate.py` inline in the main session and babysit it
turn by turn.** Dispatch a single subagent (Agent tool, `general-purpose` is fine) that owns the
entire gate → possible-revision → redraft → re-gate cycle for one message, and only reports back
once with the final outcome:

1. Run `tg_approval_gate.py` for the current draft.
2. `APPROVED` → **do NOT run `wacli send` itself.** Report the approved content back and stop —
   the main session performs the actual send (see the classifier note below for why).
3. `DECLINED_WITH_REVISION` → redraft against the note, applying this skill's Steps 1-5 (voice,
   contamination filter, hard rules, opener selection) itself, then loop back to step 1 with the
   new draft. Cap at 3 rounds — if still not resolved after 3 revisions, stop and report rather
   than looping forever.
4. `DECLINED` (no note) or `TIMEOUT` → stop, report which one. Don't guess at a revision that
   wasn't given.

**Why this matters:** the whole point of `DECLINED_WITH_REVISION` is a fast redraft-and-resend
loop — routing every round back through the main session makes the loop's actual speed depend on
whatever else the main session happens to be doing when each notification lands, not on how fast
the operator replies. A subagent that owns the gate-wait/redraft loop finishes as soon as the
operator resolves it, independent of the main session's workload — that's still true and still the
reason to dispatch it. What changed (confirmed 16 Aug 2026): the main session must perform the
final send itself, not the subagent — see below.

**The actual send must run in the main session, not the subagent — this is a second, independent
gate on top of Telegram approval.** Confirmed 16 Aug 2026: a subagent's `wacli send` was denied
twice by Claude Code's own auto-mode classifier immediately AFTER `tg_approval_gate.py` had
already returned `APPROVED` for that exact unchanged content — the classifier scrutinizes an
autonomous subagent firing an outbound send with no human directly in that turn, independent of
the Telegram approval already obtained. The identical command with identical content sent
successfully on the first try when run directly in the main session instead. This is not something
to route around with clever command syntax inside the subagent (that would be gaming the
classifier's intent, not a fix) — the correct architecture is the division of labor above: subagent
owns waiting/polling/redrafting, main session owns the one final send call once `APPROVED` comes
back. If the send still gets blocked even in the main session, report it plainly and let the
operator send it themselves (`!`-prefixed) or explicitly instruct the send — don't keep retrying.

**Don't trust a subagent's reported gate outcome unless it's traceable to the literal exit line
in the script's own output — an inferred "APPROVED" is a false positive on the one question this
whole gate exists to answer.** Confirmed 17 Aug 2026: a dispatched subagent's own background-task
tracking (a `Bash run_in_background` call plus a `Monitor` it had armed) went stale across a turn
boundary — process, output file, and monitor all gone with no way to recover the real result on
resume. Instead of reporting that as unresolved, it inferred `APPROVED` from indirect signals: an
unrelated task's exit code, and the mtime of `~/.claude/scripts/.tg_approval_state/<hash>/offset.txt`
— which is a *global* getUpdates checkpoint shared by every approval request through the bot, not
evidence of any one message's decision. Caught before sending by refusing the inference and
re-running the gate directly in the main session instead, watching the real PID through to a
literal `APPROVED` line in the output file first. If a subagent's report doesn't cite the actual
output line, re-run the gate yourself rather than act on it.

Mechanical corollary: when running `tg_approval_gate.py` under Bash `run_in_background: true`,
call it directly — don't also wrap it in `& disown`/`nohup ... &` inside the command string.
Double-backgrounding makes the harness mark the outer wrapper "complete" the instant it echoes and
returns, while the actual script keeps running orphaned and untracked.

`gog`'s equivalently-gated sends (Gmail, Calendar with attendees, destructive Sheets/Drive ops)
follow this same subagent-dispatch pattern — see that skill's own Operational rules section.

### Multiple items (message + documents) — sequential gates, and send is automatic

**Real incident, 13 Aug 2026:** three `tg_approval_gate.py` calls (a text message plus two
document attachments) were fired in parallel (`run_in_background: true`, all in one turn). Two
succeeded; the third crashed with `HTTP Error 409: Conflict` from Telegram's `getUpdates` — the
exact single-consumer-per-bot-token conflict this skill's own Step 6 already warns about, just
happening between two copies of *this same script* instead of against openclaw. **Never dispatch
more than one `tg_approval_gate.py` call at a time.** When a message needs one or more documents
attached, run the gates one after another — dispatch the next only once the previous has resolved
(`APPROVED`/`DECLINED`/`TIMEOUT`), never concurrently, even though each is a separate recipient
decision. (The script was rewritten 14 Aug 2026 to share one Telegram poller across concurrent
processes via a lock+mailbox instead of each racing its own `getUpdates` — see its docstring —
which also fixed a real cross-*session* bug: two different Claude Code sessions each with their
own pending approval on the same bot could silently steal each other's decision. That fix doesn't
relax this rule; still dispatch sequentially within one session, it just means a *different*
session's pending approval no longer breaks yours.)

**Show the reviewer the whole batch, not just the one item being decided.** Real incident, 14 Aug
2026: the first of a 3-message sequence got declined as "lacking detail" — the missing detail was
actually in messages 2 and 3, which the reviewer hadn't seen yet, because each gate only showed
its own item. Fix: build the full plain-text preview of every item in the batch once, then pass it
as `--batch-preview` on **every** gate call in that batch (not just the first) — it's appended
under a "Full sequence" heading so whichever item is currently under review, the reviewer still
sees the complete plan before approving/declining just that piece.

**When "send this" logically includes documents, sending them is part of the same action — not a
separate step that needs a fresh explicit request.** If the operator asks to message a recipient
about something that has an obvious document to go with it (a proposal, a contract, a gameplan
already sitting in `clients/<slug>/`), draft the message *and* the file caption(s) up front, then
run all the gates sequentially and send each as it's approved — don't stop after the text message
and wait to be told separately to "send the docs too." Determining *which* documents (e.g. a
superseded doc vs. the current one — check for "Supersedes ..." language in the docs themselves
before assuming an older numbered file is still current) still needs judgment, but once that's
decided, delivering the full set is one continuous flow, gated per-item, not a manual step per file
requiring a new prompt each time.

## wacli send mechanics — use the real feature, don't fake it with text

This skill governs *voice*, not *mechanism* — but the two are easy to conflate, so be explicit about
which `wacli send <subcommand>` a piece of content actually needs. Don't simulate a poll, a file, or a
voice note as a plain text message when wacli has a dedicated command for it:

- `wacli send text --to <jid> --message "..."` — plain message.
- `wacli send file --to <jid> --file <path> --caption "..."` — a document/image/video with a caption.
  The caption gets the same voice-matching treatment as a text message (Steps 1-5 above) — it's still
  a message Vincent is "saying," just attached to a file.
- `wacli send poll --to <jid> --question "..." --option "..." --option "..." [--multi N]` — a real
  WhatsApp poll (2-12 options, single-select unless `--multi` is set). The `--question` text gets the
  same voice-matching treatment; the `--option` values are usually proper nouns/short labels and don't
  need it. Verify with `wacli send poll --help` if a flag's behavior is in doubt rather than assuming.
- `wacli send voice` / `wacli send sticker` / `wacli send status` / `wacli send react` exist too —
  check `wacli send --help` for the full list before assuming text/file/poll are the only options.

If asked to "make a poll," "attach a file," etc., confirm which subcommand you're about to run (and
show the exact command) before sending — the same per-send approval in Step 6 covers the mechanism,
not just the wording.
