---
name: task-decompose
description: Automatically decompose complex tasks into parallel agent dispatches for faster execution
---

# Task Decomposition & Parallel Dispatch Skill

## Purpose
When invoked, analyze the task and decompose it into independent sub-tasks that can be executed in parallel via dispatch-agent. This is the PRIMARY speed optimization — not using faster models, but parallelizing work.

## When to Invoke
- Complex task with multiple components
- Multiple files/modules involved
- Different subsystems can be worked on independently
- When asked to "speed this up" or "make this faster"

## Analysis Steps

### 1. Identify Independent Domains
Ask: Can these be done simultaneously?
- Different files/modules being modified?
- Different subsystems (auth vs. API vs. UI)?
- Different test files?
- No shared state between sub-tasks?

### 2. Group by Dependency
- **Independent** → Dispatch parallel agents
- **Related** → Must be sequential

### 3. For Each Independent Domain
Create an agent dispatch with:
- **Specific scope**: Exact files or subsystem
- **Clear goal**: What success looks like
- **Constraints**: What NOT to touch
- **Output format**: Summary template

## Output Structure
Return a structured decomposition BEFORE dispatching:

```
## Task Decomposition

### Sub-task 1: [Scope]
- **Goal**: [specific objective]
- **Files**: [exact files to modify]
- **Agent prompt**: [full prompt for this agent]

### Sub-task 2: [Scope]
- **Goal**: [specific objective]
- **Files**: [exact files to modify]
- **Agent prompt**: [full prompt for this agent]

### [Continue for each...]

## Integration Plan
After all agents complete:
1. Review each summary
2. Check for file conflicts
3. Verify fixes work together
4. Run full test suite
```

## Agent Prompt Template
Each dispatched agent should receive:

```markdown
# Agent: [Task Name]

## Context
[Brief context about what this task is about]

## Goal
[Specific, measurable goal]

## Scope
- **Files to modify**: [exact list]
- **Files to NOT modify**: [critical constraints]

## Constraints
- Do NOT touch files outside scope
- Do NOT change production code outside your task
- Return summary in specified format

## Success Criteria
[What "done" looks like]

## Output Format
Return:
```
## Agent Results
### Found
[What was identified]
### Changed
[What was modified]
### Verification
[How to verify it works]
```
```

## Key Principle
**Dispatch agents in parallel using Agent tool with `run_in_background: true`**

Example:
```typescript
Agent({ description: "Domain 1 task", prompt: "...", run_in_background: true })
Agent({ description: "Domain 2 task", prompt: "...", run_in_background: true })
Agent({ description: "Domain 3 task", prompt: "...", run_in_background: true })
// All three run concurrently
```

## Warning Signs (Don't Parallelize)
- Tasks share state or dependencies
- Fixing one might break another
- Need to understand full system first
- Exploratory (not yet known what's broken)
