#!/usr/bin/env bash
set -eu
SHARED="$HOME/.claude/skills/_ios-shared/scripts"
"$SHARED/install-tool.sh" xcbeautify
# Maestro already installed per prior plan; just verify
if ! command -v maestro > /dev/null 2>&1; then
    echo "[install-tools] WARNING: maestro not in PATH. See ~/.claude/skills/_ios-shared/ios-tech-baseline.md"
fi
echo "[install-tools] /ios-qa-audit dependencies ready."
