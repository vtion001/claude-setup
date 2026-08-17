---
name: security-audit
description: >
  AI-powered cybersecurity auditor using Burp Suite MCP, Playwright, and source code
  analysis. Runs 15 modular audit passes mapping to OWASP Top 10 (2025), OWASP API
  Security Top 10, and WSTG v4.2 covering reconnaissance, security headers, authentication,
  authorization, injection, XSS, CSRF, cryptography, API security, file upload/SSRF,
  business logic, supply chain, error handling, rate limiting/DoS, and compliance.
  Uses three-tier system: Tier 0 (static analysis via Opsera + Grep), Tier 1 (Burp Suite
  MCP + Playwright), Tier 2 (AI judgment). Supports --passive, --quick, --code-only,
  --pass, --authorize, --rate, and --pages flags. This skill should be used when the
  user asks to "security audit", "pentest", "vulnerability scan", "is it secure",
  "check for vulnerabilities", "OWASP audit", "security test", "hack test",
  "penetration test", "cybersecurity audit", "check API security", "rate limit test",
  "check for SQL injection", "test XSS", "security review".
---

# Security Audit — AI-Powered Cybersecurity Testing

Test whether a web application is secure. Not "does it look good?" (that's `/ux-audit`) or "is it built right?" (that's `/ui-audit`) but "can it be hacked?" — SQL injection, XSS, auth bypass, API abuse, and 100+ vulnerability classes.

## Prerequisites

The following MCP tools must be available:
- **Burp Suite MCP** (`proxy`, `scanner`, `intruder`, `repeater`, `sequencer`, `collaborator`, `DOM Invader`, `clickbandit`) — primary active/passive scanning engine
- **Playwright MCP** (`browser_navigate`, `browser_snapshot`, `browser_take_screenshot`, `browser_evaluate`, `browser_click`) — browser automation for authenticated crawling and payload delivery
- **Opsera DevSecOps plugin** (optional) — enhanced Tier 0 static analysis via `opsera-devsecops:security-scan`
- **Linear MCP** (optional) — auto-filing security debt issues with `["Security Debt"]` label
- A running application accessible at a URL
- Access to source code (for Tier 0 static analysis)

### Burp Suite MCP — connection setup

Burp's MCP server (Burp → Settings → Extensions → MCP) exposes an **SSE** endpoint. Configure it in the project's `.mcp.json`:

```json
{ "mcpServers": { "burp": { "type": "sse", "url": "http://127.0.0.1:9876" } } }
```

- **URL is the root path, not `/sse`.** Burp serves the SSE handshake at `/` (a GET returns `event: endpoint` + a `sessionId`). Pointing at `/sse` returns `404` and the `burp` tools silently fail to load.
- **MCP servers load only at Claude Code startup** — after editing `.mcp.json`, restart the session before the `burp` tools appear. Mid-session edits do not hot-reload.
- **WSL → Windows host:** if Burp runs on Windows and Claude Code in WSL, enable mirrored networking (`~/.wslconfig` → `[wsl2]` / `networkingMode=mirrored`) and `wsl --shutdown`, so `127.0.0.1:9876` reaches the Windows-side server. Default NAT mode cannot.
- **Pre-flight (before active scanning):** `curl -s --max-time 5 http://127.0.0.1:9876/ | head -3` — `event: endpoint` = ready; `404` = wrong path (not root); `000`/refused = unreachable (networking or Burp down).

Full procedure and fallbacks: `scripts/burp-workflows.md` → Workflow 0.

## Invocation

```
/security-audit                                          → Full 15-pass, all three tiers, passive scanning
/security-audit --passive                                → Passive scanning only (no attack payloads sent)
/security-audit --quick                                  → Tier 0 + Tier 1 passive only (fast, safe)
/security-audit --code-only                              → Tier 0 only (no browser or Burp needed)
/security-audit --pass auth,injection,xss                → Cherry-pick specific passes
/security-audit --authorize staging                      → Authorize active scanning on staging
/security-audit --authorize production --domain x.com    → Authorize production (requires domain confirmation)
/security-audit --rate 10                                → Set max requests/second (default varies by target)
/security-audit --pages /api/users,/login,/dashboard     → Audit specific endpoints only
```

All flags are combinable. Defaults: full 15-pass, all three tiers, passive scanning, localhost authorized.

## Pass Names (for --pass flag)

`recon`, `headers`, `auth`, `authz`, `injection`, `xss`, `csrf`, `crypto`, `api`, `upload`, `logic`, `supply-chain`, `errors`, `rate-limit`, `compliance`

## Three-Tier System

Each pass executes up to three tiers of analysis:

| Tier | What It Does | Tools |
|------|-------------|-------|
| **Tier 0: Static Analysis** | Source code scanning — secrets, hardcoded credentials, insecure patterns, dependency versions, configuration review | `Read`, `Grep`, `Glob`, `opsera-devsecops:security-scan` |
| **Tier 1: Automated Scanning** | Burp Suite MCP passive + active scanning, Playwright browser automation, traffic interception | Burp MCP (proxy, scanner, intruder, repeater, sequencer), Playwright MCP |
| **Tier 2: AI Judgment** | Contextual reasoning on scan results, false positive filtering, risk assessment, business logic analysis | Claude analysis of Tier 0 + Tier 1 results |

## Workflow

### Phase 0: Configuration

Auto-detect from codebase and environment. Prompt only for values that cannot be resolved:

| Input | Default | Notes |
|-------|---------|-------|
| `APP_URL` | `http://localhost:3000` | Base URL of the running app |
| `FRAMEWORK` | auto-detect | Next.js, Express, Django, Laravel, etc. |
| `AUTH_METHOD` | auto-detect | JWT, session cookies, OAuth, API keys |
| `API_TYPE` | auto-detect | REST, GraphQL, gRPC, WebSocket |
| `AUTH_REQUIRED` | auto-detect | Whether login is needed for scanning |
| `LOGIN_EMAIL` | auto-detect from seeders/env | Dev credentials |
| `LOGIN_PASSWORD` | auto-detect from seeders/env | Dev credentials |
| `LINEAR_PROJECT` | auto-detect from context | For auto-filing |
| `TARGET_TYPE` | auto-detect from URL | localhost / staging / production |
| `SCAN_RATE` | varies by target type | Requests per second cap |
| `REPORT_DIR` | `./security-audit/` | Where to save reports and evidence |

### Phase 1: Authorization Verification

**CRITICAL — This phase cannot be skipped.**

1. Determine target type from `APP_URL`:
   - `localhost` / `127.0.0.1` / `0.0.0.0` → **localhost** (auto-authorized)
   - Contains `staging`, `dev`, `test`, `sandbox` → **staging** (requires `--authorize staging`)
   - All other domains → **production** (requires `--authorize production --domain {domain}`)
   - Third-party domains not owned by user → **BLOCKED** (never test)

2. For non-localhost targets, display authorization warning:
   ```
   WARNING: You are about to scan a non-localhost target.
   Target: {APP_URL}
   Type: {staging|production}
   Active scanning: {enabled|disabled}

   Active scanning sends attack payloads (SQLi, XSS, etc.) to the target.
   You MUST have explicit written authorization to test this target.

   Confirm authorization? [y/N]
   ```

3. Wait for explicit user confirmation before proceeding.

4. For production targets with active scanning requested, require DOUBLE confirmation:
   ```
   PRODUCTION ACTIVE SCAN — ELEVATED RISK
   Domain: {domain}
   This will send attack payloads to a production system.
   Rate limit: {rate} req/sec

   Type the domain name to confirm: ___
   ```

5. Log authorization decision with timestamp for audit trail.

### Phase 2: Static Analysis (Tier 0)

Before any network activity, run Tier 0 across all selected passes.

**Primary: Opsera DevSecOps** (if available)
- Run `opsera-devsecops:security-scan` for comprehensive SAST
- Covers secrets detection, dependency vulnerabilities, code patterns

**Fallback: Built-in Analysis** (always runs as supplement)
- `Grep` for hardcoded secrets, API keys, passwords in source
- `Grep` for insecure patterns (`eval()`, `innerHTML`, `dangerouslySetInnerHTML`, `exec()`, raw SQL)
- `Glob` for sensitive files (`.env`, `credentials.json`, `*.pem`, `*.key`)
- `Read` package manifests for dependency versions and known CVEs
- `Read` configuration files for security settings

If `--code-only` flag is set, stop here and generate report from Tier 0 findings only.

### Phase 3: Route Discovery

Extract all testable endpoints from the application:

**Source-based discovery:**
- Read route definition files (Express routes, Next.js app/, Django urls.py, etc.)
- Parse OpenAPI/Swagger specs if present
- Extract API endpoints from source code

**Network-based discovery:**
- Burp sitemap crawl via proxy
- Fetch and parse `robots.txt`, `sitemap.xml`
- Check common paths: `/admin`, `/api/docs`, `/swagger`, `/.env`, `/.git`, `/graphql`

Organize endpoints into groups:
- Public endpoints (no auth)
- Authenticated endpoints (require login)
- Admin endpoints (elevated roles)
- API endpoints (REST/GraphQL/WebSocket)

If `--pages` flag is set, use only the specified endpoints.

### Phase 4: Authentication

If auth is required for scanning:
1. Navigate to login page via Playwright
2. Capture login page for security analysis (form action, CSRF token, password field attributes)
3. Fill credentials and submit
4. Capture authentication tokens/cookies via Burp proxy
5. Verify login succeeded
6. Configure Burp session handling with captured tokens
7. If login fails, report error and stop

### Phase 5: Passive Scanning

All traffic from Playwright browser automation flows through Burp proxy. No attack payloads are sent.

For each discovered endpoint:
1. Navigate via Playwright → Burp intercepts traffic
2. Burp passive scanner analyzes responses for:
   - Missing security headers
   - Cookie flag issues
   - Information disclosure
   - Insecure content loading
   - Cacheable sensitive responses
3. Collect all passive findings
4. Cross-reference with Tier 0 results

If `--passive` flag is set, stop here (skip Phase 6).

### Phase 6: Active Scanning

**Requires authorization for the target type.** Each pass executes its active checks.

Before starting active scans:
1. Display confirmation prompt with target, rate limit, and passes to run
2. Wait for user confirmation
3. Apply rate limiting per target type (see `references/safety-guardrails.md`)
4. Log all requests sent

For each selected pass:
1. Read the pass reference file from `references/passes/{pass}.md`
2. Execute Tier 1 active checks using Burp MCP tools (scanner, intruder, repeater)
3. Apply Tier 2 AI judgment to filter false positives and assess real risk
4. Score each pass using `references/scoring-rubric.md`
5. Cross-reference findings with source code for file:line attribution

Read `scripts/burp-workflows.md` for reusable Burp MCP command sequences.

### Phase 7: Report Generation

Read `references/report-template.md` for the full template.

Generate:
- `security-audit/security-audit-report.md` — Full narrative report with OWASP mapping
- `security-audit/security-audit-scorecard.md` — Quick-reference scorecard
- `security-audit/evidence/` — Screenshots, request/response logs, PoC artifacts

**Calculate Security Score (SS):**
Read `references/scoring-rubric.md` for weights and formula.

**OWASP Coverage Matrix:**
Read `references/owasp-mapping.md` for mapping each finding to OWASP Top 10, API Top 10, and WSTG test IDs.

**Linear integration (if available):**
- File issues with label `["Security Debt"]`
- Group by vulnerability class (one issue per class, not per instance)
- Include severity, OWASP ID, CWE ID, evidence, reproduction steps, remediation
- Priority mapped from severity: Critical → P1, High → P2, Medium → P3, Low → P4

### Phase 8: Cleanup

After the audit is complete:
1. Remove any test data created during scanning (test accounts, uploaded files, injected records)
2. Clear Burp proxy state and session tokens
3. Log audit completion with timestamp
4. Generate audit trail summary (total requests sent, endpoints tested, time elapsed)
5. Verify no persistent artifacts remain on the target

## Safety Rules (CRITICAL)

These rules are enforced in every pass, every phase, every scan. Violations are hard failures.

1. **NEVER send destructive payloads** — No `DROP TABLE`, `DELETE *`, `rm -rf`, `format`, `shutdown`, or any payload that modifies/destroys data. See `references/safety-guardrails.md` for the full blocklist.
2. **NEVER exfiltrate real user data** — Use test accounts and synthetic data only. Never copy, store, or transmit actual user PII.
3. **NEVER exceed rate limits** — Respect the configured rate cap. Honor `429` responses with exponential backoff.
4. **NEVER test unauthorized targets** — Verify scope and authorization before every active scan. Third-party targets are ALWAYS blocked.
5. **NEVER store credentials in reports** — Redact all secrets, tokens, passwords, API keys from output. Use `[REDACTED]` placeholders.
6. **NEVER modify production data** — Read-only operations on production systems. No writes, updates, or deletes.
7. **ALWAYS log all scan actions** — Full audit trail of every request sent: timestamp, target, method, path, response code.
8. **ALWAYS clean up** — Remove test data, accounts, and artifacts after audit completes.
9. **ALWAYS verify target** — Confirm URL resolves to expected host before scanning. DNS rebinding protection.
10. **ALWAYS respect robots.txt** — Unless explicitly overridden with `--ignore-robots` flag.

## Reference Files

- **`references/safety-guardrails.md`** — Authorization levels, rate limits, destructive payload blocklist, confirmation prompts, cleanup checklist
- **`references/scoring-rubric.md`** — Security Score weights, formula, severity mapping, score ranges
- **`references/report-template.md`** — Full report template, scorecard, OWASP coverage matrix, Linear issue format
- **`references/owasp-mapping.md`** — OWASP Top 10 (2025), API Security Top 10 (2023), WSTG v4.2 cross-reference
- **`references/passes/01-reconnaissance.md`** through **`15-compliance-logging.md`** — Individual pass definitions
- **`scripts/burp-workflows.md`** — Burp MCP connection setup/pre-flight (Workflow 0) + reusable command sequences for 12 attack workflow types
