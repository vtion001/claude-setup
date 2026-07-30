#!/usr/bin/env bash
# Upload a deliverables folder to Telegram. Sends a header message, each .mp4 as a
# streaming video, and each .pdf/other as a document. Verifies "ok":true per send.
#
# Credentials: export BOT and CHAT first (they live in the workspace CLAUDE.md —
# NEVER hardcode them here).
#   export BOT="<bot-token>"; export CHAT="<chat-id>"
#
# Usage: send-telegram.sh <deliverables-dir> ["<header markdown message>"]
set -euo pipefail

DIR="${1:?usage: send-telegram.sh <dir> [header]}"
HEADER="${2:-*Deliverables package* — files below 👇}"
: "${BOT:?export BOT=<bot-token> (from CLAUDE.md)}"
: "${CHAT:?export CHAT=<chat-id> (from CLAUDE.md)}"

api() { curl -s -X POST "https://api.telegram.org/bot${BOT}/$1" "${@:2}"; }
check() { echo "$1" | grep -q '"ok":true' && echo "  ✓ $2" || { echo "  ✗ $2"; echo "$1" | head -c 300; echo; return 1; }; }

check "$(api sendMessage --data-urlencode "chat_id=${CHAT}" --data-urlencode "parse_mode=Markdown" --data-urlencode "text=${HEADER}")" "header"

for f in "$DIR"/*.mp4; do [ -e "$f" ] || continue
  check "$(api sendVideo -F "chat_id=${CHAT}" -F "supports_streaming=true" -F "video=@${f}")" "$(basename "$f")"
done
for f in "$DIR"/*.pdf; do [ -e "$f" ] || continue
  check "$(api sendDocument -F "chat_id=${CHAT}" -F "document=@${f}")" "$(basename "$f")"
done
echo "done."
