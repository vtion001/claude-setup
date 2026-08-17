---
name: ios-dev-workbench
description: >
  iOS / SwiftUI developer workbench. Not an audit — this is a setup +
  reference skill. Wires + validates the MCP servers most useful for
  SwiftUI development (Figma Dev Mode MCP, XcodeBuildMCP, Apple Docs
  MCP, SwiftLens / SourceKit-LSP) and bundles deep references for
  Apple HIG, SF Symbols, WWDC sessions, and Swift evolution proposals.

  Triggers: "ios dev setup", "ios workbench", "configure ios mcp",
  "set up xcodebuildmcp", "set up figma mcp", "ios reference",
  "/ios-dev-workbench", "validate ios mcp servers".

  Flags:
    --check          # Validate MCP servers and print status (default)
    --install        # Install missing MCPs (npx wrappers + config)
    --print-config   # Print Claude Code MCP config snippets to add

  Sibling skills:
    - /swiftui-ux-audit  uses Maestro (already installed)
    - All 6 ios-*-audit skills use the references this workbench bundles
---

# iOS Dev Workbench

This skill is your iOS-development knowledge base + MCP-server
orchestrator. It validates that the four iOS-relevant MCP servers are
installed + reachable, prints the exact Claude Code config to add, and
points at the canonical references (HIG, WWDC, Swift API Design,
Maestro, etc.) every iOS audit cites.

## Prerequisites

- macOS with Xcode 26.5
- Node.js 18+ for `npx`-based MCPs (`brew install node` if missing)
- Anthropic Claude Code config file at `~/.config/claude-code/mcp.json`
  or `~/Library/Application Support/Claude/claude_desktop_config.json`

## Invocation

```
/ios-dev-workbench                      # Default: validate + print status
/ios-dev-workbench --install            # Install missing MCPs
/ios-dev-workbench --print-config       # Print MCP config snippets
```

## Workflow

### Phase 0: Status check

For each MCP server in the list, probe whether it's installed and
reachable. Print a 4-column status table:

```
MCP                   Installed   Reachable   Required for
─────────────────────────────────────────────────────────────
XcodeBuildMCP         ✓           ✓           qa, ui-impl, security
Figma Dev Mode MCP    ✓           ✗*          design handoff
Apple Docs MCP        ✓           ✓           integration, security
SwiftLens MCP         ✗           N/A         code-review, ui-impl

* Figma Dev Mode requires Xcode 27 beta; you're on 26.5.
```

### Phase 1: Print config (when `--print-config`)

Emit ready-to-paste blocks for Claude Code's MCP config file.

### Phase 2: Install (when `--install`)

For each missing MCP, run the install command after user confirmation.

## MCP Servers (the four)

### 1. XcodeBuildMCP
**Repo:** https://github.com/getsentry/XcodeBuildMCP
**Install:** `npm i -g xcodebuildmcp` or `npx -y xcodebuildmcp@latest`
**Config:**
```json
{
  "mcpServers": {
    "xcodebuild": {
      "command": "npx",
      "args": ["-y", "xcodebuildmcp@latest", "mcp"]
    }
  }
}
```
**Used by:** `/ios-qa-audit`, `/ios-ui-impl-audit`, `/ios-security-audit`.
Runs xcodebuild, controls simulators, reads .xcresult bundles.

### 2. Figma Dev Mode MCP
**Docs:** https://help.figma.com/hc/en-us/articles/41061095668759-Xcode-and-Figma-Set-up-the-MCP-server
**Requirements:** Xcode 27 beta + Figma Dev Mode subscription
**Config:** Configured inside Figma desktop app; Claude Code reads via
MCP socket.
**Used by:** Design handoff (audits cross-check vs Figma when present).

### 3. Apple Docs MCP
**Repo (kimsungwhee):** https://lobehub.com/mcp/kimsungwhee-apple-docs-mcp
**Install:** `npm i -g apple-docs-mcp` or use the `npx` form below.
**Config:**
```json
{
  "mcpServers": {
    "apple-docs": {
      "command": "npx",
      "args": ["-y", "@kimsungwhee/apple-docs-mcp"]
    }
  }
}
```
**Used by:** `/ios-integration-audit`, `/ios-security-audit`,
`/ios-ui-impl-audit` for HIG / Platform Security / framework lookups.

### 4. SwiftLens MCP
**Repo:** https://github.com/swiftlens/swiftlens
**Install:** `pip install swiftlens` then run `swiftlens mcp`
**Config:**
```json
{
  "mcpServers": {
    "swiftlens": {
      "command": "swiftlens",
      "args": ["mcp"]
    }
  }
}
```
**Used by:** `/ios-code-review`, `/ios-ui-impl-audit` for semantic
Swift queries via SourceKit-LSP.

## Additional configured tools (already present per prior plan)

- **Maestro CLI** at `~/.maestro/bin/maestro` — used by `/swiftui-ux-audit`,
  `/ios-qa-audit`. Already in PATH.
- **OpenJDK 17** at `/opt/homebrew/opt/openjdk@17` — required for Maestro.
- **`DEVELOPER_DIR`** pinned to Xcode.app in `~/.zshrc`.

## Reference catalog

The audits all cite this catalog. Each entry has a URL the audit
references when writing findings.

See `references/hig.md`, `references/wwdc.md`, `references/swift-evolution.md`,
`references/sf-symbols.md`, `references/owasp-mas.md`.

## Rules

- **Don't auto-install Node.js.** If `npx` missing, fail loud with the
  brew install command.
- **Don't auto-write to Claude Code config files.** Always print the
  snippet for the user to paste — config-file format varies per host
  (CLI vs Desktop vs Cursor vs Windsurf).
- **MCP install rejection is fine.** Audits gracefully degrade when an
  MCP isn't available.

## Reference files

- `references/hig.md` — Apple HIG sections every audit cites
- `references/wwdc.md` — WWDC sessions by topic
- `references/swift-evolution.md` — Accepted SE-XXXX proposals worth adopting
- `references/sf-symbols.md` — SF Symbols categories + browser link
- `references/owasp-mas.md` — OWASP MASVS / MASTG control IDs
- `references/mcp-config-templates.md` — All 4 MCP config blocks
- `scripts/check-mcps.sh` — Probe each MCP for installation
- `scripts/install-mcps.sh` — Install via npm + pip after confirmation
