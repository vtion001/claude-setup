---
description: "Activate a local agent from ~/agents/. Usage: /agent <name> [args...]"
---

# Agent Dispatcher

The user wants to activate a local agent. Run it using the agent management script.

## Instructions

1. Parse the arguments: `$ARGUMENTS`
   - First word = agent name
   - Remaining words = arguments to pass to the agent

2. Run the agent:
```bash
python3 /Users/archerterminez/agent activate <agent_name> [args...]
```

3. If no agent name is provided, list available agents:
```bash
python3 /Users/archerterminez/agent list
```

4. Show the agent's output to the user.

## Available Agents

azure-agent, azure-architect, azure-devops-engineer, azure-server-developer, business-research, content-creator, data-analyst, database-developer, debug-agent, debug-test-agent, deep-research, dev-orchestrator, devops-engineer, feasibility-study, forex-notifier, forex-trader, forex-trader-instructor, frontend-developer, fullstack-developer, hipaa-compliance-agent, job-hunter, lead-generator, marketing-orchestrator, media-psychologist, meta-ads-specialist, n8n-workflow-builder, presentation-agent, product-research, project-manager, qa-engineer, quotation-generator, report-orchestrator, resume-optimizer, search-console-analyst, search-console-analyst-backup, superpowers, tech-architect, tech-stacks-researcher, todo-tracker, website-analyst
