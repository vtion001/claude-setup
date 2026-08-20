# Dispatching audit subagents in parallel

The orchestrator must spawn all 6 audit subagents in **one message with
6 Agent tool calls**. Sequential dispatch defeats the purpose.

## The single message pattern

In Claude Code, multiple Agent tool calls in the same message run in
parallel. Use this exact shape:

```
<single message containing:>
  Agent(subagent_type=ios-ui-auditor,        description="UI impl audit",          prompt="...")
  Agent(subagent_type=ios-backend-auditor,   description="Backend audit",          prompt="...")
  Agent(subagent_type=ios-integration-auditor, description="Integration audit",    prompt="...")
  Agent(subagent_type=ios-security-auditor,  description="Security audit",         prompt="...")
  Agent(subagent_type=ios-qa-auditor,        description="QA audit",               prompt="...")
  Agent(subagent_type=ios-code-reviewer,     description="Code review audit",      prompt="...")
```

## Prompt template per subagent

All 6 subagents accept the same prompt shape. Customize the audit name
in the body:

```
Audit cwd as <audit-name>. Project at: <project-root>.
Apply default flags unless overridden. Return your standard structured
summary + JSON findings block. Be terse — under 500 words.
```

If `--quick` was passed to the orchestrator, append:
```
Use --quick mode.
```

If `--skip` excludes a subagent, do NOT spawn it. Reduce iHS denominator
accordingly.

## After dispatch

Wait for all 6 returns. The Agent tool returns each subagent's final
message. Parse the JSON findings block from each (between fenced
```json blocks).

Aggregate into a dict:
```python
results = {
    "security":    {...},
    "backend":     {...},
    "ui-impl":     {...},
    "integration": {...},
    "qa":          {...},
    "code-review": {...}
}
```

Hand off to the synthesis step (`synthesize-report.md`).
