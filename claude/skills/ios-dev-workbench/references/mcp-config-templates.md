# MCP Config Templates

Paste these into your Claude Code MCP config file. Location varies by host:
- **Claude Code CLI**: `~/.config/claude-code/mcp.json`
- **Claude Desktop**: `~/Library/Application Support/Claude/claude_desktop_config.json`
- **Cursor**: `~/.cursor/mcp.json`
- **Windsurf**: `~/.codeium/windsurf/mcp.json`

## XcodeBuildMCP
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

## Apple Docs MCP (kimsungwhee)
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

## SwiftLens
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
Prerequisite: `pip install swiftlens`.

## Figma Dev Mode MCP

Configured inside Figma desktop app (not Claude Code config).
- Open Figma desktop app
- Enable Dev Mode
- Tools → MCP Server → toggle on
- Returns a `figma-dev-mode-mcp-server` endpoint Claude Code reads

Requires **Xcode 27 beta** + an active Figma Dev Mode subscription.

## Combined config (all four at once)

```json
{
  "mcpServers": {
    "xcodebuild": {
      "command": "npx",
      "args": ["-y", "xcodebuildmcp@latest", "mcp"]
    },
    "apple-docs": {
      "command": "npx",
      "args": ["-y", "@kimsungwhee/apple-docs-mcp"]
    },
    "swiftlens": {
      "command": "swiftlens",
      "args": ["mcp"]
    }
  }
}
```

After adding, restart Claude Code (or the host app). MCPs appear in the
`/mcp` slash command.
