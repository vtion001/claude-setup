---
name: linear-project-update
description: Use when asked to update a Linear project — post a project/status update to the Activity tab, check milestones for pending tasks, and/or refresh the project overview (summary + description). Covers Linear MCP project writes and their gotchas.
---

# Linear Project Update

## Overview
Post a project update to the **Activity tab**, audit **milestones + open issues** for pending work, and refresh the **overview** (summary + description) — using the Linear MCP tools (`mcp__*_Linear__*`). This skill exists mainly to encode the non-obvious gotchas that otherwise cause failed/duplicated writes.

## Workflow
0. **Get the LOCAL date first.** Run `date +'%A, %B %-d, %Y'` (add `%H:%M %Z` if you need the time) and use *that* for every human-readable date you write into the update/summary. Do **not** use Linear's `createdAt`/`updatedAt` (those are **UTC** and can be a day off), and do **not** reuse a date from earlier in the conversation — the clock may have rolled over mid-session. Re-run `date` each time you post.
1. **Resolve the project.** `get_project` with `includeMilestones: true`. Note the project `id`, current `summary`, `description`, `lead`, and milestone progress.
2. **Find pending tasks.** `list_issues` with `project: <id>`. The result is often huge (>token limit) and gets saved to a file — read it with `python3`/jq, not Read. Filter on the **`status`** string field (NOT `state`, which is null), excluding `Done`/`Canceled`. Report the open ones (identifier from the `url` slug, title, status, priority). Cross-check against the repo's CLAUDE.md / git log — issues are often *implemented but not marked Done*; surface these, don't assume.
3. **Post the Activity-tab update.** `save_comment` with **`projectId`** (a top-level project comment IS the Activity-tab update). Markdown body, literal newlines.
4. **Refresh the overview.** `save_project` with `id` + new `summary` and/or `description`. Keep existing description content; add/update sections rather than replacing wholesale (re-send the full description — `save_project` overwrites it).

## Critical gotchas
- **Dates must be LOCAL, not UTC.** The user is in a non-UTC timezone (UTC+8). Linear's `createdAt`/`updatedAt` are UTC and can read a day behind the user's local date — never copy a date from them into prose. Always shell out to `date` (step 0) for any date you write, and re-derive it per post.
- **`summary` is capped at 255 chars; `description` is uncapped.** The API error `"description must be shorter than or equal to 255 characters"` is **mislabeled** — it refers to the **summary** field, not the long body. If you hit it, shorten `summary`. (em/en dashes cost extra bytes.)
- **Activity tab = `save_comment` + `projectId`.** There is no separate "project update" tool; the project-scoped top-level comment is the Activity update. (Replies need `parentId`.)
- **Issue state lives in `status` (string) + `statusType`, not `state`** (`state` is null in `list_issues` output). Group/filter by `status`.
- **`list_issues` output overflows context.** It's written to a tool-results file; query it with `python3 -c "import json; ..."` (the file's single line is too long for Read's chunking).
- **`save_project` replaces `description` entirely** — fetch current, edit, re-send the whole thing.
- **Milestone `progress` can be a stale `0%`** even when the description says COMPLETE — trust the description/issues over the number; flag the discrepancy.

## Quick reference
| Goal | Tool | Key arg |
|------|------|---------|
| Read project + milestones | `get_project` | `includeMilestones: true` |
| List milestones | `list_milestones` | `project` |
| Find pending issues | `list_issues` | `project`; filter `status` ≠ Done/Canceled |
| Activity-tab update | `save_comment` | `projectId` |
| Overview edit | `save_project` | `id` + `summary`(≤255) / `description` |

## Common mistakes
- Putting the long body in `summary` → 255 error. Long content goes in `description`.
- Filtering issues by `state` (always null) → "no pending tasks" false negative. Use `status`.
- Re-`Read`ing the giant `list_issues` file → truncation loops. Use `python3`.
- Marking issues Done without confirming — closing is a batch external write; surface candidates and let the user confirm.
