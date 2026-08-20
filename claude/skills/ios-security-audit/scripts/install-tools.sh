#!/usr/bin/env bash
# install-tools.sh — Install mobsfscan + optionally Proxyman for /ios-security-audit.
#
# Idempotent. Called by the skill's Phase 0.

set -eu
HERE="$(cd "$(dirname "$0")" && pwd)"
SHARED="$HOME/.claude/skills/_ios-shared/scripts"

"$SHARED/install-tool.sh" mobsfscan || echo "[install-tools] mobsfscan skipped; --skip-mobsf will work."

# Proxyman is optional and only needed for cert-pinning runtime probes.
# Don't auto-prompt; require explicit invocation:
if [ "${WITH_PROXYMAN:-}" = "1" ]; then
    "$SHARED/install-tool.sh" proxyman
fi

echo "[install-tools] /ios-security-audit dependencies ready."
