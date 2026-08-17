#!/bin/bash
# Render an ALTO information memorandum by running the EXISTING design-system
# pipeline on the ALTO Mac-mini via SSH — never reimplements or edits that
# pipeline locally. Uploads a context.json, runs generate-media.sh remotely,
# downloads the resulting PDF.
#
# Usage: render-remote.sh <local-context.json> <local-output.pdf> [remote-out-name]
#
# information-memorandum.html is a fixed, bespoke design (Georgia serif,
# cream background, red/#d23f1f headings) rebuilt 2026-08-07 to match
# "Variant A — Classic ALTO style", the one-off document already reviewed
# and sent to Josh. It does NOT use the shared classic/bold/editorial
# --variant CSS system other design-system templates use — there is only
# one canonical look for this document type, so no --variant flag is passed.
set -euo pipefail

CTX_LOCAL="$1"
PDF_LOCAL="$2"
REMOTE_NAME="${3:-information-memorandum-$(date +%s).json}"

HOST="altoproperty@100.114.165.87"
REMOTE_BASE="/Users/altoproperty/.openclaw/workspace"
REMOTE_CTX="/tmp/${REMOTE_NAME}"
REMOTE_OUT="/tmp/$(basename "$REMOTE_NAME" .json).pdf"

if [ ! -f "$CTX_LOCAL" ]; then
  echo "error: context file not found: $CTX_LOCAL" >&2
  exit 1
fi

echo "-> uploading context to Mac-mini..."
scp -q "$CTX_LOCAL" "${HOST}:${REMOTE_CTX}"

echo "-> rendering via design-system/scripts/generate-media.sh (remote, unmodified)..."
ssh "$HOST" "cd '$REMOTE_BASE' && skills/design-system/scripts/generate-media.sh information-memorandum --context '$REMOTE_CTX' --out '$REMOTE_OUT'"

echo "-> downloading rendered PDF..."
scp -q "${HOST}:${REMOTE_OUT}" "$PDF_LOCAL"

echo "-> cleaning up remote temp files..."
ssh "$HOST" "rm -f '$REMOTE_CTX' '$REMOTE_OUT'"

echo "done: $PDF_LOCAL"
