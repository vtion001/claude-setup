#!/usr/bin/env bash
set -eu
SHARED="$HOME/.claude/skills/_ios-shared/scripts"
"$SHARED/install-tool.sh" xcbeautify
echo "[install-tools] /ios-ui-impl-audit dependencies ready."
