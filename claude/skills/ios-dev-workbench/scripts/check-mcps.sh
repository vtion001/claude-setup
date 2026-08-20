#!/usr/bin/env bash
# check-mcps.sh — Probe each iOS-relevant MCP for installation.
set -eu

echo "MCP                   Installed   Notes"
echo "──────────────────────────────────────────────────────────────"

# Node + npx baseline
if command -v npx > /dev/null 2>&1; then
    NODE_OK="✓"
else
    NODE_OK="✗"
fi
echo "Node.js (for npx)     $NODE_OK"

# XcodeBuildMCP — npx-loadable
if npx --no-install xcodebuildmcp --version > /dev/null 2>&1; then
    echo "XcodeBuildMCP         ✓           run via 'npx -y xcodebuildmcp@latest mcp'"
else
    echo "XcodeBuildMCP         ⏳          npx pulls on first use (no install required)"
fi

# Apple Docs MCP — npx-loadable
if npx --no-install @kimsungwhee/apple-docs-mcp --version > /dev/null 2>&1; then
    echo "Apple Docs MCP        ✓           run via 'npx -y @kimsungwhee/apple-docs-mcp'"
else
    echo "Apple Docs MCP        ⏳          npx pulls on first use"
fi

# SwiftLens — pip-installed
if command -v swiftlens > /dev/null 2>&1; then
    echo "SwiftLens             ✓           $(swiftlens --version 2>/dev/null || echo 'installed')"
else
    echo "SwiftLens             ✗           install: pip install swiftlens"
fi

# Figma Dev Mode MCP — desktop-app-managed
if [ -d "/Applications/Figma.app" ]; then
    echo "Figma Dev Mode MCP    ◐           Figma installed; enable in Dev Mode → MCP Server"
else
    echo "Figma Dev Mode MCP    ✗           install Figma desktop app first"
fi

# Maestro CLI
if command -v maestro > /dev/null 2>&1; then
    echo "Maestro CLI           ✓           $(maestro --version 2>&1 | head -1)"
else
    echo "Maestro CLI           ✗           see ~/.claude/skills/_ios-shared/ios-tech-baseline.md"
fi

# Java (Maestro dep)
if java -version > /dev/null 2>&1; then
    JV=$(java -version 2>&1 | head -1 | awk -F'"' '{print $2}')
    echo "Java (for Maestro)    ✓           $JV"
else
    echo "Java (for Maestro)    ✗           brew install openjdk@17"
fi
