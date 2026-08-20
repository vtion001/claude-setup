---
name: launch-remote-control
description: Programmatically start a remote-controllable `claude` session on this Mac when the operator is away from the computer (e.g. on their phone with no screen/keyboard access). Opens a new Terminal window, launches `claude`, and types `/remote-control` into it via AppleScript — no Accessibility/System Events permission needed. Invoke when the user asks to "start remote control", "open claude and run /remote-control", or otherwise wants a session they can take over from the Claude mobile app.
---

# Launch Remote-Control Claude Session

Starts a `claude` session in `--remote-control` mode on the local Mac so the
operator can take it over from the **Claude mobile app**. The whole point is
remote bootstrap: the user is typically on their phone with no way to type into
the computer, so we drive Terminal programmatically.

## Why AppleScript (not System Events)

`/remote-control` is a Claude Code **UI command** typed at the `claude` prompt —
it cannot be invoked via the Skill tool or as a shell command. To "type" it into
a running TUI we use Terminal's own scripting:

```applescript
set w to do script "claude"          -- opens a window, runs claude in it
delay 8                               -- let the TUI finish loading
do script "/remote-control" in w     -- injects into THAT window's tty (stdin)
```

`do script ... in <window>` writes to the window's tty directly, so it reaches
the running claude process's stdin **without** needing System Events /
Accessibility (which would otherwise require granting the automation app
"control your computer" permission — a non-starter when the user is remote).

## Run

```bash
~/.claude/skills/launch-remote-control/launch.sh [working-dir]
```

- `working-dir` (optional) — directory the session `cd`s into before launching
  claude. Defaults to `~/Desktop/REPOSITORY/altoproperty-main`.
- The wrapper runs the AppleScript, then polls up to ~20s for the process and
  prints it on success.

Or call the AppleScript directly:

```bash
osascript ~/.claude/skills/launch-remote-control/start-remote-control.applescript [working-dir]
```

## Verify it worked

The defining signal is a running process with the `--remote-control` flag:

```bash
pgrep -fl 'claude --remote-control'
# e.g. 24658 /opt/homebrew/bin/claude --remote-control
```

If that prints a PID, the session is live. Report the PID back to the user.

## What to tell the user (they're on their phone)

1. The session is live — confirm with the PID from `pgrep`.
2. They can't see the Mac screen, so the pairing happens from the **Claude
   mobile app**: open it and look for / pair with this newly-available session.
3. You (Claude) can confirm the process is alive but **cannot read the TUI's
   pairing URL/code** from outside. If the mobile app doesn't surface the
   session in a minute or two, say so plainly rather than guessing.

## Troubleshooting

- **No process after ~20s** — claude may still be loading. The `delay 8` assumes
  a cold TUI start; on a slow boot bump it. Re-run `launch.sh`.
- **AppleScript blocked** — Terminal needs permission to be controlled by
  AppleScript (Automation prompt the first time). This is NOT Accessibility; if
  macOS prompts, the user (or you, if local) must allow it once.
- **Multiple windows pile up** — each run opens a fresh Terminal window. Old
  `claude` sessions keep running; close stale windows manually if needed.

## Gotchas

- `delay` is in **seconds**. 8s is the tested floor for the TUI to accept input;
  shorter and `/remote-control` may be typed before the prompt is ready.
- Don't name this skill `remote-control` — that collides with the built-in
  `/remote-control` UI command. Hence `launch-remote-control`.
- This launches a brand-new, context-free session. It does NOT hand off the
  current conversation — it's a fresh `claude` the user pairs into.
