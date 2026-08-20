# Claude Code Setup — Portable Export

A portable snapshot of a Claude Code configuration: settings, statusline, terminal
background, skills, commands, hooks and helper scripts. Clone it on a new machine,
run one script, and the setup is reproduced.

Originally exported from Windows 11 · Claude Code 2.1.x. Last synced from macOS
2026-08-21 — `claude/` now reflects both machines' skills/agents/commands as of
that date, plus a redacted MCP server export (`mcp.json.example`, new this sync);
`install.ps1` (Windows-only) and the ported `.sh` hooks/scripts both still apply,
see "External dependencies" and "Notes" below.

---

## Quick start

```powershell
git clone <this-repo> claude-setup
cd claude-setup

# preview every change without writing anything
powershell -ExecutionPolicy Bypass -File .\install.ps1 -DryRun

# apply
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

Then:

1. Run `claude` — the 74 plugins listed in `settings.json` reinstall themselves from the marketplace on first start.
2. Run `/login` to authenticate. **Credentials are never exported.**
3. Fill in `~/.claude/.env` with your real tokens (see `.env.example`).
4. Restore MCP servers: copy `claude/mcp.json.example`'s `mcpServers` block into your
   `~/.claude.json`, fill in the `<FILL_IN>` placeholders (`magic`/`apify`/`waypoint` need real
   values; the rest need none), then `claude mcp list` to verify.
5. Restart Windows Terminal to pick up the background image.

---

## What's in here

```
claude/                       -> installs to ~/.claude
  settings.json               74 plugins, hooks, statusline, permissions, effort level
  settings.local.json         per-project permission allowlist
  global-prefs.json           portable subset of ~/.claude.json (10 keys)
  CLAUDE.md                   global instructions (secrets redacted)
  skills/                     128 skills, symlinks dereferenced (includes _archived-2026-08-14/,
                               the skill-consolidation project's retired originals)
  mcp.json.example            9 user-scope MCP servers from ~/.claude.json, secrets redacted to
                               <FILL_IN> placeholders. Project-scoped MCP servers (per-repo, `-s
                               local`) are NOT included — those live in each project's own config.
                               claude.ai-connected OAuth connectors (Gmail, Slack, etc.) are
                               account-level, not machine config — re-authenticate via claude.ai,
                               nothing to restore here.
  commands/                   44 commands (code-audit, goal, and per-role agent commands)
  hooks/                      sonar-secrets pre-tool + prompt scanners (.ps1 + .sh)
                               ship-loop deploy-gate + review-log (.ps1 + .sh)
                               stop-respect-active.sh (macOS/Linux Stop-hook safety net)
  memory/                     persistent memory store (secrets redacted)
  statusline.ps1 / .sh        3-row custom statusline (Windows / macOS+Linux)
  prompt-boost.ps1/.sh/.md/.json/-context.py   ctrl+g prompt rewriter
  sidebar.ps1 / .py+-split.sh companion pane: file tree / live file viewer
  local-qwen3.ps1/.sh         local Qwen3 gateway launchers
  package.json

terminal/
  v-claude-bg-terminal.png            terminal background image
  windows-terminal-appearance.json    background/opacity/acrylic settings

docs/
  CHEAT_SHEET.md  CLAUDE_CODE_DEVELOPER_GUIDE.md  QUICK_REFERENCE.md

install.ps1      importer (supports -DryRun, -SkipTerminal)
.env.example     secret template
```

---

## macOS / Linux port

The Windows-only pieces (statusline, prompt-boost, the sidebar companion pane,
sonar-secrets hooks, ship-loop hooks) have native macOS/Linux equivalents
alongside the originals — bash + one small Python helper, no new dependencies
beyond `jq` and `python3`.

`install.ps1` doesn't wire these up (it's Windows-only); on macOS/Linux, copy
`claude/` to `~/.claude` as usual, then add this to `~/.claude/settings.json`
yourself (merge into your existing keys, don't overwrite):

```json
{
  "env": { "VISUAL": "bash /Users/YOU/.claude/prompt-boost.sh" },
  "statusLine": { "type": "command", "command": "bash /Users/YOU/.claude/statusline.sh" },
  "hooks": {
    "PreToolUse": [
      { "matcher": "Read", "hooks": [{ "type": "command",
        "command": "bash /Users/YOU/.claude/hooks/sonar-secrets/build-scripts/pretool-secrets.sh", "timeout": 60 }] },
      { "matcher": "Bash", "hooks": [{ "type": "command",
        "command": "bash /Users/YOU/.claude/hooks/ship-loop/build-scripts/pretool-deploy-gate.sh", "timeout": 30 }] }
    ],
    "UserPromptSubmit": [{ "matcher": "*", "hooks": [{ "type": "command",
      "command": "bash /Users/YOU/.claude/hooks/sonar-secrets/build-scripts/prompt-secrets.sh", "timeout": 60 }] }],
    "SubagentStop": [{ "matcher": "sentinal|verity|aesthetica", "hooks": [{ "type": "command",
      "command": "bash /Users/YOU/.claude/hooks/ship-loop/build-scripts/subagentstop-review-log.sh", "timeout": 15 }] }]
  }
}
```

Notes:
- `prompt-boost.sh` triggers on Claude Code's built-in `ctrl+g` — no separate
  keybinding needed. It reads recent conversation context via
  `prompt-boost-context.py`, asks a `❓`-prefixed clarifying question instead
  of guessing when a reference can't be resolved, and preserves your own
  first-person voice when the draft is answering a question the assistant
  just asked (instead of flipping it into a second-person instruction).
- The sonar-secrets hooks no-op safely if the `sonar` CLI isn't installed —
  same graceful-degrade behavior as the Windows originals.
- The ship-loop hooks back the `ship-loop` skill's 5-subagent virtual team
  (`syntax`/`sentinal`/`verity`/`aesthetica`/`flow` in `claude/agents/`):
  `pretool-deploy-gate.sh` blocks deploy-shaped Bash commands (`vercel --prod`,
  `git push origin main`, etc.) unless a quality-gate marker for that
  directory is less than 4 hours old; `subagentstop-review-log.sh` appends a
  JSONL audit line to `~/.claude/hooks/ship-loop/logs/review-log.jsonl` every
  time a review subagent finishes. Both are backstops only — the skill's own
  GATE step and explicit user confirmation are the primary controls.
- `sidebar.py` is a standalone companion pane (file tree when idle, live
  file viewer when pointed at a target via `~/.claude/sidebar.target`) — pair
  it with `sidebar-split.sh` and a terminal profile/keybinding of your choice
  to split it into a new pane (an iTerm2 example: create a profile with
  Custom Command `python3 ~/.claude/sidebar.py`, then use AppleScript's
  `split vertically with profile "<name>"` or a Key Mapping bound to
  `KEY_ACTION_SPLIT_VERTICALLY_WITH_PROFILE`).
- `statusline.sh` auto-detects CPU/MEM via native macOS calls and falls back
  to ASCII (`@`, `PR`) instead of Nerd Font glyphs if none is installed.

---

## Why it's not a raw folder copy

The live `.claude` directory is **573 MB**, and most of it neither belongs in git nor
transfers meaningfully. Three things make a straight copy fail:

| Problem | Handling |
|---|---|
| `downloads/claude-2.1.96-win32-x64.exe` is 170 MB | Excluded — GitHub hard-rejects files >100 MB |
| `plugins/cache/` (267 MB) contains nested `.git` repos | Excluded — they'd commit as broken submodule pointers. Plugins reinstall from `settings.json` |
| `.credentials.json` holds live OAuth tokens | Excluded — re-authenticate with `/login` |
| `projects/` (67 MB) is conversation transcripts | Excluded — client/project content, not configuration |
| Config spans 3 locations, not 1 | Bundle pulls from `.claude/`, `~/.claude.json` and Windows Terminal |

The configuration that actually defines the setup is ~5.3 MB of the 573 MB.

### Three config surfaces

A Claude Code setup is not stored in one place:

1. **`~/.claude/`** — settings, skills, hooks, scripts
2. **`~/.claude.json`** — global prefs, mixed with machine-bound identity (`userID`,
   `machineID`, `oauthAccount`, 25 project paths). Only 10 genuine preference keys were
   extracted; the other 68 keys were deliberately left behind.
3. **Windows Terminal `settings.json`** — the background image and opacity

### Path rewriting

The exporting machine's absolute paths appear in 60 places across 4 encodings
(`C:/Users/X`, `C:\Users\X`, JSON-escaped `C:\\Users\\X`, and Git-Bash `//c/Users/X`).
`install.ps1` rewrites the profile name in every text file, so a machine with a
different Windows username works without manual edits.

---

## Security

No live secrets are committed. Before export:

- `.credentials.json` (Claude OAuth tokens) — **excluded entirely**
- `~/.claude.json` `oauthAccount` / `userID` / `machineID` — **excluded**
- A Telegram bot token appeared in **7 places** across `CLAUDE.md`,
  `memory/reference_telegram_bot.md` and `skills/ags-monitor/SKILL.md` — all replaced
  with `${TELEGRAM_BOT_TOKEN}` / `${TELEGRAM_CHAT_ID}` placeholders
- Bundle was scanned for OpenAI/GitHub/Google/AWS/Slack keys, JWTs and private keys — clean
- **2026-08-18 re-sync:** re-scanned with the same pattern set plus a broader
  password/api-key/token keyword pass — clean, one real finding: `video-kit/.env`
  (live Pexels + Pixabay API keys) was caught by the existing `.gitignore` rule and
  never staged; added `video-kit/.env.example` (placeholder keys) so the skill's
  env requirements are still documented.

Real values go in `~/.claude/.env`, which `.gitignore` blocks.

> Even so, keep this repo **private**. `settings.local.json`, `memory/` and the skills
> describe internal projects, infrastructure and client work.

---

## External dependencies

As of the 2026-08-18 macOS sync, 11 skills are symlinks to a repo outside `.claude` —
all of them into VJR-Digital-Solutions now (the `ags-*` skills that used to be
symlinks on Windows are plain directories on this machine). They've been
**dereferenced** (real content copied in) for this bundle, so it's self-contained —
but they are snapshots. If you still maintain the source repo, re-link after install:

| Skills | Original source |
|---|---|
| `vjr-os`, `vjr-marketing`, `vjr-status`, `vjr-acquire-leads`, `vjr-deliver-project`, `vjr-quote-to-cash`, `vjr-client-sync`, `vjr-community-sync`, `vjr-notify-openclaw`, `vjr-legal-case-file`, `wacli-msg` | `~/Desktop/VJR-Digital-Solutions/skills/` (macOS) / `Desktop\Repository\VJR-Digital-Solutions\skills\` (Windows) |

Some skills also assume machine-specific tooling: `gh.exe` at
`/mnt/c/Program Files/GitHub CLI/`, a local Qwen3 gateway on `127.0.0.1:8787`, and a
D:-drive install convention.

---

## Notes

- `install.ps1` backs up the existing `~/.claude` to `~/.claude-backup-<timestamp>` and
  `~/.claude.json` to `.backup-<timestamp>` before writing. Nothing is destroyed.
- Preference merging is additive — your existing login and identity keys are untouched.
- Windows-oriented. On macOS/Linux the `claude/` tree still drops into `~/.claude`, but
  the PowerShell hook and statusline commands in `settings.json` need porting.

## Re-exporting

After changing your setup, refresh this bundle by re-running the export, or copy
individual files back into `claude/` — remembering to redact secrets first.
