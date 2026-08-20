#!/usr/bin/env bash
# install-mcps.sh — Install missing iOS MCPs after user confirmation.
set -eu
SHARED="$HOME/.claude/skills/_ios-shared/scripts"

if ! command -v npx > /dev/null 2>&1; then
    echo "[install-mcps] Node.js missing. Install: brew install node"
    exit 2
fi

# SwiftLens is pip-installable
if ! command -v swiftlens > /dev/null 2>&1; then
    echo ""
    printf "Install SwiftLens (pip install swiftlens)? [y/N] "
    read -r REPLY
    case "$REPLY" in
        y|Y) pip install --user swiftlens ;;
    esac
fi

# XcodeBuildMCP + Apple Docs MCP are npx-on-demand; nothing to install eagerly.
# Print the config snippet to add to Claude Code:
echo ""
echo "Config snippet to add to your Claude Code MCP config file:"
echo "(see ~/.claude/skills/ios-dev-workbench/references/mcp-config-templates.md)"
echo ""
cat "$HOME/.claude/skills/ios-dev-workbench/references/mcp-config-templates.md" | sed -n '/Combined config/,/^```$/p' | head -30
