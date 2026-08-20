---
name: dev-process
description: >
  Router for the software delivery process — brainstorming/design, planning, TDD,
  debugging, parallel/subagent dispatch, git worktrees, code review, changelogs,
  skill authoring, and capturing session learnings back into skills. Use on
  "/dev-process", "help me plan this", "debug this", "write a plan", "code review",
  "changelog", "create a skill", or any process/workflow request where you're not
  sure which specific specialist skill applies.
---

# Dev Process — Router

Doesn't do the work itself — figures out which specialist skill the request actually
needs and invokes it via the `Skill` tool.

## Routing table

| If the request is about... | Invoke |
|---|---|
| Turning an idea into a design/spec before any implementation | `brainstorming` |
| Writing a bite-sized, TDD-focused implementation plan from a spec | `writing-plans` |
| Creating, editing, or verifying a skill before deployment | `writing-skills` |
| Debugging any bug/test failure/unexpected behavior before proposing a fix | `systematic-debugging` |
| Executing an implementation plan's independent tasks in this session | `subagent-driven-development` |
| Executing a written plan in a separate session with review checkpoints | `executing-plans` |
| 2+ independent tasks with no shared state — parallel agent dispatch | `dispatching-parallel-agents` |
| Automatically decomposing a complex task into parallel dispatches | `task-decompose` |
| Splitting god files / reorganizing into domain folders | `modularize` |
| Isolating feature work via git worktrees before executing a plan | `using-git-worktrees` |
| Starting any conversation — how to find/use skills at all | `using-superpowers` |
| Deciding how to integrate finished, tested work | `finishing-a-development-branch` |
| Requesting a code review before merging | `requesting-code-review` |
| Evaluating code-review feedback before implementing it | `receiving-code-review` |
| Confirming work is actually complete/passing before claiming so | `verification-before-completion` |
| Testing a real-time/media/AI-pipeline app CI has no hardware for | `testing-dags` |
| Writing a failing test before implementing any feature/bugfix | `test-driven-development` |
| Creating/modifying/measuring a skill from scratch | `skill-creator` |
| Absorbing a session's real workflow back into the skill(s) it touched | `syncing-skills-from-session` |
| Backfilling or updating a repo's `docs/CHANGELOG.md` from merged PRs | `recording-changelog` |
| Capturing corrections/learnings/errors for continuous improvement | `self-improvement` |

## Fallback

If nothing above matches clearly, list the candidates above and ask which one fits
rather than guessing.
