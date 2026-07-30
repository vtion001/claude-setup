# Claude Code Developer Toolkit - Quick Reference Card

## Most Used Commands

| Task | Command |
|------|---------|
| Start AI workflow | `/superpowers` |
| Train AI model | `/huggingface-skills train [model]` |
| Build frontend | `/frontend-design create [component]` |
| Design API | `/postman design` |
| Git commit | `/commit-commands:commit` |
| Review PR | `/code-review analyze PR` |
| Scan security | `/semgrep scan` |
| Deploy to cloud | `/deploy-on-aws launch` |
| Debug error | `/sentry analyze` |
| Test UI | `/playwright test` |

---

## AI/ML Development

```
/huggingface-skills train [model] on [dataset]
/huggingface-skills deploy to spaces
/huggingface-skills evaluate [model]

/fiftyone visualize dataset
/fiftyone find duplicates
/fiftyone analyze model

/pinecone query vectors
/pinecone create index

/goodmem store context
/goodmem retrieve memories

/data-engineering author DAG
/data-engineering debug pipeline
/data-engineering migrate Airflow

/atlan search data assets
/atlan manage quality rules
```

---

## Database Operations

```
/mongodb connect [database]
/mongodb list collections
/mongodb query documents

/prisma migrate
/prisma generate
/prisma db push
/prisma studio

/supabase connect project
/supabase manage auth
/supabase setup real-time

/firebase deploy functions
/firebase manage firestore

/cockroachdb explore schemas
/cockroachdb debug queries
```

---

## Frontend & Full Stack

```
/frontend-design create component [name]
/frontend-design build [page type]
/frontend-design generate responsive

/laravel-boost create model [name]
/laravel-boost migrate
/laravel-boost setup routes

/sanity-plugin query content
/sanity-plugin build schemas

/mintlify init docs
/mintlify publish

/netlify-skills deploy
/netlify-skills configure functions

/vercel deploy
/vercel check status
/vercel access logs
```

---

## Backend & APIs

```
/postman sync collections
/postman generate client
/postman run tests
/postman create mocks

/aws-serverless build Lambda
/aws-serverless deploy SAM
/aws-serverless debug

/deploy-on-aws assess
/deploy-on-aws estimate costs
/deploy-on-aws launch
```

---

## Git & DevOps

```
/github create issue [title]
/github manage PRs
/github review code
/github search repos

/gitlab manage repos
/gitlab handle merge requests
/gitlab configure pipelines

/commit-commands:commit
/commit-commands:push
/commit-commands:create-pr

/pr-review-toolkit review all
/pr-review-toolkit review tests
/pr-review-toolkit review security

/feature-dev start [feature name]
/feature-dev implement
/feature-dev test
```

---

## Security & Quality

```
/aikido scan vulnerabilities
/aikido detect secrets
/aikido check IaC

/semgrep scan code
/semgrep enforce patterns

/sonarqube-agent-plugins analyze
/sonarqube-agent-plugins quality gate

/security-guidance check [file]
/security-guidance warn

/sentry access errors
/sentry analyze stack
/sentry debug production

/optibot review code
/optibot catch bugs
```

---

## Testing & Monitoring

```
/playwright test [flow]
/playwright automate browser
/playwright screenshot

/postHog access analytics
/postHog manage flags
/postHog run experiments

/pagerduty score diffs
/pagerduty correlate incidents

/context7 lookup [topic]
/context7 get [library] docs
/context7 pull version [version]
```

---

## Development Tools

```
/mcp-server-dev design server
/mcp-server-dev build
/mcp-server-dev deploy

/agent-sdk-dev build agent
/agent-sdk-dev integrate SDK

/plugin-dev create plugin
/plugin-dev publish

/claude-code-setup analyze
/claude-code-setup recommend

/greptile find [pattern]
/greptile understand codebase

/code-review analyze PR
/code-review check security
```

---

## Web & Data

```
/firecrawl scrape [url]
/firecrawl convert to markdown
/firecrawl extract structured

/nimble search web
/nimble extract data
/nimble build agents

/brightdata-plugin search Google
/brightdata-plugin extract data
```

---

## Communication

```
/slack search messages
/slack access channels
/slack post notification

/notion search pages
/notion create document
/notion update content

/discord access channels
/discord post message
```

---

## Language Servers

| Language | Binary Needed | Features |
|----------|---------------|----------|
| TypeScript | typescript-language-server | autocomplete, types |
| Python | pyright-langserver | type checking |
| Rust | rust-analyzer | borrow check, refactor |
| Go | gopls | go to def, find refs |
| Java | jdtls | code completion |
| C++ | clangd | diagnostics |
| C# | csharp-ls | Roslyn analysis |
| Ruby | ruby-lsp | code actions |
| PHP | intelephense | code intelligence |

---

## MCP Servers Available

```
GitHub        → Issues, PRs, repos, actions
GitLab        → Repos, MRs, pipelines, wikis
Firebase      → Firestore, auth, functions
Supabase      → DB, auth, storage, real-time
MongoDB       → Collections, queries, indexes
Sentry        → Errors, stack traces, issues
PostHog       → Analytics, feature flags
Playwright    → Browser automation
Slack         → Messages, channels
Chrome DevTools → Performance, debugging
```

---

## Quick Project Starters

### New Full Stack Project:
```
/superpowers start project
/frontend-design scaffold
/prisma setup database
/postman design API
/github init repo
/deploy-on-aws launch
```

### AI/ML Project:
```
/superpowers start AI project
/huggingface-skills train model
/fiftyone prepare dataset
/pinecone setup vector store
/data-engineering build pipeline
```

### API Project:
```
/superpowers design API
/postman create collection
/prisma define schema
/github commit
/playwright test endpoints
/deploy-on-aws launch
```

---

## Essential Slash Commands

| Category | Must-Know |
|----------|-----------|
| AI Dev | `/superpowers`, `/huggingface-skills`, `/fiftyone` |
| Databases | `/mongodb`, `/prisma`, `/supabase`, `/firebase` |
| Frontend | `/frontend-design`, `/expo`, `/laravel-boost` |
| Backend | `/postman`, `/aws-serverless`, `/deploy-on-aws` |
| DevOps | `/github`, `/vercel`, `/netlify-skills` |
| Security | `/semgrep`, `/aikido`, `/security-guidance` |
| Quality | `/code-review`, `/pr-review-toolkit`, `/sonarqube` |
| Testing | `/playwright`, `/postman` |
| Docs | `/mintlify`, `/context7` |

---

## Environment Setup

```bash
# Claude Code paths
export CLAUDE_CODE_GIT_BASH_PATH="C:\Program Files\Git\usr\bin\bash.exe"

# API Keys (in .env)
ANTHROPIC_API_KEY=sk-...
HUGGINGFACE_TOKEN=hf_...
OPENAI_API_KEY=sk-...

# MCP Server credentials
GITHUB_TOKEN=ghp_...
SLACK_BOT_TOKEN=xobP...
SENTRY_DSN=https://...
```

---

## Plugin Management

```bash
/plugin list                    # List all plugins
/plugin install [name]         # Install new plugin
/plugin uninstall [name]        # Remove plugin
/plugin marketplace list       # View marketplaces
/plugin marketplace add [repo] # Add marketplace
```

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| Plugin not loading | `/plugin uninstall` then `/plugin install` |
| MCP not working | Check credentials in `.env` |
| LSP errors | Install binary, verify in PATH |
| Slow startup | Disable unused plugins |
| Context full | `/compact` to summarize |

---

## Key Combinations

```
/superpowers + /huggingface-skills  = AI development
/frontend-design + /postman         = Full stack web
/prisma + /mongodb + /supabase      = Database stack
/github + /vercel + /deploy-on-aws  = DevOps pipeline
/semgrep + /aikido + /security-guidance = Security first
/playwright + /code-review + /sentry = Quality assurance
```

---

*Quick Reference Card - 56 Plugins Installed (2026-04-09)*
*Full guide: ~/.claude/CLAUDE_CODE_DEVELOPER_GUIDE.md*