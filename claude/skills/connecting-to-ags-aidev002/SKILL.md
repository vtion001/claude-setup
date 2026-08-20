---
name: connecting-to-ags-aidev002
description: Use when the user asks to connect to, SSH into, fix, or recover access to "ags-aidev002" (their Linux dev machine, physically at work) — including phrases like "connect to my work computer", "SSH into ags-aidev002", "fix aidev002 access", "is my work Linux box reachable", or continuing the 2026-07-27 SSH-access-recovery investigation.
---

# Connecting to ags-aidev002 (Linux dev machine, physical, at work)

## Status as of 2026-07-27 — SSH access is DOWN, root cause identified, fix needs physical access

This machine is **unreachable via any remote channel** as of the last check. Full
investigation was done (see "Evidence gathered" below) so the next session shouldn't
have to re-derive any of this — just execute the fix checklist once physically at the
machine.

**Do not re-run the full diagnostic sweep from scratch** — jump straight to "Fix
checklist" below once you're at the console. Only re-run "Quick health check" first to
confirm the state hasn't changed (e.g. someone else already fixed it, or it broke
differently).

## Machine facts

| Fact | Value |
|---|---|
| Hostname | `ags-aidev002` |
| Tailscale IP | `100.110.210.72` |
| Tailscale MagicDNS | `ags-aidev002.tail7ceefe.ts.net` |
| OS | Linux |
| Tailnet owner | `vtion001` |
| Machine type | **Physical/local machine at work** (confirmed by user — not a cloud VM, no provider console available) |
| Sibling machine | `ags-aidev001` (Windows, `100.69.210.13`) — separate machine, separate problem, not covered here |

## Quick health check (run this first, from any machine on the tailnet)

```bash
tailscale ping ags-aidev002              # confirms the box is powered on and tailscaled is alive
nc -zv -w 5 100.110.210.72 22            # SSH — expect "Connection refused" if still broken
nc -zv -w 5 100.110.210.72 443           # tailscale serve proxy — expect it to open (TLS), separate issue from SSH
```

If `tailscale ping` now fails entirely (not just SSH), the situation has changed —
the whole box may be off/disconnected, which is a different problem than what's
documented here (this doc assumes Tailscale itself is alive and only specific
services are down).

## Root cause (confirmed 2026-07-27, at the network layer — not guessed)

Tailscale mesh connectivity to this box is healthy (ping succeeds, fresh handshake,
`tailscaled` is running fine on it). The problem is scoped to two specific services on
top of that:

1. **SSH (port 22): TCP-level "Connection refused"** — this happens *before* any
   username/auth is evaluated, so it isn't a wrong-username or wrong-key problem
   (unlike the `altoproperty` vs `joshua` gotcha on alto-mac-mini — see
   [[connecting-to-alto-mac-mini]] — that pattern doesn't apply here). It means
   either `sshd` is not running/not installed, or a host firewall rule explicitly
   rejects port 22.
2. **Tailscale SSH is NOT enabled** on this node — if it were, `tailscale ssh
   ags-aidev002` would succeed at the TCP layer even with sshd down, since
   `tailscaled` itself intercepts port 22 when that feature is on. It doesn't, so
   it's off.
3. **`tailscale serve` on port 443 is configured but its backend is dead** — the TLS
   handshake completes fine (valid Let's Encrypt cert for
   `ags-aidev002.tail7ceefe.ts.net`), but every HTTP path returns `502` with an empty
   body. This means some local app (probably analogous to the Mission Control
   `tailscale serve --bg --https=443 http://localhost:PORT` pattern documented in
   `mission-control-boilerplate/docs/mc-access.md`) crashed or was never restarted.
   This is a **separate** issue from SSH — fixing one doesn't fix the other.

Given Tailscale itself is alive, the machine did NOT lose power/network — this looks
like specific services not coming back after some event (reboot, crash, manual stop),
not a total outage.

## Evidence gathered (why other access paths were ruled out — 2026-07-27)

Full investigation before concluding physical access was required:

- **Cloud provider console**: ruled out — user confirmed this is a physical/local
  machine, not a VM. (AWS: no credentials configured. GCP `openclaw-communications`
  and Azure `Joshua-Openclaw`: both had CLI auth configured on the operator's Mac but
  tokens had expired, requiring interactive re-login — moot once "physical machine"
  was confirmed.)
- **RustDesk**: the operator's Mac (`macbook-pro`, Tailscale IP `100.113.91.39`) runs
  its own **self-hosted RustDesk rendezvous+relay server** in Docker
  (`rustdesk-hbbs` + `rustdesk-hbbr`, `100.113.91.39:21116`, healthy/up for weeks).
  Checked `~/Library/Preferences/com.carriez.RustDesk/peers/` (empty) and the hbbs
  container's full log history (~3 weeks) — **zero evidence `ags-aidev002` has ever
  registered with this self-hosted server.** The only registered peer is the iPad
  (matches the existing `reference_rustdesk_btnwatch` memory).
  The user's **phone** does have a saved RustDesk connection for this machine — which
  means its client is likely pointed at the **public** RustDesk relay instead, not
  this self-hosted one (so the empty peers/log finding above doesn't contradict it).
  That connection is **password-gated** and no permanent password was found anywhere
  searchable on this Mac (RustDesk configs, `~/.ssh`, provisioning/bootstrap scripts,
  every doc repo-wide). **Still unresolved as of 2026-07-27: check a password manager
  (1Password/Bitwarden/etc.) for a saved RustDesk password for this machine before
  assuming none exists.**
- **Remote power-cycle**: no smart-plug/PDU integration found on this Mac that could
  force a reboot of this box.
- **No dedicated skill/doc existed** for `ags-aidev001`/`ags-aidev002` before this one
  — the only prior art was the `mission-control-boilerplate/docs/mc-access.md`
  Tailscale snapshot (just an IP/OS table) and the `bob-ags` docs (which reference
  `ags-aidev001`'s `tailscale serve` URL for QA, not `ags-aidev002`, and not SSH/
  RustDesk access details).

## Fix checklist — run once physically at the machine

```bash
# 1. Bring SSH back
sudo systemctl status ssh              # or sshd — check which unit name this distro uses
sudo systemctl enable --now ssh        # if it's stopped/disabled
# If missing entirely:
sudo apt install openssh-server        # Debian/Ubuntu — adjust for actual distro

# 2. Check firewall isn't explicitly blocking port 22
sudo ufw status
sudo iptables -L -n | grep ':22\b'

# 3. Also enable Tailscale SSH — gives a second independent path so this doesn't
#    strand us again (matches how alto-mac-mini is set up)
sudo tailscale up --ssh

# 4. Find and fix the dead `tailscale serve` backend on 443
sudo tailscale serve status            # shows what URL/port it's supposed to proxy to
# then check/restart whatever local process that points at (systemd service, docker
# container, tmux/screen session, etc. — investigate once you see the target)

# 5. Once SSH works again from the operator's Mac:
ssh <user>@100.110.210.72              # figure out the actual username once logged in locally — don't assume "root" or a name-based guess; alto-mac-mini's own gotcha was a non-obvious username, this box may have its own
```

## After SSH is restored — set up Claude Code remote-control

Once you can SSH in again, the original ask was to run Claude Code on this machine
itself and drive it remotely via `/remote-control` (see the `launch-remote-control`
skill for the mechanics — it opens a Terminal, launches `claude`, and types
`/remote-control` for you). That only needs to be (re-)done after SSH is confirmed
working; no point attempting it before then.

## Common mistakes

| Mistake | Fix |
|---|---|
| Re-running the full remote diagnostic sweep (Tailscale, cloud CLIs, RustDesk logs) again | Already done 2026-07-27, see "Evidence gathered" — just run "Quick health check" to confirm state, then go straight to the fix checklist |
| Assuming a `Connection refused` on port 22 is a wrong-username/wrong-key problem | It's a TCP-level rejection, before auth is even reached — means sshd isn't listening or a firewall is rejecting it, not a credentials issue |
| Trying `tailscale ssh` again expecting a different result | Confirmed Tailscale SSH isn't enabled on this node — it'll keep refusing until `tailscale up --ssh` is run locally on the box |
| Assuming the dead port-443 backend and dead SSH are the same root cause | They're two independent broken services; fixing SSH doesn't fix the 502, and vice versa |
| Giving up on RustDesk because the self-hosted server shows no record of this box | The phone's saved connection is probably on the *public* RustDesk relay, not the self-hosted one — check a password manager for the permanent password before ruling RustDesk out entirely |
