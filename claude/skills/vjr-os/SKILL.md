---
name: vjr-os
description: Entry point and dispatcher for the VJR Digital Solutions operating system. Use when the user wants to run their business — manage clients, generate proposals/contracts/invoices, find leads, deliver projects, run marketing — or asks "what can the OS do", "run vjros", or mentions the business OS. Routes to the right vjros command or sibling skill.
---

# VJR Digital Solutions OS

`vjros` is the kernel that runs Vincent's service business as a client-lifecycle state machine:
`lead → qualified → proposed → signed → delivering → invoiced → closed`. Each domain is a
*process* that advances clients.

## Repo location
The OS lives at `~/Desktop/Repository/VJR-Digital-Solutions` (WSL: `/mnt/c/Users/VJ_Rodriguguez/Desktop/Repository/VJR-Digital-Solutions`). Always run commands from that directory:

```bash
cd /mnt/c/Users/VJ_Rodriguguez/Desktop/Repository/VJR-Digital-Solutions && python3 vjros.py <command>
```

## When to use which command / sibling skill
- "What's the state of the business / show my pipeline / status" → `vjros status` (skill: **vjr-status**)
- "Quote / proposal / contract / invoice for <client>" → **vjr-quote-to-cash**
- "Find leads / prospects in <niche>" → **vjr-acquire-leads**
- "Deliver / build / onboard <signed client>" → **vjr-deliver-project**
- "Marketing campaign / content / reporting" → **vjr-marketing**
- "What agents/processes exist" → `vjros agents`
- Manage a client record directly → `vjros client new|show|advance --client "..."`

## Rules
1. Always `cd` into the repo first.
2. Discover capabilities with `vjros agents` if unsure — never invent agent or process names.
3. After a process runs, report the new stage and where artifacts landed (`clients/<slug>/`).
4. `ready` agents are verified; `exp`/`spec` agents may degrade gracefully — relay any skip messages honestly.
