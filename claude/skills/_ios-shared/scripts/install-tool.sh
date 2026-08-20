#!/usr/bin/env bash
# install-tool.sh — Idempotent tool installer used by every audit's Phase 0.
#
# Detects whether a tool is installed; if not, prompts the user once,
# installs via brew or pip, and verifies. Returns 0 on success (tool is
# present at exit), non-zero on failure or user rejection.
#
# Usage:
#   install-tool.sh <tool> [<install-cmd>]
#
# Recognized tools (default install commands):
#   swiftlint      → brew install swiftlint
#   swiftformat    → brew install swiftformat
#   periphery      → brew install periphery
#   xcbeautify     → brew install xcbeautify
#   xcodes         → brew install xcodes
#   mobsfscan      → pip install mobsfscan
#   maestro        → already installed at ~/.maestro/bin/maestro
#   proxyman       → brew install --cask proxyman
#
# Custom: install-tool.sh foo "brew install custom-formula"

set -eu

TOOL="${1:?tool name required}"
CUSTOM_CMD="${2:-}"

# Detection table
detect() {
    case "$1" in
        swiftlint|swiftformat|periphery|xcbeautify|xcodes|maestro)
            command -v "$1" > /dev/null 2>&1
            ;;
        mobsfscan)
            command -v mobsfscan > /dev/null 2>&1 || pip show mobsfscan > /dev/null 2>&1
            ;;
        proxyman)
            [ -d "/Applications/Proxyman.app" ]
            ;;
        *)
            command -v "$1" > /dev/null 2>&1
            ;;
    esac
}

default_install() {
    case "$1" in
        swiftlint|swiftformat|periphery|xcbeautify|xcodes)
            echo "brew install $1"
            ;;
        mobsfscan)
            echo "pip install --user mobsfscan"
            ;;
        proxyman)
            echo "brew install --cask proxyman"
            ;;
        maestro)
            echo "# Maestro install handled separately; see ios-tech-baseline.md"
            ;;
        *)
            echo ""
            ;;
    esac
}

# Already present?
if detect "$TOOL"; then
    echo "[install-tool] $TOOL already installed."
    exit 0
fi

CMD="${CUSTOM_CMD:-$(default_install "$TOOL")}"
if [ -z "$CMD" ]; then
    echo "[install-tool] Unknown tool: $TOOL. Pass a custom install command as 2nd arg."
    exit 2
fi

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "  Audit tool not installed: $TOOL"
echo ""
echo "  Will run:  $CMD"
echo "════════════════════════════════════════════════════════════════"
echo ""

# Skip the prompt if non-interactive (CI, agent context).
if [ ! -t 0 ]; then
    echo "[install-tool] Non-interactive shell; auto-installing $TOOL."
    REPLY="y"
else
    printf "Install %s now? [y/N] " "$TOOL"
    read -r REPLY
fi

case "$REPLY" in
    y|Y|yes|YES)
        eval "$CMD"
        if detect "$TOOL"; then
            echo "[install-tool] $TOOL installed."
            exit 0
        else
            echo "[install-tool] Install command ran but $TOOL still not detectable."
            exit 1
        fi
        ;;
    *)
        echo "[install-tool] Skipped. The audit's pass that depends on $TOOL will be marked SKIPPED in the report."
        exit 1
        ;;
esac
