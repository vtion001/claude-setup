---
name: vjr-notify-openclaw
description: >
  Push context into Vincent's OpenClaw agent so it has the full picture and can reply to him on his own
  Telegram. Use when Vincent says "tell openclaw about this", "let openclaw know", "sync this to yuki /
  openclaw", "make sure openclaw has context", or after finishing work in this Claude Code session that
  Vincent will want to continue discussing from his phone (legal/financial/business matters he tracks
  through OpenClaw agents like main/Yuri or yuki).
---

# Notify OpenClaw (deliver to Telegram)

OpenClaw (`~/.openclaw`) is Vincent's separate, always-on agent gateway — its own CLI, own launchd
service, own Telegram bot. This skill pushes a context update into a live OpenClaw agent session and has
it reply on Vincent's actual Telegram, so he can keep the conversation going from his phone instead of
needing this Claude Code session.

## Step 1 — Find the right agent

```bash
openclaw agents list
```

Default target is the `main` agent (identity may show as a name like "Yuri") unless Vincent names a
specific one (e.g. `yuki` for finance-tracker matters — see `~/.openclaw/agents/yuki/agent.md` for its
existing handover-file convention, which is a separate, file-based way to give it context and may be more
appropriate for finance-specific updates than a live delivered message).

## Step 2 — Find the REAL live Telegram session (don't trust the table display)

`openclaw sessions list`'s table truncates session keys and can visually merge two different rows. Read
the actual keys from the session store instead:

```bash
python3 -c "
import json
with open('/Users/archerterminez/.openclaw/agents/<agent>/sessions/sessions.json') as f:
    data = json.load(f)
for k, v in data.items():
    if 'telegram:direct' in k:
        print(k, v.get('updatedAt'), v.get('route', {}).get('target'))
"
```

Pick the session with a **non-empty `route.target.to`** (format `telegram:<chatId>`) and the most recent
`updatedAt` / longest `usageFamilySessionIds` history — that's Vincent's real ongoing DM thread. Skip any
session whose `route`/`deliveryContext` is empty (e.g. a bare `agent:main:telegram:direct:82`-style key
with no `to` field) — that's a stub created by a delivery attempt that had no target, not a real thread.
Attempting `--deliver` against a stub fails with `GatewayClientRequestError: Delivering to Telegram
requires target <chatId>`.

## Step 3 — Deliver

```bash
openclaw agent --session-key "agent:<agent>:telegram:direct:<chatId>" --deliver --json --message "$(cat <context-file>)"
```

Write the context to a scratchpad file first and pass it via `$(cat ...)` — the message is usually
multi-paragraph prose with punctuation that's painful to escape inline. Keep the message factual and
self-contained (this agent has no memory of the Claude Code session that generated it): what happened,
current status, what's still open, and — if relevant — an explicit instruction ("no action needed, just
acknowledge" or "let me know what you think").

Check the JSON result for `"deliverySucceeded": true` / `"deliveryStatus": {"status": "sent"}` before
telling Vincent it went through.

## Notes

- `--deliver` actually pushes a live message to Vincent's own Telegram right now — this is Vincent
  notifying himself via his own agent/bot, not an external send to a third party, so it doesn't need the
  same per-send confirmation gate as messaging someone else. Still worth a one-line heads-up in the reply
  ("pushed to your Telegram") so he's not surprised by his phone buzzing.
- If `openclaw agents list` or `openclaw status` throws a "Doctor warnings" banner about plugin install
  metadata conflicts (brave/google-meet/voice-call), that's a known pre-existing warning — ignore it,
  it doesn't block agent/message commands.
