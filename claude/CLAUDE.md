# Claude Code Instructions

## Core Principle
Keep it simple, efficient, robust, best practice and scalable. No overengineering!

## Development Guidelines
1. Don't create files unless necessary
2. Prefer editing over creating new files
3. Keep animations simple and working
4. No unnecessary comments in code
5. Test all changes before marking complete

---

# Git & GitHub CLI (WSL)

## GitHub CLI location
- **`gh` is NOT on PATH in WSL.** The Windows binary lives at:
  `/mnt/c/Program Files/GitHub CLI/gh.exe`
- Invoke it directly, e.g. `GH="/mnt/c/Program Files/GitHub CLI/gh.exe"; "$GH" repo create ...`
- Already authenticated as **vtion001** (keyring, scopes: `repo`, `read:org`, `gist`).
  Use it for repo creation, PRs, and any GitHub API needs.

## Git auth in this WSL session
- **SSH works** for `git@github.com` (authenticated as vtion001) — use SSH remotes for push/fetch/clone.
- **HTTPS credential helper is broken** under WSL (Windows GCM vsock bridge fails). If a repo's
  origin is HTTPS and auth fails, switch it to SSH:
  `git remote set-url <remote> git@github.com:<owner>/<repo>.git`

## Global git identity (already set)
- `user.name  = VJ Rodriguez`
- `user.email = agsdev@allianceglobalsolutions.com`
- If a commit ever fails with "empty ident name", re-apply globally:
  `git config --global user.name "VJ Rodriguez" && git config --global user.email "agsdev@allianceglobalsolutions.com"`

## Gotchas
- Shallow clones (`.git/shallow`, `is-shallow-repository = true`) cannot be pushed to a fresh
  empty repo — run `git fetch --unshallow <remote>` (over SSH) first.

---

# BOB-AGS Project Context

## Project Overview
Call Tracking & QA Analysis platform for Flyland Recovery Network. Laravel 12 + Blade/Alpine.js/Tailwind + PostgreSQL.

## Tech Stack
- **Backend:** Laravel 12, PHP 8.2+, Breeze session auth
- **Frontend:** Blade + Alpine.js + Tailwind CSS (Vite). Vue 3 in package.json but **unused**.
- **DB:** PostgreSQL (prod), SQLite `:memory:` (tests)
- **Queue/Session:** Database-backed
- **AI:** OpenAI GPT-4o primary → OpenRouter → Anthropic fallback
- **STT:** AssemblyAI (primary) + self-hosted Whisper
- **Integration:** CallTrackingMetrics (CTM) REST API v1
- **Error Tracking:** Sentry (`sentry/sentry-laravel` v4.25)
- **Email:** Resend (prod), log driver (dev)

## Quick Reference Commands
```bash
npm run dev              # Dev server (Vite + Laravel + queue)
php artisan test         # Run all tests
php artisan test --filter=TestName  # Single test
npx playwright test      # E2E tests
./vendor/bin/pint        # Lint (PHP)
php artisan migrate      # Run migrations
```

## Key Config Files
| File | Purpose |
|------|---------|
| `config/qarubric.php` | Call QA rubric (107-pt scoring) |
| `config/chat_qa_rubric.php` | Chat QA rubric (Flyland V2, 13 criteria) |
| `config/qa_prompts.php` | Call QA analysis system prompts |
| `config/chat_qa_prompts.php` | Chat QA AI prompts |
| `config/openai.php` | LLM config |
| `config/ctm.php` | CTM API credentials |
| `.env` | Environment variables (SENTRY_LARAVEL_DSN, etc.) |

## Architecture Notes
- Controllers are thin facades; all logic lives in `app/Services/`
- DI via singletons in `AppServiceProvider::register()`
- No external CDN — all assets self-hosted (CSP: `'self'`)
- Sentry auto-discovers; config via `SENTRY_LARAVEL_DSN` env var

## Testing
- PHPUnit uses SQLite `:memory:` (no external DB needed)
- External services (CTM, OpenAI, Anthropic) should be mocked
- E2E default baseURL is Render prod; override with `E2E_BASE_URL` env var

## Git Workflow
- `main` branch for production
- Feature branches: `feat/*`, `fix/*`
- PR required for all changes
- CI runs: PHPUnit (PHP 8.2/8.3/8.4 matrix) + security audit + frontend quality

---

# Team Practices & Methodologies

## Core Methodology: Scrum + Kanban Hybrid

### Scrum Framework (Primary)
- **Sprint Cycles**: 2-week iterations
- **Roles**:
  - **Product Owner**: [Travis]
  - **Scrum Master**: [Codey] (TPM)
  - **Development Team**: [Syntax], [Aesthetica], [Flow], [Sentinal], [Verity]

### Key Ceremonies
- **Sprint Planning**: Start of each sprint
- **Daily Stand-up**: 15-min daily sync for [TechTeam]
- **Sprint Review**: Demo working software to [MarketingTeam]
- **Sprint Retrospective**: Process improvement discussion

### Kanban Integration
- **Marketing Team**: Kanban board for content/campaign workflow
- **Operational Work**: Separate board for bugs, security patches, infrastructure
- **Flow States**: Backlog → In Progress → Review → Done

## Team Member Role Designations
- [Syntax] : Principal Engineer
- [Codey] : Technical Program Manager (TPM)
- [Aesthetica] : Front-end Developer & UI/UX Designer
- [Sentinal] : Security Operations Specialist
- [Flow] : Dev Ops Engineer
- [Verity] : QA
- [Bran] : Digital Marketing Specialist
- [Cipher] : StoryBrand Expert
- [Echo] : Content Strategist

## Team Designations
- [Team] : [Syntax], [Codey], [Aesthetica], [Sentinal], [Flow], [Verity], [Bran], [Cipher], [Echo]
- [TechTeam] : [Syntax], [Codey], [Aesthetica], [Sentinal], [Flow], [Verity]
- [MarketingTeam] : [Codey], [Bran], [Cipher], [Echo]
- [DeploymentTeam] : [Flow], [Sentinel], [Syntax], [Verity]

## Development Practices

### Definition of Done
- Code reviewed and approved
- Automated tests passing
- Security review completed
- Deployed to staging environment
- Product Owner acceptance

### Quality & Security
- Shift-left testing: QA involved from requirements phase
- Security reviews integrated into sprint cycle
- Threat modeling for new features
- Automated security scanning in CI/CD

---

# Six Sigma Quality Framework

## Current Sigma Level
- **Baseline:** ~2.5σ (indicative, DPMO ~365,591)
- **Target:** ~3.5σ after improvements

## Quality Gates (CI/CD Pipeline)
| Gate | Tool | Threshold | Enforcement |
|------|------|-----------|-------------|
| PHPUnit tests | `php artisan test` | 100% pass | Block merge |
| PHP version compat | 8.2/8.3/8.4 matrix | All pass | Block merge |
| Composer audit | `composer audit --locked` | 0 high/critical | Block merge |
| Security scan | High-severity check | 0 findings | Block merge |
| Frontend build | `npm run build` | Success | Block merge |
| Bundle size | Manual check | < 500KB | Warn |

## Key Metrics (FMEA)
| Failure Mode | RPN | Status |
|-------------|-----|--------|
| No prod error tracking | 810 → 54 | ✅ Sentry installed |
| No security in CI | 280 → 14 | ✅ Added to pipeline |
| No performance SLO | 270 → 36 | ✅ Monitoring added |
| No a11y testing | 270 → 24 | ✅ Playwright tests added |

## Monitoring
- **Sentry:** Production error tracking (set `SENTRY_LARAVEL_DSN` in prod)
- **Performance:** `PerformanceMonitoring` middleware tracks response times
- **Health Check:** `/health` endpoint checks DB, queue, cache status
- **Slow Requests:** Logged when > 3000ms response time

---

# Code Quality Guardrails (Anti-Vibe-Coding Rules)

## Styling Consistency
- NEVER switch styling approaches mid-project. If the project uses Tailwind, USE Tailwind.
- NEVER use inline styles (`style={{}}`) when a utility-first framework is in use.
- NEVER use JavaScript to simulate CSS pseudo-classes (:hover, :focus, :active).

## No Hack Workarounds
- If you hit a limitation, DO NOT invent a JS workaround. Use the correct tool.
- Inline event handlers for styling = code smell. Always prefer declarative styling.

## Framework Discipline
- Before writing ANY component, check 3 existing components to match patterns.
- Do not introduce new dependencies without explicitly stating WHY.
- Maintain consistent patterns across ALL files.

## Self-Check Before Committing
1. No inline `style={{}}` objects
2. No JS-based hover/focus/active handlers replacing CSS
3. Styling approach matches the rest of the codebase
4. No mixed styling paradigms
5. Code is maintainable

---

# Telegram Integration — Report & Screenshot Delivery

## Credentials
- Bot token: `${TELEGRAM_BOT_TOKEN}`
- Chat ID: `${TELEGRAM_CHAT_ID}`

## Usage
```bash
BOT="${TELEGRAM_BOT_TOKEN}"
CHAT="${TELEGRAM_CHAT_ID}"

# Send text message
curl -s -X POST "https://api.telegram.org/bot${BOT}/sendMessage" \
  --data-urlencode "chat_id=${CHAT}" \
  --data-urlencode "parse_mode=Markdown" \
  --data-urlencode "text=*Bold title* and body text"

# Send screenshot/image
curl -s -X POST "https://api.telegram.org/bot${BOT}/sendPhoto" \
  -F "chat_id=${CHAT}" \
  -F "photo=@path/to/screenshot.png" \
  -F "caption=Description of image"
```

## Rules
- Always use `--data-urlencode` for text (not `-d`)
- Verify each send succeeded by checking `"ok":true` in the response

---

# D: Drive Installation Rule

## Rule
**ALL new software, packages, and tools MUST be installed to D: drive, NOT C: drive.**

## Applies To
- npm global packages
- Python packages (pip, uv)
- Docker images and volumes
- WSL distributions
- Development tools
- IDE extensions
- Any other software

## Implementation

### npm
```bash
npm config set prefix "D:\npm-global"
export PATH="$PATH:/mnt/d/npm-global"
```

### Python (pip)
```bash
pip config set global.target "D:\python-packages"
```

### uv
```bash
export UV_CACHE_DIR="D:\Cache\uv"
```

### Docker
- Docker data: `D:\Docker`
- Docker images: `D:\Docker\images`

### WSL
- WSL distributions: `D:\WSL`
- WSL memory: 10GB (configured in .wslconfig)

## Benefits
- Keeps C: drive free for Windows system files
- Prevents C: drive from filling up
- Easier to manage and backup
- Better performance on D: drive (if SSD)

## Monitoring
- Check C: drive space regularly
- Alert if C: drive free space < 50GB

## Local Qwen3 session
- Gateway: `http://127.0.0.1:8787`
- Model: `qwen3:14b-q4_K_M`
- Windows launcher: `powershell -ExecutionPolicy Bypass -File C:/Users/VJ_Rodriguguez/.claude/local-qwen3.ps1`
- WSL launcher: `bash /mnt/c/Users/VJ_Rodriguguez/.claude/local-qwen3.sh`
- The launchers set `ANTHROPIC_BASE_URL` only for that Claude Code process; normal cloud sessions remain unchanged.
- Gateway status: `GET /status`; context compaction: `POST /v1/compact`.
