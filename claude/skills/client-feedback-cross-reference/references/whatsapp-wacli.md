# WhatsApp via `wacli`

`wacli` is a local WhatsApp CLI (`~/.wacli` store, binary usually on PATH — confirm with `which wacli`, don't assume). Use `--read-only` for anything that only reads, so a mistake can't send or mutate WhatsApp state.

## Pull the thread

```bash
wacli --read-only messages list --chat <phone>@s.whatsapp.net --json --limit 60
```

- Save to a file and parse with `python3 -c "import json..."` rather than piping through `grep`/`tail` on the raw JSON — a single message can contain newlines, quotes, and long text that breaks naive shell text-processing, and `tail -c N` on a large JSON blob truncates from the **front** of the array if the tool returns newest-first, silently dropping the most recent messages instead of the oldest. Confirm the actual sort order empirically (check two adjacent timestamps) before assuming which end you're looking at.
- Sort the parsed messages by `Timestamp` yourself before reading — don't assume the returned order is chronological.

## Confirm you have everything (don't trust a stale local copy)

```bash
wacli chats list --json
```

Find the chat's `last_message_ts` and `unread_count`. Compare `last_message_ts` against the newest timestamp your `messages list` call returned. **If they don't match, your local store is behind — sync before doing anything else**, or you will confidently act on an incomplete thread.

## Syncing — the gotcha that will eat 20 minutes if you miss it

`wacli sync` **defaults to `--follow`, a persistent listener that never exits on its own.** Running it as a plain background command and waiting for it to finish is a mistake — it will sit at 0% CPU indefinitely holding the store's write lock (which blocks `media download` with a "store is locked" error), and there is nothing to wait *for*. This happened for real: ~20 minutes lost waiting on a `sync` call that was never going to return, before recognizing the process was idle (not busy) and killing it.

Use the bounded one-shot form instead:

```bash
wacli sync --once --download-media --idle-exit 20s --json
```

`--once` exits after the connection goes idle for `--idle-exit` (default 30s) instead of running forever. This is the form to use for "catch up on what's new" — never the bare `wacli sync`.

If you're already stuck behind a hung `--follow` sync from a previous mistake: find its PID (`ps aux | grep "wacli sync"`), `kill` it (safe — it's your own helper process, not a persistent user-facing service), then re-run with `--once`.

### Even the correct `--once` form can look stuck when it's actually just slow

Real incident, 15 Aug 2026: `wacli sync --once --idle-exit 20s` was launched correctly, ran for
35+ minutes, and repeated `messages list` checks during that window all returned the same stale
data — indistinguishable from a hung process by symptom alone. `wacli doctor` looked like proof of
a stuck sync (`LOCKED=true`, `CONNECTED=false`, `LAST_SYNC` frozen) — but killing the process to
force a flush revealed it had genuinely been catching up on a real backlog the whole time
(`MESSAGES` count jumped +55 on kill, `LAST_SYNC` had actually advanced past what any single
snapshot showed). A slow-but-working sync and a truly-stuck one present identically in one check.

**Don't judge sync health from one `wacli doctor` call — poll it.** Run the sync in the
background, then poll `LAST_SYNC` every few seconds; if it's advancing (even slowly), it's
working, let it continue. Only kill it once `LAST_SYNC` has stopped advancing across 2-3
consecutive checks, or once `chats list`'s `last_message_ts` (see the section above) confirms
you're caught up. Killing an in-progress `--once` sync is always safe — it forces a flush of
whatever's already fetched, it never loses data:

```bash
wacli sync --once --idle-exit 20s --json > /tmp/wacli-sync.out 2>&1 &
SYNC_PID=$!
PREV="" STALL=0
while kill -0 "$SYNC_PID" 2>/dev/null; do
  sleep 3
  CUR=$(wacli doctor 2>&1 | awk '/LAST_SYNC/{print $2}')
  [ "$CUR" = "$PREV" ] && STALL=$((STALL+1)) || STALL=0
  PREV=$CUR
  [ "$STALL" -ge 3 ] && { kill "$SYNC_PID" 2>/dev/null; break; }
done
echo "final LAST_SYNC: $PREV"
```

Run this whole block as **one** `Bash run_in_background: true` call — it's self-contained and
exits on its own (sync finishes naturally, or 3 stalled checks trigger the kill) — not as repeated
manual `sleep`+check turns, which the harness blocks anyway for foreground waits. One notification
when it's actually done, instead of guessing from a single point-in-time snapshot.

## Media captions — check `Text`/`MediaCaption`, not `DisplayText`

This is the single most consequential gotcha in this whole reference, found the hard way: `wacli`'s message object has a `DisplayText` field that reads `"Sent document"` / `"Sent image"` for **every** media message, whether or not the sender attached a caption. It's a UI label, not the content. The actual caption — if the client wrote one — is in the `Text` field (and duplicated into `MediaCaption`).

If you only print `DisplayText` when scanning the thread (the natural thing to do for a quick chronological read), every media message looks uncaptioned, even ones that explicitly spell out what to do. Real example from a production run: an image that looked like an uncaptioned circled screenshot — printed as `"Sent document"` — actually carried the caption `"image should be the 28 typography image i sent through"`, a fully-specified instruction that got wrongly logged as "ambiguous, needs clarification" because the caption field was never checked.

**Always dump the full message JSON for media items** (not just `DisplayText`) before deciding whether an image is captioned:

```python
# after loading the parsed messages list
for m in msgs:
    if m['MediaType']:
        print(m['MsgID'], '| Text:', repr(m['Text']))  # NOT m['DisplayText']
```

## Downloading media (screenshots, documents the client sent)

`wacli media download` needs the message ID, not just the chat:

```bash
wacli media download --chat <phone>@s.whatsapp.net --id <MsgID> --output <path.jpg> --json
```

Collect every image/document message ID from the parsed thread first, then loop over them. **View every downloaded image before deciding it's irrelevant**, even a captioned one — the caption tells you intent, the image confirms it's the right one. An image with neither caption nor visible annotation is itself a valid "just context, no action" finding — but only once you've actually checked both, not assumed from the filename or from `DisplayText`.

## Sending (separate, gated step)

Sending anything (a text reply, a file) is a distinct, higher-stakes action from reading — never do it as part of a read-only investigation pass, and never send client-facing content without the operator's explicit sign-off on the exact message first. See the "Compose the confirmation message" phase in the parent skill — draft, present, wait for approval, then send.
