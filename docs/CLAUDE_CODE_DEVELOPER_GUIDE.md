# Claude Code Developer Toolkit - Complete Guide

## Overview

This guide covers 56+ installed plugins for full stack development, AI/ML, and autonomous coding workflows.

---

## Table of Contents

1. [Getting Started](#getting-started)
2. [Core Skills](#core-skills)
3. [AI/ML Development](#ai-ml-development)
4. [Database Management](#database-management)
5. [Frontend & Full Stack](#frontend--full-stack)
6. [Backend & APIs](#backend--apis)
7. [DevOps & Cloud](#devops--cloud)
8. [Security & Code Quality](#security--code-quality)
9. [Testing & Monitoring](#testing--monitoring)
10. [MCP Servers Reference](#mcp-servers-reference)
11. [Quick Reference Cheatsheet](#quick-reference-cheatsheet)

---

## Getting Started

### Activating Your Toolkit

When you start Claude Code, plugins load automatically. You can:

1. **List installed plugins:** `/plugin list`
2. **Check plugin status:** `/plugin` → Installed tab
3. **Get help:** Type `/help` in Claude Code

### Plugin Activation Methods

```
/plugin-name          # Direct invocation (manual)
/skill-name           # Alternative syntax for skills
Claude auto-invokes   # Based on context (automatic)
```

---

## Core Skills

### 1. Superpowers (`/superpowers`)

The flagship plugin for AI-powered development methodology.

**What it teaches:**
- Brainstorming techniques
- Subagent development with code review
- Debugging strategies
- TDD (Test-Driven Development)
- Skill authoring

**Usage:**
```
/superpower start a new feature
/superpower debug this error
/superpower teach me TDD
```

**Best for:** Learning AI-augmented development workflows.

---

### 2. Claude Code Setup (`/claude-code-setup`)

Analyzes your codebase and recommends automations.

**Usage:**
```
/claude-code-setup analyze my project
/claude-code-setup recommend hooks
/claude-code-setup suggest MCP servers
```

---

### 3. Claude MD Management (`/claude-md-management`)

Maintains and improves CLAUDE.md files.

**Usage:**
```
/claude-md-management audit
/claude-md-management capture learnings
/claude-md-management improve quality
```

---

## AI/ML Development

### 1. Hugging Face Skills (`/huggingface-skills`)

Build, train, evaluate, and use open source AI models.

**Key Features:**
- Model training workflows
- Dataset management
- Space deployment
- Inference optimization

**Usage:**
```
/huggingface-skills train model on dataset X
/huggingface-skills evaluate model performance
/huggingface-skills deploy to huggingface spaces
/huggingface-skills list available models
```

**Example:**
```
/huggingface-skills fine-tune bert for sentiment analysis
```

---

### 2. FiftyOne (`/fiftyone`)

Build high-quality datasets and computer vision models.

**Key Features:**
- Dataset visualization
- Model analysis
- Duplicate detection
- Inference runs

**Usage:**
```
/fiftyone visualize dataset
/fiftyone find duplicates
/fiftyone analyze model predictions
/fiftyone evaluate model quality
```

---

### 3. Pinecone (Vector Database)

Vector database integration for AI applications.

**Best for:**
- Semantic search
- RAG (Retrieval Augmented Generation)
- Similarity matching
- Embeddings storage

**Usage:**
```
Create and manage vector indexes
Query for similar embeddings
Scale vector operations
```

---

### 4. GoodMem (`/goodmem`)

Memory infrastructure for AI agents.

**Usage:**
```
/goodmem store context from session
/goodmem retrieve relevant memories
/goodmem manage embedding spaces
```

---

### 5. Data Engineering (`/data-engineering`)

Data pipeline development with Apache Airflow.

**Usage:**
```
/data-engineering author DAG
/data-engineering debug pipeline failure
/data-engineering trace data lineage
/data-engineering migrate Airflow 2 to 3
```

---

### 6. Atlan (`/atlan`)

Data catalog for search, exploration, and governance.

**Usage:**
```
/atlan search data assets
/atlan explore schema
/atlan manage data quality rules
```

---

### 7. Qodo Skills (`/qodo-skills`)

Reusable AI agent capabilities library.

**Usage:**
```
/qodo-skills list capabilities
/qodo-skills apply coding pattern
```

---

## Database Management

### 1. MongoDB (`/mongodb`)

Connect to MongoDB, explore data, manage collections.

**Usage:**
```
/mongodb connect to database
/mongodb list collections
/mongodb query documents
/mongodb optimize indexes
/mongodb manage schemas
```

**MCP Server:** Yes - Full MongoDB integration

---

### 2. Prisma (`/prisma`)

Postgres database management, migrations, queries.

**Usage:**
```
/prisma migrate
/prisma generate
/prisma studio
/prisma db push
/prisma execute SQL
```

**MCP Server:** Yes - Postgres integration

---

### 3. Supabase (`/supabase`)

Postgres + auth, storage, real-time subscriptions.

**Usage:**
```
/supabase connect project
/supabase manage auth
/supabase handle storage
/supabase setup real-time
```

**MCP Server:** Yes - Full Supabase integration

---

### 4. Firebase (`/firebase`)

Firestore, auth, cloud functions, hosting.

**Usage:**
```
/firebase deploy functions
/firebase manage firestore
/firebase setup authentication
/firebase configure hosting
```

**MCP Server:** Yes - Full Firebase integration

---

### 5. CockroachDB (`/cockroachdb`)

Distributed SQL database operations.

**Usage:**
```
/cockroachdb explore schemas
/cockroachdb write optimized SQL
/cockroachdb debug queries
/cockroachdb manage distributed tables
```

---

### 6. PlanetScale (`/planetscale`)

MySQL-compatible serverless database.

**Usage:**
```
/planetscale connect org
/planetscale explore databases
/planetscale manage branches
/planetscale review schema changes
```

**Note:** Currently failing to load - may need manual fix.

---

## Frontend & Full Stack

### 1. Frontend Design (`/frontend-design`)

Create production-grade frontend interfaces.

**Usage:**
```
/frontend-design create component library
/frontend-design build landing page
/frontend-design design dashboard
/frontend-design generate responsive layouts
```

**Best practices:**
- Specify design system (Tailwind, MUI, etc.)
- Include accessibility requirements
- Define responsive breakpoints

---

### 2. Laravel Boost (`/laravel-boost`)

Laravel development toolkit.

**Usage:**
```
/laravel-boost artisan commands
/laravel-boost create models
/laravel-boost setup migrations
/laravel-boost configure routes
/laravel-boost optimize performance
```

---

### 3. Sanity Plugin (`/sanity-plugin`)

CMS content platform integration.

**Usage:**
```
/sanity-plugin query content
/sanity-plugin author content
/sanity-plugin build schemas
/sanity-plugin manage datasets
```

---

### 4. Mintlify (`/mintlify`)

Build documentation sites.

**Usage:**
```
/mintlify init documentation
/mintlify convert markdown files
/mintlify publish docs
/mintlify style documentation
```

---

### 5. Netlify Skills (`/netlify-skills`)

Netlify deployment and configuration.

**Usage:**
```
/netlify-skills deploy site
/netlify-skills configure functions
/netlify-skills setup edge functions
/netlify-skills manage blobs
/netlify-skills configure forms
```

---

### 6. Vercel (`/vercel`)

Vercel deployment management.

**Usage:**
```
/vercel deploy
/vercel check build status
/vercel access logs
/vercel configure domains
/vercel manage environment
```

---

### 7. Expo (React Native)

Mobile development with Expo.

**Usage:**
```
/expo build project
/expo deploy mobile app
/expo upgrade dependencies
/expo debug device
```

---

## Backend & APIs

### 1. Postman (`/postman`)

Full API lifecycle management.

**Usage:**
```
/postman sync collections
/postman generate client code
/postman discover APIs
/postman run tests
/postman create mocks
/postman monitor API health
```

**Best for:** REST, GraphQL API development

---

### 2. AWS Serverless (`/aws-serverless`)

Serverless application development on AWS.

**Usage:**
```
/aws-serverless design architecture
/aws-serverless build Lambda functions
/aws-serverless deploy SAM templates
/aws-serverless test locally
/aws-serverless debug functions
```

---

### 3. Deploy on AWS (`/deploy-on-aws`)

AWS deployment with cost estimation.

**Usage:**
```
/deploy-on-aws assess architecture
/deploy-on-aws estimate costs
/deploy-on-aws deploy with IaC
/deploy-on-aws optimize spending
```

---

---

### 4. Chrome DevTools MCP

Control and inspect live Chrome browser.

**Usage:**
- Record performance traces
- Analyze network requests
- Debug JavaScript
- Screenshot pages
- Console interaction

---

## DevOps & Git

### 1. GitHub (`/github`)

Repository management via MCP.

**Usage:**
```
/github create issue
/github manage PRs
/github review code
/github search repositories
/github manage actions
/github configure webhooks
```

**MCP Server:** Yes - Full GitHub integration

---

### 2. GitLab (`/gitlab`)

GitLab DevOps integration.

**Usage:**
```
/gitlab manage repos
/gitlab handle merge requests
/gitlab configure CI/CD pipelines
/gitlab manage issues
/gitlab manage wikis
```

**MCP Server:** Yes - Full GitLab integration

---

### 3. Commit Commands (`/commit-commands`)

Streamlined git workflow.

**Usage:**
```
/commit-commands:commit
/commit-commands:push
/commit-commands:create-pr
/commit-commands:ammend
```

---

### 4. PR Review Toolkit (`/pr-review-toolkit`)

Comprehensive PR review with specialized agents.

**Usage:**
```
/pr-review-toolkit review comments
/pr-review-toolkit review tests
/pr-review-toolkit review error handling
/pr-review-toolkit review type design
/pr-review-toolkit review code quality
```

---

### 5. Code Review (`/code-review`)

Automated code review for PRs.

**Usage:**
```
/code-review analyze PR
/code-review check security
/code-review verify style
```

---

## Security & Code Quality

### 1. Aikido (`/aikido`)

Security scanning - SAST, secrets, IaC vulnerabilities.

**Usage:**
```
/aikido scan for vulnerabilities
/aikido detect secrets
/aikido check IaC security
/aikido generate report
```

---

### 2. Semgrep (`/semgrep`)

Static analysis for security vulnerabilities.

**Usage:**
```
/semgrep scan code
/semgrep catch vulnerabilities
/semgrep guide secure coding
/semgrep enforce patterns
```

---

### 3. SonarQube Agent Plugins (`/sonarqube-agent-plugins`)

Code quality and security analysis.

**Usage:**
```
/sonarqube-agent-plugins analyze code
/sonarqube-agent-plugins review quality
/sonarqube-agent-plugins check security
/sonarqube-agent-plugins measure coverage
```

---

### 4. Security Guidance (`/security-guidance`)

Real-time security reminders when editing.

**Usage:**
- Automatic warnings for command injection
- XSS vulnerability detection
- SQL injection prevention
- Secure authentication patterns

---

### 5. Sentry (`/sentry`)

Error monitoring and debugging.

**Usage:**
```
/sentry access error reports
/sentry analyze stack traces
/sentry search issues by fingerprint
/sentry debug in production
```

**MCP Server:** Yes - Sentry integration

---

## Testing & Monitoring

### 1. Playwright (`/playwright`)

Browser automation and E2E testing.

**Usage:**
```
/playwright test UI interactions
/playwright automate browser
/playwright take screenshots
/playwright record performance
/playwright run E2E tests
```

**MCP Server:** Yes - Microsoft Playwright

---

### 2. PostHog (`/posthog`)

Analytics, feature flags, experimentation.

**Usage:**
```
/posthog access analytics
/posthog manage feature flags
/posthog run experiments
/posthog track errors
/posthog analyze user behavior
```

**MCP Server:** Yes - PostHog integration

---

### 3. PagerDuty (`/pagerduty`)

Incident management and risk scoring.

**Usage:**
```
/pagerduty score pre-commit diffs
/pagerduty correlate incidents
/pagerduty enhance code security
/pagerduty manage on-call
```

---

### 4. Context7 (`/context7`)

Up-to-date documentation lookup.

**Usage:**
```
/context7 lookup React docs
/context7 get Next.js latest
/context7 fetch API references
/context7 pull version-specific docs
```

---

## Development Tools

### 1. MCP Server Dev (`/mcp-server-dev`)

Design and build MCP servers.

**Usage:**
```
/mcp-server-dev design server
/mcp-server-dev build from scratch
/mcp-server-dev deploy server
/mcp-server-dev test connections
```

---

### 2. Agent SDK Dev (`/agent-sdk-dev`)

Claude Agent SDK development.

**Usage:**
```
/agent-sdk-dev build agent
/agent-sdk-dev integrate SDK
/agent-sdk-dev test agent
/agent-sdk-dev deploy agent
```

---

### 3. Plugin Dev (`/plugin-dev`)

Create Claude Code plugins.

**Usage:**
```
/plugin-dev create plugin
/plugin-dev add skills
/plugin-dev add agents
/plugin-dev publish marketplace
```

---

### 4. Feature Dev (`/feature-dev`)

Comprehensive feature development workflow.

**Usage:**
```
/feature-dev start feature
/feature-dev explore architecture
/feature-dev implement feature
/feature-dev test feature
/feature-dev review feature
```

---

### 5. Greptile (`/greptile`)

AI-powered codebase search.

**Usage:**
```
/greptile find code patterns
/greptile search natural language
/greptile understand codebase
/greptile locate functions
```

---

## Web Scraping & Data

### 1. Firecrawl (`/firecrawl`)

Web scraping and content extraction.

**Usage:**
```
/firecrawl scrape website
/firecrawl convert to markdown
/firecrawl extract structured data
/firecrawl crawl entire site
```

---

### 2. Bright Data Plugin (`/brightdata-plugin`)

Web scraping, Google search, data extraction.

**Usage:**
```
/brightdata-plugin search Google
/brightdata-plugin extract data
/brightdata-plugin structure web content
```

---

### 3. Nimble (`/nimble`)

Web data toolkit - search, extract, map.

**Usage:**
```
/nimble search web
/nimble extract data
/nimble crawl pages
/nimble build data agents
```

---

## Communication

### 1. Slack (`/slack`)

Slack workspace integration.

**Usage:**
```
/slack search messages
/slack access channels
/slack read threads
/slack post notifications
```

**MCP Server:** Yes - Slack integration

---

### 2. Notion (`/notion`)

Notion workspace integration.

**Usage:**
```
/notion search pages
/notion create documents
/notion manage databases
/notion update content
```

---

### 3. Discord (`/discord`)

Discord messaging bridge.

**Usage:**
```
/discord access channels
/discord manage allowlists
/discord post messages
/discord configure policies
```

---

## Language Servers (Code Intelligence)

These require binary installation but provide:
- Auto-completion
- Type checking
- Error diagnostics
- Code navigation
- Refactoring support

### Installed LSPs:

| Language | Plugin | Binary Required |
|----------|--------|-----------------|
| TypeScript | typescript-lsp | typescript-language-server |
| Python | pyright-lsp | pyright-langserver |
| Rust | rust-analyzer-lsp | rust-analyzer |
| Go | gopls-lsp | gopls |
| Java | jdtls-lsp | jdtls |
| C++ | clangd-lsp | clangd |
| C# | csharp-lsp | csharp-ls |
| Ruby | ruby-lsp | ruby-lsp |
| PHP | php-lsp | intelephense |

---

## MCP Servers Reference

### Official MCP Integrations:

| Service | Capabilities |
|---------|--------------|
| **GitHub** | Issues, PRs, repos, actions |
| **GitLab** | Repos, MRs, pipelines, wikis |
| **Firebase** | Firestore, auth, functions |
| **Supabase** | DB, auth, storage, real-time |
| **MongoDB** | Collections, queries, indexes |
| **Sentry** | Errors, stack traces, issues |
| **PostHog** | Analytics, feature flags |
| **Playwright** | Browser automation |
| **Slack** | Messages, channels |
| **Chrome DevTools** | Performance, debugging |

---

## Quick Reference Cheatsheet

### Starting a New Project

```
/superpowers start project
/claude-code-setup analyze
/frontend-design create structure
/github setup repository
```

### AI/ML Development

```
/huggingface-skills train model
/fiftyone visualize dataset
/pinecone setup vector store
/data-engineering build pipeline
```

### Full Stack Development

```
/frontend-design create UI
/postman design API
/prisma setup database
/laravel-boost build backend
/vercel deploy
```

### Code Review

```
/code-review analyze PR
/semgrep scan security
/aikido check vulnerabilities
/sonarqube-agent-plugins quality gate
```

### Debugging

```
/superpowers debug
/sentry analyze errors
/playwright reproduce issue
/chrome-devtools-mcp inspect
```

### Deployment

```
/deploy-on-aws launch
/vercel deploy
/netlify-skills configure
/aws-serverless monitor
```

### Documentation

```
/mintlify build docs
/context7 lookup docs
/notion update wiki
```

---

## Troubleshooting

### Plugin Not Loading
```bash
/plugin list  # Check status
/plugin uninstall <name>@marketplace
/plugin install <name>@marketplace
```

### MCP Server Issues
- Verify credentials configured
- Check network connectivity
- Restart Claude Code

### LSP Not Working
- Install required binary
- Verify binary in PATH
- Check `/plugin` Errors tab

### Performance Issues
- Disable unused LSPs
- Reduce plugin count
- Use `/compact` to free context

---

## Best Practices

### 1. Selective Plugin Usage
- Only enable plugins you actively use
- Too many plugins can slow startup

### 2. Context Management
- Use `/compact` when context fills
- Invoke skills only when needed
- Use `disable-model-invocation: true` for manual skills

### 3. Security First
- Always use security scanning on PRs
- Enable security-guidance for real-time warnings
- Regular dependency audits

### 4. MCP Credential Setup
- Store API keys in environment variables
- Use `.env` files for project-specific credentials
- Rotate keys regularly

### 5. Skill Customization
- Create project-specific skills in `.claude/skills/`
- Share skills via plugins for teams
- Document custom skill usage in CLAUDE.md

---

## Getting Help

- `/help` - General Claude Code help
- `/plugin` - Plugin management
- `/superpowers` - AI development methodology
- Claude Code docs: https://code.claude.com/docs

---

## Changelog

- **2026-04-09**: Initial setup - 56 plugins installed
  - AI/ML: huggingface-skills, fiftyone, pinecone, goodmem
  - Databases: mongodb, prisma, supabase, cockroachdb, firebase
  - DevOps: github, gitlab, aws-serverless, vercel, netlify
  - Security: aikido, semgrep, sonarqube, security-guidance
  - Development: mcp-server-dev, agent-sdk-dev, plugin-dev
  - Code Intelligence: pyright, typescript, rust-analyzer, gopls, jdtls

---

*Maintained by Claude Code Developer Toolkit*