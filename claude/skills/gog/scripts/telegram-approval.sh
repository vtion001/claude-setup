#!/usr/bin/env bash
# Gate for `gog gmail send`: post the drafted email (to/subject/body + attachment
# list) to the ags-approval Telegram bot with Approve/Decline buttons, then poll
# until someone taps one. Exit code is the actual signal — callers branch on it,
# not on stdout.
#
# Exit codes: 0 = approved, 1 = declined, 2 = timed out / no response, 3 = usage/API error.
#
# Usage:
#   telegram-approval.sh --token "$AGS_APPROVAL_BOT_TOKEN" --chat "$AGS_APPROVAL_CHAT_ID" \
#     --to "a@b.com,c@d.com" --subject "Subject line" --body-file draft.txt \
#     --attach "file1.pdf,file2.pdf" [--timeout-secs 900]
#
# Requires: curl, jq (both already on PATH on this machine).
set -euo pipefail

TOKEN="" CHAT="" TO="" SUBJECT="" BODY_FILE="" ATTACH="" TIMEOUT=900
while [[ $# -gt 0 ]]; do
  case "$1" in
    --token) TOKEN="$2"; shift 2 ;;
    --chat) CHAT="$2"; shift 2 ;;
    --to) TO="$2"; shift 2 ;;
    --subject) SUBJECT="$2"; shift 2 ;;
    --body-file) BODY_FILE="$2"; shift 2 ;;
    --attach) ATTACH="$2"; shift 2 ;;
    --timeout-secs) TIMEOUT="$2"; shift 2 ;;
    *) echo "unknown flag: $1" >&2; exit 3 ;;
  esac
done
if [[ -z "$TOKEN" || -z "$CHAT" || -z "$TO" || -z "$SUBJECT" || -z "$BODY_FILE" ]]; then
  echo "missing required flag (--token --chat --to --subject --body-file)" >&2
  exit 3
fi

API="https://api.telegram.org/bot${TOKEN}"
BODY_PREVIEW=$(head -c 800 "$BODY_FILE")
ATTACH_LIST="(none)"
if [[ -n "$ATTACH" ]]; then
  ATTACH_LIST=$(echo "$ATTACH" | tr ',' '\n' | sed 's/^/  \xe2\x80\xa2 /' | paste -sd $'\n' -)
fi

CARD_FILE="$(mktemp)"
{
  echo "*Email approval requested*"
  echo ""
  echo "*To:* ${TO}"
  echo "*Subject:* ${SUBJECT}"
  echo ""
  echo "*Body preview:*"
  echo '```'
  echo "${BODY_PREVIEW}"
  echo '```'
  echo ""
  echo "*Attachments (${ATTACH:+$(echo "$ATTACH" | tr ',' '\n' | wc -l)}${ATTACH:-0}):*"
  echo "${ATTACH_LIST}"
} > "$CARD_FILE"

SEND_RESP=$(curl -sS -X POST "${API}/sendMessage" \
  --data-urlencode "chat_id=${CHAT}" \
  --data-urlencode "parse_mode=Markdown" \
  --data-urlencode "text=$(cat "$CARD_FILE")" \
  --data-urlencode 'reply_markup={"inline_keyboard":[[{"text":"✅ Approve","callback_data":"approve"},{"text":"❌ Decline","callback_data":"decline"}]]}')
rm -f "$CARD_FILE"

if [[ "$(echo "$SEND_RESP" | jq -r '.ok')" != "true" ]]; then
  echo "Telegram sendMessage failed: $SEND_RESP" >&2
  exit 3
fi
MSG_ID=$(echo "$SEND_RESP" | jq -r '.result.message_id')

echo "Approval card posted to Telegram (message_id=${MSG_ID}). Waiting up to ${TIMEOUT}s for Approve/Decline..." >&2

DEADLINE=$(( $(date +%s) + TIMEOUT ))
OFFSET=0
DECISION=""
while [[ $(date +%s) -lt $DEADLINE ]]; do
  UPDATES=$(curl -sS "${API}/getUpdates?timeout=20&offset=${OFFSET}")
  if [[ "$(echo "$UPDATES" | jq -r '.ok')" != "true" ]]; then
    sleep 2; continue
  fi
  COUNT=$(echo "$UPDATES" | jq '.result | length')
  for ((i=0; i<COUNT; i++)); do
    UPDATE=$(echo "$UPDATES" | jq ".result[$i]")
    UPD_ID=$(echo "$UPDATE" | jq -r '.update_id')
    OFFSET=$((UPD_ID + 1))
    CB_MSG_ID=$(echo "$UPDATE" | jq -r '.callback_query.message.message_id // empty')
    CB_DATA=$(echo "$UPDATE" | jq -r '.callback_query.data // empty')
    CB_ID=$(echo "$UPDATE" | jq -r '.callback_query.id // empty')
    if [[ "$CB_MSG_ID" == "$MSG_ID" && -n "$CB_DATA" ]]; then
      curl -sS -X POST "${API}/answerCallbackQuery" \
        --data-urlencode "callback_query_id=${CB_ID}" \
        --data-urlencode "text=$([[ $CB_DATA == approve ]] && echo Approved || echo Declined)" > /dev/null
      DECISION="$CB_DATA"
      break 2
    fi
  done
done

if [[ -z "$DECISION" ]]; then
  curl -sS -X POST "${API}/editMessageText" \
    --data-urlencode "chat_id=${CHAT}" --data-urlencode "message_id=${MSG_ID}" \
    --data-urlencode "text=$(cat <<< "⏱ TIMED OUT — no response within ${TIMEOUT}s. Email NOT sent.")" > /dev/null
  echo "Timed out waiting for approval." >&2
  exit 2
fi

STAMP="$([[ $DECISION == approve ]] && echo '✅ APPROVED' || echo '❌ DECLINED')"
curl -sS -X POST "${API}/editMessageText" \
  --data-urlencode "chat_id=${CHAT}" --data-urlencode "message_id=${MSG_ID}" \
  --data-urlencode "text=${STAMP} — ${SUBJECT}" > /dev/null

if [[ "$DECISION" == "approve" ]]; then
  echo "Approved." >&2
  exit 0
else
  echo "Declined." >&2
  exit 1
fi
