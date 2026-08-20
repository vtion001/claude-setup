---
name: todoist-log
description: Log a fully-detailed task straight to the user's Todoist Inbox via /todoist-log [description]. With no argument, summarizes the current conversation into a task; with an argument, builds the task around that text. Infers priority, due date, labels, and a detailed description from context — no follow-up questions.
---

# Todoist Log

Create one task in the user's Todoist Inbox, filled out as completely as the
context allows. This is a capture tool, not a planner — one task per
invocation, always landing in Inbox.

## Input

`/todoist-log` (no argument) or `/todoist-log <description>`.

- **No argument**: summarize whatever was just being discussed into a task —
  what needs to happen, why, and what's blocking it. Write the `content` as
  a short actionable title and put the narrative detail in `description`.
- **With argument**: the argument text anchors `content`; still enrich
  `description`/priority/due/labels from surrounding conversation context.

## Fill every field you can justify — don't ask the user

Decide values yourself from context and create the task in one shot. Only
leave a field blank if nothing in context justifies a value (e.g. don't
invent a due date for a task with no time pressure).

- **`content`**: short, action-oriented, specific enough to act on cold days
  later (not "Twilio thing" — "Check ALTO IVR (+61 7 4803 4068) live webhook
  config once Josh provides a working Twilio credential").
- **`description`**: the detail a future read needs — what's already been
  tried/ruled out, what's blocking it, what the concrete next step is, and
  any relevant IDs/links/dates. This is where most of the "comprehensive and
  detailed" value lives; don't leave it thin.
- **`priority`** — **the API scale is inverted from what you see in the
  Todoist app**: API `4` = the app's P1 (urgent/red) ... API `1` = the app's
  P4 (no priority, the default). Map by urgency-in-context, then translate:
  genuinely urgent/blocking → `4`; normal actionable → `2`-`3`; low-stakes/
  someday → `1` or omit.
- **`due_string`** (preferred over `due_date`) — natural language, e.g.
  `"tomorrow morning"`, `"Aug 10"`. Use this for "when to work on/follow up
  on it." Only set a date if context implies real timing (e.g. "wait until
  tomorrow morning" → due tomorrow morning); don't fabricate urgency.
- **`deadline_date`** is a *different concept* from due — it's a hard
  external cutoff (e.g. a contract date, someone else's deadline). Only set
  it when context describes an actual hard cutoff, not just "when I'll get
  to it." Most tasks should NOT have a deadline_date.
- **`labels`** — free-form, comma-separated; invent short lowercase-hyphen
  labels that fit (project name, category like `follow-up`/`blocked`/
  `client`). No fixed taxonomy to respect — the account currently has zero
  labels, so early choices set the pattern; keep them reusable rather than
  one-off.
- **`duration`/`duration_unit`** — only set when context implies a concrete
  time-box (e.g. "quick 15 min call"); omit otherwise.
- **`section` (via `--section-name`)** — always set one. This drives board-
  view segmentation, so pick the friendly project/context name the task
  belongs to (e.g. `"ALTO Property"`, `"VJR-OS"`, `"Personal"`,
  `"Joson Furniture"`) — human-readable names, not repo/folder slugs. The
  script resolves an existing section by exact case-insensitive name match
  within the target project, or creates it if none matches — so reuse the
  same name consistently rather than near-duplicates ("Alto" vs
  "ALTO Property"). If nothing in context suggests a specific project, use
  `"Personal"` rather than leaving it unsectioned.

## Running it

```bash
python3 ~/.claude/skills/todoist-log/create_task.py \
  --content "<content>" \
  --description "<description>" \
  --priority <1-4> \
  --labels "<label1,label2>" \
  --section-name "<friendly project name>" \
  --due-string "<natural language>"
  # add --deadline-date / --duration --duration-unit only when justified
```

The script resolves the Inbox project ID live via the API each run (never
hardcoded), reads the token from `~/.config/todoist/.env`, and prints the
created task's id/url/priority/due/labels back as JSON.

## After creating

Show the user the printed JSON (or at minimum the content, description,
priority, due, and the `https://app.todoist.com/app/task/<id>` link) so they
can see exactly what was captured without opening Todoist.

## Credential

Token lives in `~/.config/todoist/.env` as `TODOIST_API_TOKEN=...` — local
file, not committed anywhere (`~/.claude/skills/` isn't a git repo).
