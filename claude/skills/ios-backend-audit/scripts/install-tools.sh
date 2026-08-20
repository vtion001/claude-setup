#!/usr/bin/env bash
set -eu
SHARED="$HOME/.claude/skills/_ios-shared/scripts"
if [ "${WITH_PROXYMAN:-}" = "1" ]; then
    "$SHARED/install-tool.sh" proxyman
fi
echo "[install-tools] /ios-backend-audit dependencies ready (Proxyman optional)."
