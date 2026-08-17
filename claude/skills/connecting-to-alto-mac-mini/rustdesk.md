# RustDesk — password management and self-hosted server (hbbs/hbbr)

Reference for anything RustDesk-related on ALTO's Mac-mini-2. Read this before touching
RustDesk's password, poking at hbbs/hbbr, or debugging a "can't connect" report — several
of these gotchas cost significant time to diagnose the first time around.

## Self-hosted server architecture

This machine runs its own self-hosted rustdesk-server (hbbs/hbbr), not the public
rustdesk.com relay — confirmed via `RustDesk2.toml`'s `custom-rendezvous-server`,
`relay-server`, and `rendezvous_server` all pointing at `100.114.165.87` (the same
tailnet IP as everything else on this machine).

**As of 2026-07-31, `hbbs`/`hbbr` run as native macOS LaunchAgents
(`~/Library/LaunchAgents/com.rustdesk.hbbs.plist` / `.hbbr.plist`), NOT as Docker
containers.** If you ever see them running via `docker ps` again, that's a regression —
see "The Docker registration bug" below for why. Binaries:
`/Users/altoproperty/rustdesk-server-bin/{hbbs,hbbr}` (built from source, `git clone
--branch <version> --depth 1 https://github.com/rustdesk/rustdesk-server.git` + `git
submodule update --init --recursive --depth 1` for the `hbb_common` submodule + `cargo
build --release` — no official macOS binaries are published, only Linux/Windows).
Persistent server identity/data (`id_ed25519` keypair, `db_v2.sqlite3` peer database)
lives in `/Users/altoproperty/rustdesk-server-data/`, unchanged across the Docker→native
migration — the server's `Key:` value and every client's existing config stayed valid.

## The Docker registration bug (why native, not Docker/Colima)

The RustDesk client running on this same Mac-mini could NEVER successfully register its
public key with the self-hosted server when it ran via Docker/Colima — `register_pk of
100.114.165.87:21116 due to key not confirmed` in the client log, repeating forever, and
the server's `peer` table (`SELECT * FROM peer` in `db_v2.sqlite3`) stayed **permanently
empty** no matter what was tried against the container: recreating it, adding missing
port mappings, fixing the image version, `colima restart`, pointing the client at
`127.0.0.1` instead of the tailnet IP — none of it worked, all producing the *identical*
symptom.

The decisive test: pointing the SAME client at RustDesk's public server
(`rs-ny.rustdesk.com`) instead succeeded immediately, and the client's own NAT-type
detection reported `ASYMMETRIC` against the public server vs. **`SYMMETRIC` every single
time against our own container-hosted server** — same machine, same interface, only the
destination changed.

**Root cause:** Colima's VM networking rewrites the outbound source port inconsistently
when host traffic loops back into its own Docker container (self-referential host→VM
routing) — invisible to RustDesk's simple NAT-echo probe, but fatal to the actual
key-confirmation handshake, which needs a stable port across the exchange. **This is
unavoidable for this specific setup** — the Mac-mini's own client MUST register with its
own server for anyone (including a different device elsewhere) to ever find it by
RustDesk ID; this isn't a "local testing only" edge case.

Running the server natively removes the VM networking layer entirely and fixes it —
confirmed via a real `update_pk` log line and a populated `peer` table immediately after
switching, with the registration retry loop stopping for good.

**If registration breaks again**, check in this order before assuming it's the same bug:
1. `launchctl list | grep rustdesk` — both LaunchAgents should show PID + exit status 0.
2. `docker ps` — confirm `hbbs`/`hbbr` are NOT running there (would conflict on the same
   ports and reintroduce the exact bug above).
3. `sqlite3 /Users/altoproperty/rustdesk-server-data/db_v2.sqlite3 "SELECT * FROM peer"` —
   should show a row per registered device; empty again means history repeating.
4. Client log (`~/Library/Logs/RustDesk/RustDesk_rCURRENT.log` on whichever machine is
   failing to register) — look for `register_pk ... due to key not confirmed` looping
   forever vs. a one-time `Latency of ... : Nms` line (success) or a real error.

Port 21114 (an hbbs API endpoint some client telemetry calls hit) still isn't implemented
by this hbbs version — `Connection refused` / empty replies there are cosmetic (WARN-level,
gracefully degraded) and NOT related to the registration bug above; don't chase that port
again as a lead.

## Password management (permanent vs temporary)

Two independent passwords exist:

| Type | How it's set | Privilege needed | Where it lives |
|---|---|---|---|
| Temporary (default) | Click the refresh icon in RustDesk's own GUI window | None | Nowhere persisted — in-memory only, not in any config file or log |
| Permanent | `--password <value>` CLI flag | **sudo** | `RustDesk.toml`'s `password` + `salt` fields (salted hash, NOT `RustDesk2.toml`) |

**Config file map** (`~/Library/Preferences/com.carriez.rustdesk/`):
- `RustDesk.toml` — ID, keypair, and the **permanent password + salt** (Config1). This
  is the file to check/verify against, not `RustDesk2.toml` — checking the wrong file
  first is an easy, already-made mistake (its `password`/`salt` fields simply don't
  exist there, so it looks like nothing was ever set).
- `RustDesk2.toml` — network/relay options only (rendezvous/relay server, direct-access
  port, `trusted_devices`). No password lives here.
- `RustDesk_local.toml` — UI state only (window size, peer sorting).
- `RustDesk_hwcodec.toml` — hardware codec settings, unrelated.

**Setting/rotating the permanent password — the actual working sequence:**
```bash
# 1. Confirm no passwordless sudo (expected to fail):
ssh altoproperty@100.114.165.87 'sudo -n true'   # "passwordless sudo: NO" is normal

# 2. Have the HUMAN run this in a real interactive terminal (Terminal.app/iTerm),
#    NOT through Claude Code's `!` bridge — see gotcha below for why:
ssh altoproperty@100.114.165.87
sudo /Applications/RustDesk.app/Contents/MacOS/RustDesk --password <NEW_PASSWORD>
# (types the real sudo password interactively when prompted)

# 3. Verify against the correct file (mtime should be current, password/salt non-empty):
ssh altoproperty@100.114.165.87 'cat "$HOME/Library/Preferences/com.carriez.rustdesk/RustDesk.toml"'
```
Unprivileged, no sudo → the app itself refuses cleanly with `"Installation and
administrative privileges required!"` (a real, specific message — not a hang, and no
stray process). There is **no separate `--install` flag** (confirmed absent via a
strings search of the binary) — it's the same `--password` command, just needs to run
as root.

Default `verification-method` is unset in `RustDesk2.toml`, meaning **both temporary and
permanent passwords are accepted side by side** — setting a permanent one doesn't break
the existing rotating-password flow.

## The "can't type" bug — macOS Secure Input, not a RustDesk problem

**Confirmed 2026-08-14.** If RustDesk connects fine (you can see the screen, move the
mouse) but keystrokes go nowhere, don't assume it's a permissions or config problem on
RustDesk's side — check whether the Mac-mini's screen is locked first. It almost
certainly is.

**Root cause:** macOS engages Secure Input Mode (`CGSSetSecureEventInput`) whenever a
password field — including the lock screen itself — has focus, and Secure Input blocks
*every* app, not just RustDesk, from injecting synthetic keystrokes system-wide. This is
a deliberate, unbypassable Apple security feature (it's what stops a keylogger-style app
from harvesting/injecting text during password entry). TeamViewer and AnyDesk (both also
installed on this machine — see the TCC query below) would hit the exact same wall.
Only Apple's own built-in Screen Sharing has a private entitlement that can authenticate
through a locked screen; no third-party remote tool gets that exception.

**Diagnose it, don't guess:**

```bash
# Is the screen locked RIGHT NOW?
ssh altoproperty@100.114.165.87 \
  'ioreg -n Root -d1 -a 2>/dev/null | plutil -extract IOConsoleUsers.0.CGSSessionScreenIsLocked raw -'
# "true" = locked, confirms Secure Input is blocking every app's synthetic input

# Correlate a past failed session against the lock screen — get the connection window
# from RustDesk's own log first (~/Library/Logs/RustDesk/RustDesk_rCURRENT.log, look for
# "Connection opened from <ip>:<port>."), then check the unified log for that window:
log show --start "<session start>" --end "<session end>" \
  --predicate 'eventMessage CONTAINS[c] "_setSecureInput"' --info
# a loginwindow "CGSSetSecureEventInput: 1" line landing inside the connection window
# = the screen was locked for that whole session
```

**Don't mistake this for a missing TCC permission — check the SYSTEM db, not the user
one.** A prior session concluded RustDesk's Accessibility/Screen Recording grants were
missing by querying `~/Library/Application Support/com.apple.TCC/TCC.db` (the user-level
db) — that query genuinely returns zero rows for RustDesk, but it's the wrong database.
Grants for this class of app (Accessibility, Screen Recording, Input Monitoring) live in
the **system** TCC.db instead, and no sudo is needed to read it:

```bash
sqlite3 "/Library/Application Support/com.apple.TCC/TCC.db" \
  "SELECT service, client, auth_value FROM access WHERE client LIKE '%rustdesk%';"
# kTCCServiceScreenCapture|com.carriez.rustdesk|2   <- auth_value 2 = Allowed
# kTCCServiceAccessibility|com.carriez.rustdesk|2   <- auth_value 2 = Allowed
```
Confirmed 2026-08-14: both are properly granted and current (granted after the app's
last binary update, so no stale-grant-vs-updated-signature mismatch either) — the
permissions were never the problem.

**The fix — two parts:**

1. **One-time unlock, needs a human.** RustDesk can't do this itself — that's the whole
   bug. Either sit at the machine physically, or try Apple's own Screen Sharing first
   (`System Settings → General → Sharing → Screen Sharing` — untested live as of
   2026-08-14, but it may authenticate through the lock screen where RustDesk can't).

2. **Stop it recurring** — run over the existing SSH session, no sudo, no GUI needed:
   ```bash
   ssh altoproperty@100.114.165.87
   defaults -currentHost write com.apple.screensaver askForPassword -int 0
   ```
   This machine's `displaysleep` is 10 minutes (`pmset -g`) and had no override for
   "require password after sleep," so it was using macOS's default (lock immediately) —
   which is why an unattended box like this one ends up here regularly. Middle-ground
   alternative if disabling the password requirement entirely is too much: keep it on
   but push the delay out (`defaults -currentHost write com.apple.screensaver
   askForPasswordDelay -int 14400` for a 4-hour grace window) instead of `askForPassword
   -int 0`. Neither key exists under the ByHost domain until you set it — that's expected,
   it just means macOS is on its unmodified default. GUI-equivalent path for whoever has
   hands-on access: System Settings → Lock Screen → "Require password after screen saver
   begins or display is turned off."

## Gotchas

**Never pipe the sudo password through Claude Code's `!` bridge or a non-interactive SSH
command.** `ssh -t host 'sudo ...'` still fails with *"a terminal is required to read
the password"* because the `!` mechanism's stdin isn't a real TTY, and the workaround
(`echo 'password' | sudo -S ...`) would put the operator's actual macOS account password
in the chat transcript — meaningfully more sensitive than the scoped API tokens normally
handled this way. Always have the human open their own terminal, SSH in interactively,
and type the sudo password there.

**Invoking the RustDesk GUI binary with ANY CLI flag spawns a full duplicate GUI process
on this macOS build**, even for something as simple as `--help` (which is silently
ignored — no help text, just a normal app launch). Confirmed via `ps aux | grep rustdesk`
showing a second PID appear. `--password` is different: it's a genuinely implemented
action that exits cleanly with a specific message instead of falling through to the GUI.
After any flag invocation, always check `ps aux | grep -i rustdesk` and kill only the
newly-spawned PID — leave the original running instance (the one with an old start-time
in `ps`) untouched.

**AppleScript/System Events UI automation hangs indefinitely, unrecoverable.**
`osascript -e 'tell application "System Events" to tell process "RustDesk" ...'` blocks
on a silent Accessibility permission dialog — same class of issue as the `imsg` FDA
gotcha in the main skill, except this machine has **no display attached at all**
(`screencapture -x` fails with `"could not create image from display"`, not a permission
error — there's nothing to show the dialog on). Unlike `imsg`, there's no "RustDesk/
TeamViewer in and click Allow" escape hatch here, because RustDesk *is* the remote-access
tool in question. Detect the hang via `ps aux | grep osascript` (near-zero CPU time since
start = genuinely blocked, not slow) and kill it — don't wait it out, it will never
resolve on its own.

**Don't hand-edit the `password`/`salt` fields, and don't try the IPC socket.** The
permanent password is a proper salted hash (confirmed via strings in
`Frameworks/liblibrustdesk.dylib`: `"Permanent password hash storage requires a
non-empty salt"`, `"refusing update"` on malformed data) — writing it by hand risks a
silently-corrupt value that only fails when someone actually tries to connect. There's
also a live Unix socket (`/tmp/RustDesk-501/ipc`) the running GUI listens on, likely the
real internal CLI/GUI protocol, but it isn't documented anywhere accessible — don't
hand-roll messages to it against a live, in-use instance. The only safe way to set the
password is the app's own `--password` flag with real sudo, per the sequence above.

## Common mistakes

| Mistake | Fix |
|---|---|
| Checking `RustDesk2.toml` for the permanent password | It's in `RustDesk.toml` (`password`/`salt` fields) — `RustDesk2.toml` only has network/relay options |
| Running `RustDesk --help` (or any flag) over SSH to "check" it | Spawns a full duplicate GUI process on this build — always `ps aux \| grep rustdesk` after and kill only the new PID |
| Piping a sudo password through `!` or `ssh -t host 'sudo ...'` | No real TTY there — password prompt fails, and piping it via `echo pw \| sudo -S` exposes the real macOS account password in the transcript. Have the human SSH in interactively and type it themselves |
| Waiting out a hung `osascript`/System Events call against RustDesk | It's blocked on an undismissable Accessibility dialog (no display attached) — it will never resolve; kill the PID instead |
| Hand-editing RustDesk's `password`/`salt` TOML fields | They're a salted hash the app computes internally — only ever set via `--password` (with sudo), never by hand |
| Running `hbbs`/`hbbr` via Docker/Colima on this machine | Causes permanent registration failure (`key not confirmed` forever, empty `peer` table) — Colima's VM networking breaks the key-confirmation handshake for this machine's own self-referential client↔server traffic. Must run as native LaunchAgents instead |
| Chasing port 21114 as a registration-bug lead | It's a separate, cosmetic gap (an hbbs API endpoint this version doesn't implement) — real registration failures show as `register_pk ... due to key not confirmed` looping forever, not connection-refused on 21114 |
| Treating a "can't type over RustDesk" report as a permissions/config problem | Check `CGSSessionScreenIsLocked` first — it's almost always the lock screen's Secure Input Mode blocking every app's synthetic keystrokes, not something wrong with RustDesk specifically (confirmed 2026-08-14) |
| Querying the user TCC.db (`~/Library/Application Support/com.apple.TCC/TCC.db`) for RustDesk's Accessibility/Screen Recording grants | Wrong database — those grants live in the **system** TCC.db (`/Library/Application Support/com.apple.TCC/TCC.db`, world-readable, no sudo needed); the user db genuinely returns zero rows for this class of app and will look like a missing grant that isn't actually missing |
