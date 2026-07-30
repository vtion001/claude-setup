---
name: Telegram Bot for Reports & Screenshots
description: Telegram bot credentials and chat ID for sending QA screenshots, audit reports, and deliverables to Vincent across all projects
type: reference
---

Telegram bot for delivering screenshots, audit reports, and other artifacts directly to Vincent.

**Config location:** `C:\Users\VJ_Rodriguguez\.openclaw\openclaw.json` → `channels.telegram`

**Bot token:** `${TELEGRAM_BOT_TOKEN}`
**Chat ID:** `${TELEGRAM_CHAT_ID}`
**Bot name:** Yana (@Yuri_FX_Signal_Bot)

**How to send:**
- Text: `curl -s -X POST "https://api.telegram.org/bot${BOT}/sendMessage" --data-urlencode "chat_id=${CHAT}" --data-urlencode "text=message"`
- Photo: `curl -s -X POST "https://api.telegram.org/bot${BOT}/sendPhoto" -F "chat_id=${CHAT}" -F "photo=@path/to/file.png" -F "caption=description"`
- Document: `curl -s -X POST "https://api.telegram.org/bot${BOT}/sendDocument" -F "chat_id=${CHAT}" -F "document=@path/to/file.md" -F "caption=description"`
- Use `--data-urlencode` for text (not `-d`) to handle special characters
- For Markdown formatting in text messages, add `--data-urlencode "parse_mode=Markdown"`

**When to use:** Whenever the user asks to send screenshots, reports, or files to Telegram. Also proactively offer when completing QA audits, UX audits, or visual verification passes.
