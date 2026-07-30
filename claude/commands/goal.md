---
description: Define a verifiable autonomous goal — ask clarifying questions first, then work until the success check passes
argument-hint: [what you want done]
---

The user is setting a **goal**: a verifiable end-state I work toward autonomously, looping (plan → edit → run the verification check → fix) until the check passes or a stop limit is reached. Note: native Claude Code has no built-in `/goal` engine — *I* am the loop and *I* am the completion checker by actually running the verification command and reporting its real output.

Goal request (may be empty): $ARGUMENTS

## Step 1 — Clarify BEFORE doing any work (REQUIRED)
Use the **AskUserQuestion** tool to lock down anything ambiguous. A well-formed goal needs all four parts:

1. **Finish line** — the exact, objective, binary end state (not subjective like "better").
2. **Verification** — a *runnable* check the success hinges on: a command that exits 0 (`npm test`, `tsc --noEmit`), a file count `< N`, a `grep` that returns empty, a Lighthouse score, etc.
3. **Scope boundaries** — what I must **NOT** modify (so I don't satisfy the check by cheating, e.g. deleting failing tests).
4. **Stop limit** — a turn/iteration cap; if hit, I stop and report what's left.

Ask only about the parts that are unclear or missing from the request — skip what's already specified. Offer concrete options where possible. Do not begin work until these are settled.

## Step 2 — Confirm the goal spec
Restate it back in this structure and get a go-ahead:
- **Task:** …
- **Done when:** `<runnable check>`
- **Don't touch:** …
- **Stop after:** N turns → report remaining work

## Step 3 — Execute autonomously
Work toward the finish line without prompting between every step. After each meaningful change, **actually run the verification check** and report its real output — never claim "done" until the check genuinely passes. If the stop limit is reached first, halt and summarize exactly what remains.
