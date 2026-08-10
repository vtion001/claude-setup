#!/usr/bin/env bash
# Send N UI-variant mockups to Telegram: a header message, then for each
# variant a preview screenshot (sendPhoto) followed by its actual .html file
# (sendDocument). Pairs are matched by basename: variants/A-foo.png with
# variants/A-foo.html — anything without a matching .png just sends the file.
#
# Credentials: export BOT and CHAT first (they live in the workspace CLAUDE.md
# — NEVER hardcode them here).
#   export BOT="<bot-token>"; export CHAT="<chat-id>"
#
# Header text goes through a FILE, not an inline -F/--data-urlencode string —
# Telegram's API has rejected non-ASCII (em dashes, curly quotes, middle dots)
# passed inline on some shells with a "text must be encoded in UTF-8" 400,
# even though the same text in a UTF-8 file works fine via --data-urlencode
# "text@file". Per-variant captions below stay plain ASCII for the same
# reason (hyphens, not em dashes) — keep it that way rather than reintroducing
# the bug.
#
# Usage: send-telegram-variants.sh <variants-dir> <header-file.txt>
set -euo pipefail

DIR="${1:?usage: send-telegram-variants.sh <variants-dir> <header-file.txt>}"
HEADER_FILE="${2:?usage: send-telegram-variants.sh <variants-dir> <header-file.txt>}"
: "${BOT:?export BOT=<bot-token> (from CLAUDE.md)}"
: "${CHAT:?export CHAT=<chat-id> (from CLAUDE.md)}"

api() { curl -s -X POST "https://api.telegram.org/bot${BOT}/$1" "${@:2}"; }
check() { echo "$1" | grep -q '"ok":true' && echo "  OK  $2" || { echo "  FAIL $2"; echo "$1" | head -c 300; echo; return 1; }; }

check "$(api sendMessage --data-urlencode "chat_id=${CHAT}" --data-urlencode "parse_mode=Markdown" --data-urlencode "text@${HEADER_FILE}")" "header"

for html in "$DIR"/*.html; do
  [ -e "$html" ] || continue
  base="${html%.html}"
  png="${base}.png"
  name="$(basename "$base")"
  if [ -e "$png" ]; then
    check "$(api sendPhoto -F "chat_id=${CHAT}" -F "photo=@${png}" -F "caption=${name}")" "$name preview"
  fi
  check "$(api sendDocument -F "chat_id=${CHAT}" -F "document=@${html}" -F "caption=${name}.html")" "$name file"
done
echo "done."
