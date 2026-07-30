---
name: hardening-self-hosted-uptime
description: Use when a self-hosted service on Windows Desktop + WSL2 + Docker Desktop needs to survive reboots, Windows Updates, or crashes unattended, or when adding/changing a Tailscale Funnel and other tunnels must not be disrupted.
---

# Hardening Self-Hosted Uptime

## Overview
Docker Desktop, WSL2 distros, and Tailscale Funnel do not restart themselves after a Windows reboot or crash. This skill closes that gap with 5 additive layers, plus a hard rule for touching Tailscale Funnel safely when other services already use it.

## When to Use
- "the service goes down after a reboot / Windows Update"
- "nobody's around to click things after a restart"
- "add/expose a new project on Tailscale Funnel" **and other funnel entries already exist**
- NOT for services on a dedicated Linux host with real systemd — this is specifically the Windows+WSL2+Docker Desktop combo.

## The 5 Layers

| Layer | Purpose | Mechanism |
|---|---|---|
| 1. Self-healing watchdog | Re-applies funnel + `docker compose up -d` if either drifts | cron `@reboot` + `* * * * *`, flock-guarded, idempotent health checks |
| 2. Power/reboot hygiene | Stop sleep/hibernate/Fast-Startup from stranding the stack | `powercfg /hibernate off`, `standby-timeout-dc 0`, `NoAutoRebootWithLoggedOnUsers=1` |
| 3. Windows auto-login | A session must exist for Docker Desktop (GUI app) to run | Sysinternals `Autologon64.exe` — LSA-encrypted; never the plaintext `DefaultPassword` registry method |
| 4. Docker Desktop autostart + keeper | Engine starts without a click; relaunches if it crashes | `AutoStart:true` in `%APPDATA%\Docker\settings-store.json`; scheduled task at logon + every 5 min that relaunches `Docker Desktop.exe` if not running |
| 5. SYSTEM boot task for the WSL distro | WSL doesn't auto-start; systemd (PID1) needs the distro booted once | SYSTEM scheduled task, `AtStartup` trigger + 30s delay, `wsl.exe -d <distro> -u root -e /bin/true` |

Containers need `restart: always` / `restart_policy: any` already set in compose — the layers above just get the *engine* running again so those policies can kick in.

## Guardrail: Tailscale Funnel changes are additive-only

Tailscale Funnel allows exactly **3 ports per node: 443, 8443, 10000** — no more. On a machine already serving other projects, a careless add can silently collide with or wipe an existing one.

**Before any Funnel change:**
1. Run `tailscale funnel status --json` and enumerate **every** existing `Web`/`TCP` entry — all of them, not just the one you're about to touch.
2. For each entry, verify whether its backend is actually alive (`curl` the proxy target, `ss -tlnp`, `docker ps`) and present the full inventory as a table to the user, including any stale/orphaned ones you find.
3. Add the new service only on a port from {443, 8443, 10000} that step 1 showed is free.
4. **If all 3 are taken:** stop and ask the user which (if any) to reclaim — by name, with its owner project — before touching anything. Do not free one up unprompted just because a deadline is close.

**Never:**
- `tailscale funnel reset` or `tailscale serve reset` — clears every entry on the node, not just yours.
- Turning an existing entry `off` as a "I'll re-add it after the demo" two-step workaround — a crash or interruption between the two steps leaves someone else's service down with no one watching.
- Assuming a port is free because it "sounds unused" — always derive it from the actual `status --json` output taken in this session, not memory of what should be running.

## Known Gotchas
- SYSTEM-owned scheduled tasks are invisible to non-elevated `Get-ScheduledTask`/`schtasks` — always verify from an elevated prompt.
- `-RepetitionDuration ([TimeSpan]::MaxValue)` fails schtasks XML validation; use `(New-TimeSpan -Days 3650)`.
- Autologon writes `AutoLogonSID` to the registry just from being *opened* (UI pre-fill) — that is not proof it's enabled. Confirm via `reg query ... AutoAdminLogon` showing `1`, plus `DefaultUserName`/`DefaultDomainName` populated.
- `wsl --shutdown` and a full Windows reboot both kill any process running inside that same WSL distro — including an AI agent's own shell, if that's where it's executing. Hand that verification step to the human; don't run it from inside the environment under test.

## Verification Checklist
1. Run the watchdog script manually — confirm its log updates and the public URL curls 200.
2. Dry run (human-run, not agent-run): `wsl --shutdown` → wait → trigger the SYSTEM boot task → within ~90s confirm the distro is `Running`, `tailscaled` is active, and the URL is back.
3. Full reboot test (human walks away, zero clicks) → URL back within ~5 min.
