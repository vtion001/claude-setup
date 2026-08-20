---
name: recording-changelog
description: Use when a coding session merged one or more PRs and the repo's changelog needs updating, when a repo has no changelog yet and one should be backfilled, or before running /init on a repo whose CLAUDE.md has grown long — keeps a running docs/CHANGELOG.md so CLAUDE.md doesn't have to carry incident/feature narratives.
---

# Recording Changelog

## Overview

A repo's real change history already lives in git/GitHub — every merged PR has a
title, date, and number. This skill turns that into one skimmable file,
`docs/CHANGELOG.md`, so session summaries stop landing directly in CLAUDE.md
(where they bloat every future `/init` and every session's context window).

**Core principle:** never hand-type an entry from memory. Every line comes from
`gh pr list --state merged` — if you can't query it, say so instead of guessing.

## When to use

- A PR (or several) was just merged in this session → append entries before ending
  the session.
- A repo has no `docs/CHANGELOG.md` (or root `CHANGELOG.md`) yet → backfill one.
- CLAUDE.md has narrative sections like "Shipped 2026-07-26 via PR #117... here's
  the whole incident" → that content belongs here, not in CLAUDE.md.
- Before `/init` or a CLAUDE.md-improver pass on a repo whose CLAUDE.md has grown
  past a few hundred lines.

## Workflow

### 1. Find or create the file

Prefer `docs/CHANGELOG.md` if the repo has a `docs/` directory; otherwise use a
root `CHANGELOG.md`. Don't invent a third location — match the repo's existing
convention if one is visible.

```bash
gh repo view --json nameWithOwner -q .nameWithOwner   # confirm you're in a GitHub-backed repo
```

If neither `gh` nor a GitHub remote is available, tell the user directly — do not
fabricate history from commit messages alone (merge commits lack the PR
description/date fidelity `gh pr list` gives you for free).

### 2. New file → backfill

Pull recent merged PRs (last ~30, or ask the user how far back if the repo is old):

```bash
gh pr list --state merged --limit 30 --json number,title,mergedAt,url \
  --jq '.[] | "\(.mergedAt[:10]) | #\(.number) | \(.title)"' | sort -r
```

Group by date, one bullet per PR, newest date first:

```markdown
# Changelog

Running record of what shipped on this repo, one line per merged PR. Newest first.
Entries are generated from `gh pr list --state merged` — never hand-written from
memory. See the `recording-changelog` skill for how this file gets updated.

## 2026-07-27
- fix(ivr): hardcode webhook origin ([#120](https://github.com/OWNER/REPO/pull/120))
- feat(ivr): two-level Sales / Property Management menu ([#121](https://github.com/OWNER/REPO/pull/121))
```

### 3. Existing file → append only what's new

Find the highest PR number already recorded (`grep -oE '#[0-9]+' docs/CHANGELOG.md | ... | sort -n | tail -1`),
then pull only PRs merged after it:

```bash
gh pr list --state merged --limit 50 --json number,title,mergedAt,url \
  --jq --arg last "$LAST_PR_NUMBER" '.[] | select(.number > ($last|tonumber))'
```

Insert new date-grouped entries at the **top** of the file, under the header,
above existing content — reverse-chronological, don't reorder what's already
there. If nothing merged since the last entry, say so and don't touch the file.

### 4. Flag CLAUDE.md bloat (don't auto-edit)

Grep the repo's CLAUDE.md / AGENTS.md for narrative give-aways — phrases like
"Shipped `<date>` via PR #", multi-paragraph incident write-ups, or a "Gotcha:"
block that duplicates something now in the changelog. Propose trimming it to a
short pointer (architecture + the one durable warning, if any) plus a link to the
changelog entry — but only apply the edit after the user agrees, since CLAUDE.md
edits are more sensitive than an append-only changelog.

### 5. Report back

State what was added (or that nothing was new) and the file path. Don't restate
every bullet back to the user in prose — they can read the file.

## Making this durable across sessions

Skills don't self-trigger. The durable part is a one-line pointer in the repo's
own CLAUDE.md (add this once per repo, e.g. under wherever `docs/` is described):

```markdown
`docs/CHANGELOG.md` is the running record of what shipped, one line per merged
PR — keep incident/feature narratives there, not in this file. Update it via the
`recording-changelog` skill.
```

Because CLAUDE.md loads every session, this reminder travels with the repo and
prompts a fresh session to invoke the skill after it merges something — without
needing a hook or CI job.

## Common mistakes

| Mistake | Fix |
|---|---|
| Typing an entry from memory of the conversation | Pull it from `gh pr list` — memory drifts, PR metadata doesn't |
| Re-summarizing the whole PR body | One line: type(scope): what + PR link. The PR itself has the detail |
| Comparing by date to find "new" entries | Compare by PR number — dates can collide/reorder across timezones, numbers are monotonic |
| Auto-trimming CLAUDE.md without asking | Propose the trim, apply only after the user agrees |
| Backfilling the entire repo history on first run | Default to a recent window (~30 PRs); ask before going further back |
| Creating both `docs/CHANGELOG.md` and root `CHANGELOG.md` in the same repo | Pick one per repo, match whatever convention already exists |
