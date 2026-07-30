---
name: ags-os
description: AGS-Dev OS meta skill — shows full system overview including all Render services, Docker stacks, repos, and team. Invoke when user asks "what can the OS do", "show ags status", "ags help", "list all services", "show everything", or mentions the AGS-Dev OS.
---

# AGS-Dev OS

You are operating inside the AGS-Dev Claude OS — a unified workspace for the Alliance Global Solutions engineering team.

## What to do

1. Run `python3 /mnt/d/ags-dev-os/agsdev.py status` to get the live system status
2. Present the output clearly, organized by section
3. List the available CLI commands and skills

## Available commands

```bash
python3 agsdev.py status           # Render + Docker health
python3 agsdev.py deploy <service> # Trigger Render deploy
python3 agsdev.py logs <service>   # Fetch recent logs
python3 agsdev.py up [stack]       # Start Docker stack(s)
python3 agsdev.py down [stack]     # Stop Docker stack(s)
python3 agsdev.py monitor          # All dashboard URLs
python3 agsdev.py services         # All Render services
python3 agsdev.py repos            # All repos
```

## Available skills

- `/ags-status` — Render + Docker health dashboard
- `/ags-deploy` — Deploy a service to Render
- `/ags-dev` — Start/stop local dev environment
- `/ags-monitor` — All monitoring dashboard URLs

## Context

The OS root is at `/mnt/d/ags-dev-os/`. All 20 repos are accessible via `apps/`, all 4 Docker stacks via `stacks/`. Full context is in `CLAUDE.md` at the OS root.
