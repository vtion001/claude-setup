---
name: cli-tools
description: >
  Router for general-purpose CLI utilities — Google Workspace (gog), starting a
  remote-controllable Claude session, web research/lookup, the agshub work tracker,
  Linear project updates, Todoist logging, and image analysis. Use on "/cli-tools",
  "use gog", "start remote control", "research X online", "log a task", or any
  general tool-invocation request where you're not sure which specific specialist
  skill applies.
---

# CLI Tools — Router

Doesn't do the work itself — figures out which specialist skill the request actually
needs and invokes it via the `Skill` tool.

## Routing table

| If the request is about... | Invoke |
|---|---|
| Gmail, Calendar, Drive, Sheets, Docs, Contacts via the `gog` CLI | `gog` |
| Starting a remote-controllable `claude` session when away from the computer | `launch-remote-control` |
| Researching/looking something up across the web or a named platform | `agent-reach` |
| Creating/reading/updating/deleting anything in the agshub work tracker | `agshub-crud` |
| Posting a Linear project/status update, checking milestones | `linear-project-update` |
| Logging a fully-detailed task to the user's Todoist Inbox | `todoist-log` |
| Analyzing an image | `image-analysis` |

## Fallback

If nothing above matches clearly, list the candidates above and ask which one fits
rather than guessing.
