---
description: Send a message or file from .claude to your Telegram (shared bot with .openclaw)
---

# /tg-send — push to Telegram

Wraps `~/.claude/scripts/tg_send.py`, which uses the bot defined in
`~/.telegram_config.json` (the same bot the `.openclaw` `telegram_gateway`
service uses, so messages land in the same chat).

## When to use
- The user asks you to "send X to my telegram" / "push the doc to telegram" / "ping me on telegram when done".
- You've produced an artifact (plan, report, screenshot, CSV) and the user wants it delivered.

## How to invoke from Bash

```bash
# Plain text
python3 ~/.claude/scripts/tg_send.py --text "build finished ✅"

# Single file with a caption
python3 ~/.claude/scripts/tg_send.py \
  --file ~/.openclaw/plans/OUTREACH-WORKFLOW-PLAN.md \
  --caption "outreach workflow plan v1"

# Multiple files (caption goes on the first one)
python3 ~/.claude/scripts/tg_send.py \
  --file report.md --file chart.png \
  --caption "QA results"
```

## Notes
- `--text` supports Markdown (bold, italics, code). The script falls back to plain text if Telegram rejects the markdown.
- `--file` accepts any file type up to Telegram's 50 MB document limit.
- The script reads bot_token + chat_id from `~/.telegram_config.json` — to point to a different chat, edit that file.
- Exit code 0 = delivered, 2 = Telegram API rejected the request.
