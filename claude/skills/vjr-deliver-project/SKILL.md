---
name: vjr-deliver-project
description: Kick off delivery for a signed client — planning, build, and QA — and advance them to "delivering". Use when the user says "deliver <client>", "onboard <signed client>", "start building for <client>", or "kick off the project".
---

# Deliver Project

For a client at stage `signed`, runs project-manager → dev-orchestrator (optional) → qa-engineer
and advances them to `delivering`.

```bash
python3 vjros.py process deliver --client "Acme"            # full
python3 vjros.py process deliver --client "Acme" --no-build # skip dev-orchestrator
```

The client must exist (run quote-to-cash first) and should be at `signed` — advance them if the
deal closed: `python3 vjros.py client advance --client "Acme" --to signed --note "countersigned"`.

## Honesty note
Delivery agents are **experimental** (different CLI signatures / missing deps). The kernel runs
what it can and logs graceful skips — relay them. The stage still advances to `delivering` so the
pipeline reflects reality; offer to harden the dev agents if the user wants automated build/QA.
