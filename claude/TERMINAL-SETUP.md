# Claude Code terminal setup — how to use and how to rebuild

Everything here lives under `~/.claude/`, which is **user-level**. It loads in
every session, in every project, automatically. There is nothing to run or
enable per session.

## Files

| File | Purpose |
|---|---|
| `statusline.ps1` | 3-row mission-control status line |
| `prompt-boost.ps1` | ctrl+g prompt rewriter (stands in for `$VISUAL`) |
| `prompt-boost.system.md` | rewriter instructions + few-shot examples |
| `prompt-boost.mcp.json` | empty MCP config, keeps the rewrite subprocess fast |
| `prompt-boost.log` | one line per ctrl+g press — check here first when it misbehaves |
| `prompt-boost.last.txt` | your text before the last rewrite (recovery) |
| `keybindings.json` | diff panel + session tab bindings |
| `v-claude-bg-terminal.png` | Windows Terminal background |
| `settings.json` | wires up `statusLine` and `VISUAL` |

## Daily use

**ctrl+g — rewrite the prompt you are typing.** ~4–6s.

| You typed | ctrl+g does |
|---|---|
| normal text | rewrites it, sharper |
| `+text` | rewrites with project-local CLAUDE.md too (slower) |
| `/skills`, or any `/cmd` anywhere | leaves it alone |
| `[Image #1]`, `[Pasted text #2 +40 lines]` | leaves it alone |
| `#note` | leaves it alone |
| "fix these", "do it", "the second one" | leaves it alone (no conversation context) |
| empty | nothing |

It never opens an editor. Original always recoverable from
`prompt-boost.last.txt`.

**Keybindings** (`ctrl+k` then the letter):

| Keys | Action |
|---|---|
| `ctrl+k d` | toggle diff panel |
| `ctrl+k f` | show/hide tests in diff |
| `ctrl+k b` | cycle diff base |
| `ctrl+k s` | show/hide pre-session changes |
| `ctrl+k t` | new session tab |
| `ctrl+k n` / `ctrl+k p` | next / previous tab |
| `ctrl+k 1..3` | jump to tab |

The diff panel needs **a git repo** and a **wide terminal**. It silently
declines otherwise — that is not a bug.

Other built-ins worth knowing: `/tui fullscreen` (renderer), `/focus`
(minimal view, needs fullscreen renderer), `ctrl+o` transcript, `ctrl+t` todos.

## Panes and the sidebar

Claude Code has no split panes, no file explorer and no arbitrary-file viewer —
its only panel is hardcoded to git diffs. These live in Windows Terminal instead,
which is the same shape as Claude Code's own answer on macOS (it drives tmux and
iTerm2 panes for teammate sessions).

`alt+shift+*` throughout, because Claude Code itself owns plain `alt+p/o/t/w/v/j`
and `alt+up`/`alt+down`.

| Keys | Action |
|---|---|
| `alt+shift+s` | open the **sidebar** pane on the right (32%) |
| `alt+shift+e` / `alt+shift+o` | split right / split down |
| `alt+shift+←↑↓→` | move focus between panes |
| `alt+shift+,` / `alt+shift+.` | resize pane |
| `alt+shift+z` | zoom the focused pane full-screen |
| `alt+shift+w` | close pane |
| `alt+shift+d` | duplicate pane (pre-existing) |

**The sidebar** (`sidebar.ps1`) has two modes:

- **no target** — file tree of the repo, via `git ls-files`, so `.gitignore` is
  respected and `node_modules` never appears
- **a target** — that file with line numbers, re-rendering when it changes

Point it at a file:

```bash
echo C:/path/to/file.php > ~/.claude/sidebar.target   # show a file
: > ~/.claude/sidebar.target                          # back to the tree
```

Ask Claude to "show X in the sidebar" and it writes that file for you. The root
auto-follows whichever project the newest live Claude Code session is in, so it
tracks you across projects; override with `-Root`.

It repaints only when the content key changes, so text stays selectable. To edit,
focus the pane and run `vim`/`nano` there — there is still no in-app editor.

## Rebuilding on a new machine

**Use the existing export first:** `github.com/vtion001/claude-setup` (private)
has a bundle + `install.ps1` covering all three config surfaces (`~/.claude/`,
`~/.claude.json`, Windows Terminal `settings.json`). Re-export before relying on
it — the bundle goes stale the moment anything here changes.

Manual fallback:

1. Copy `~/.claude/` files from the table above.
2. Fix the absolute paths — they are hardcoded:
   - `settings.json` → `statusLine.command`, `env.VISUAL`
   - `prompt-boost.ps1` → `$ClaudeExe` (currently `D:\npm-global\claude.cmd`)
3. Add to `settings.json`:
   ```jsonc
   "env": {
     "VISUAL": "powershell -NoProfile -ExecutionPolicy Bypass -File <HOME>/.claude/prompt-boost.ps1"
   },
   "statusLine": {
     "type": "command",
     "command": "powershell -NoProfile -ExecutionPolicy Bypass -File <HOME>/.claude/statusline.ps1",
     "padding": 0, "refreshInterval": 5
   }
   ```
4. Windows Terminal background — `profiles.defaults` in its `settings.json`:
   ```jsonc
   "backgroundImage": "<HOME>/.claude/v-claude-bg-terminal.png",
   "backgroundImageOpacity": 0.35,
   "backgroundImageStretchMode": "uniform",
   "backgroundImageAlignment": "center",
   "background": "#000000", "opacity": 100, "useAcrylic": false
   ```
   Put it in `defaults`, not one profile, or only that profile gets it.
5. Restart Claude Code (settings `env` and `statusLine` are read at startup).
   `keybindings.json` and `prompt-boost.ps1` are re-read live.

## Verify

```bash
powershell -NoProfile -File ~/.claude/statusline.ps1 < ~/.claude/statusline.last.json
printf 'make the login faster' > /tmp/b.md
powershell -NoProfile -File ~/.claude/prompt-boost.ps1 "$(cygpath -w /tmp/b.md)"; cat /tmp/b.md
tail -5 ~/.claude/prompt-boost.log
```

To capture a fresh status line payload: `touch ~/.claude/statusline.debug`,
restart, inspect `statusline.last.json`, then delete the flag file.

## Gotchas already hit

- **Rewrite slow (>10s)?** `MAX_THINKING_TOKENS=0` is set on the subprocess in
  `prompt-boost.ps1`. Without it, Haiku burns ~1,500 thinking tokens and takes
  13–26s instead of ~5s.
- **Rewriter asks a question / answers instead of rewriting?** It has no
  conversation history. The script rejects meta-output and keeps your original;
  check `prompt-boost.log` for `REJECTED`.
- **Status line blank?** It exits silently on a JSON parse error. Feed it a
  payload by hand (see Verify). A BOM in the file will break it.
- **Terminal background missing?** Check it is in `profiles.defaults`, that
  `useAcrylic` is false and `opacity` is 100, and that the image path resolves.
  Windows Terminal reverts to built-in defaults on any JSON parse error.
- **Tofu boxes in the status line?** Set `$NERD = $false` near the top of
  `statusline.ps1`.
- **No external editor anymore.** `$VISUAL` is the rewriter, so both `ctrl+g`
  and `ctrl+x ctrl+e` run it. Use the IDE extension, or restore an escape hatch
  in `prompt-boost.ps1`.
