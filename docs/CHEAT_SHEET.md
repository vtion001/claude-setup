# CLAUDE CODE CHEAT SHEET
## 56 Plugins | 350+ Commands | 9 MCP Servers

═══════════════════════════════════════════════════════════════
                    ESSENTIAL COMMANDS
═══════════════════════════════════════════════════════════════

AI WORKFLOW     → /superpowers
TRAIN MODEL     → /huggingface-skills train [model]
BUILD UI        → /frontend-design create [component]
DESIGN API      → /postman design
GIT COMMIT      → /commit-commands:commit
SECURITY SCAN   → /semgrep scan
DEPLOY          → /deploy-on-aws launch
DEBUG           → /sentry analyze

═══════════════════════════════════════════════════════════════
                       AI / ML
═══════════════════════════════════════════════════════════════

/huggingface-skills train [model] on [dataset]
/huggingface-skills deploy to spaces
/huggingface-skills evaluate [model]
/fiftyone visualize dataset
/fiftyone find duplicates
/fiftyone analyze model predictions
/pinecone create index
/pinecone query vectors
/goodmem store context
/goodmem retrieve memories
/data-engineering author DAG
/data-engineering debug pipeline
/atlan search data assets
/qodo-skills apply pattern

═══════════════════════════════════════════════════════════════
                     DATABASES
═══════════════════════════════════════════════════════════════

/mongodb connect [db]          /mongodb query
/prisma migrate               /prisma studio
/supabase connect project     /supabase manage auth
/firebase deploy functions    /firebase manage firestore
/cockroachdb explore schemas  /cockroachdb debug queries
/prisma db push               /prisma generate

═══════════════════════════════════════════════════════════════
                     FRONTEND
═══════════════════════════════════════════════════════════════

/frontend-design create [component]
/frontend-design build [page type]
/frontend-design generate responsive
/laravel-boost create model [name]
/laravel-boost migrate
/sanity-plugin query content
/sanity-plugin build schemas
/mintlify init docs
/netlify-skills deploy
/vercel deploy
/expo build project

═══════════════════════════════════════════════════════════════
                       BACKEND
═══════════════════════════════════════════════════════════════

/postman sync collections
/postman generate client
/postman run tests
/aws-serverless build Lambda
/aws-serverless deploy SAM
/deploy-on-aws assess
/deploy-on-aws launch

═══════════════════════════════════════════════════════════════
                       DEVOPS
═══════════════════════════════════════════════════════════════

/github create issue [title]
/github manage PRs
/github review code
/gitlab handle merge requests
/gitlab configure pipelines
/commit-commands:commit
/commit-commands:push
/vercel deploy
/netlify-skills deploy
/deploy-on-aws launch
/aws-serverless debug

═══════════════════════════════════════════════════════════════
                     SECURITY
═══════════════════════════════════════════════════════════════

/aikido scan vulnerabilities
/aikido detect secrets
/semgrep scan code
/sonarqube-agent-plugins analyze
/security-guidance check [file]
/optibot review code

═══════════════════════════════════════════════════════════════
                     TESTING
═══════════════════════════════════════════════════════════════

/playwright test [flow]
/playwright screenshot
/playwright automate browser
/code-review analyze PR
/pr-review-toolkit review all
/postman run tests

═══════════════════════════════════════════════════════════════
                    MONITORING
═══════════════════════════════════════════════════════════════

/sentry access errors
/sentry analyze stack
/postHog access analytics
/postHog manage flags
/pagerduty score diffs
/context7 lookup [topic]

═══════════════════════════════════════════════════════════════
                      DOCS
═══════════════════════════════════════════════════════════════

/mintlify init
/context7 lookup [library]
/notion search pages
/notion create document

═══════════════════════════════════════════════════════════════
                    LANGUAGES
═══════════════════════════════════════════════════════════════

TypeScript → /typescript-lsp
Python    → /pyright-lsp
Rust      → /rust-analyzer-lsp
Go        → /gopls-lsp
Java      → /jdtls-lsp
C++       → /clangd-lsp
C#        → /csharp-lsp

═══════════════════════════════════════════════════════════════
                    PLUGINS
═══════════════════════════════════════════════════════════════

/plugin list                              List plugins
/plugin install [name]                   Install
/plugin uninstall [name]                   Remove
/plugin marketplace add [repo]             Add marketplace

═══════════════════════════════════════════════════════════════
                 QUICK STARTERS
═══════════════════════════════════════════════════════════════

FULL STACK:
/superpowers → /frontend-design → /postman → /prisma → /vercel

AI/ML:
/superpowers → /huggingface-skills → /fiftyone → /pinecone

SECURITY:
/semgrep → /aikido → /security-guidance → /sonarqube

═══════════════════════════════════════════════════════════════

Full Guide: ~/.claude/CLAUDE_CODE_DEVELOPER_GUIDE.md
Quick Ref:  ~/.claude/QUICK_REFERENCE.md