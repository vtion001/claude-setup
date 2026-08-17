#!/usr/bin/env bash
set -eu
SHARED="$HOME/.claude/skills/_ios-shared/scripts"
"$SHARED/install-tool.sh" swiftlint
"$SHARED/install-tool.sh" swiftformat
"$SHARED/install-tool.sh" periphery
echo "[install-tools] /ios-code-review dependencies ready."
