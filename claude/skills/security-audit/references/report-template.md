# Security Audit — Report Template

## Full Report: `security-audit/security-audit-report.md`

```markdown
# Security Audit Report — {Project Name}

**Date:** {date}
**URL:** {app_url}
**Framework:** {framework}
**Auth Method:** {jwt|session|oauth|api-key}
**API Type:** {rest|graphql|websocket|mixed}
**Target Type:** {localhost|staging|production}
**Scan Mode:** {passive|active|code-only}
**Passes Run:** {passes}
**Rate Limit:** {N} req/sec
**Duration:** {minutes}

---

## Executive Summary

{AI-generated narrative: 3-5 sentences summarizing the security posture. Focus on systemic patterns,
not individual symptoms. Identify the most impactful vulnerability classes and their root causes.}

**Security Score: {score}/100 — {grade} ({label})**

### OWASP Coverage

| Standard | Items Tested | Items Passed | Coverage |
|----------|-------------|-------------|----------|
| OWASP Top 10 (2025) | {N}/10 | {N}/10 | {percentage}% |
| OWASP API Top 10 (2023) | {N}/10 | {N}/10 | {percentage}% |
| WSTG v4.2 Categories | {N}/12 | {N}/12 | {percentage}% |

### Top 3 Critical Findings

1. **{vulnerability}** — {OWASP ID} — {one-line impact description}
2. **{vulnerability}** — {OWASP ID} — {one-line impact description}
3. **{vulnerability}** — {OWASP ID} — {one-line impact description}

### Estimated Remediation Effort: {sprint estimate}

---

## Security Scorecard

### Overall SS: {score}/100 — {grade}

| # | Pass | Score | Weight | Weighted | Key Finding |
|---|------|-------|--------|----------|-------------|
| 01 | Reconnaissance | {1-5} | 1x | {weighted} | {one-line finding} |
| 02 | Headers & Config | {1-5} | 2x | {weighted} | {one-line finding} |
| 03 | Authentication | {1-5} | 3x | {weighted} | {one-line finding} |
| 04 | Authorization | {1-5} | 3x | {weighted} | {one-line finding} |
| 05 | Injection | {1-5} | 3x | {weighted} | {one-line finding} |
| 06 | XSS & Client-side | {1-5} | 2x | {weighted} | {one-line finding} |
| 07 | CSRF & Clickjacking | {1-5} | 2x | {weighted} | {one-line finding} |
| 08 | Cryptography | {1-5} | 1x | {weighted} | {one-line finding} |
| 09 | API Security | {1-5} | 2x | {weighted} | {one-line finding} |
| 10 | File Upload & SSRF | {1-5} | 1x | {weighted} | {one-line finding} |
| 11 | Business Logic | {1-5} | 1x | {weighted} | {one-line finding} |
| 12 | Supply Chain | {1-5} | 2x | {weighted} | {one-line finding} |
| 13 | Error Handling | {1-5} | 1x | {weighted} | {one-line finding} |
| 14 | Rate Limiting | {1-5} | 1x | {weighted} | {one-line finding} |
| 15 | Compliance & Logging | {1-5} | 1x | {weighted} | {one-line finding} |

---

## OWASP Coverage Matrix

### OWASP Top 10 (2025)

| Rank | Code | Name | Tested | Result | Findings | Pass |
|------|------|------|--------|--------|----------|------|
| 1 | A01:2025 | Broken Access Control | {Y/N} | {Pass/Fail} | {count} | 04-Authorization |
| 2 | A02:2025 | Security Misconfiguration | {Y/N} | {Pass/Fail} | {count} | 02-Headers |
| 3 | A03:2025 | Software Supply Chain Failures | {Y/N} | {Pass/Fail} | {count} | 12-Supply Chain |
| 4 | A04:2025 | Cryptographic Failures | {Y/N} | {Pass/Fail} | {count} | 08-Crypto |
| 5 | A05:2025 | Injection | {Y/N} | {Pass/Fail} | {count} | 05-Injection, 06-XSS |
| 6 | A06:2025 | Insecure Design | {Y/N} | {Pass/Fail} | {count} | 11-Business Logic |
| 7 | A07:2025 | Authentication Failures | {Y/N} | {Pass/Fail} | {count} | 03-Auth |
| 8 | A08:2025 | Software/Data Integrity Failures | {Y/N} | {Pass/Fail} | {count} | 12-Supply Chain |
| 9 | A09:2025 | Security Logging & Alerting Failures | {Y/N} | {Pass/Fail} | {count} | 15-Compliance |
| 10 | A10:2025 | Mishandling of Exceptional Conditions | {Y/N} | {Pass/Fail} | {count} | 13-Errors |

### OWASP API Security Top 10 (2023)

| Code | Name | Tested | Result | Findings | Pass |
|------|------|--------|--------|----------|------|
| API1:2023 | Broken Object Level Authorization | {Y/N} | {Pass/Fail} | {count} | 04, 09 |
| API2:2023 | Broken Authentication | {Y/N} | {Pass/Fail} | {count} | 03 |
| API3:2023 | Broken Object Property Level Authorization | {Y/N} | {Pass/Fail} | {count} | 04, 09 |
| API4:2023 | Unrestricted Resource Consumption | {Y/N} | {Pass/Fail} | {count} | 14 |
| API5:2023 | Broken Function Level Authorization | {Y/N} | {Pass/Fail} | {count} | 04 |
| API6:2023 | Unrestricted Access to Sensitive Business Flows | {Y/N} | {Pass/Fail} | {count} | 11, 14 |
| API7:2023 | Server Side Request Forgery | {Y/N} | {Pass/Fail} | {count} | 10 |
| API8:2023 | Security Misconfiguration | {Y/N} | {Pass/Fail} | {count} | 02, 09 |
| API9:2023 | Improper Inventory Management | {Y/N} | {Pass/Fail} | {count} | 01, 09 |
| API10:2023 | Unsafe Consumption of APIs | {Y/N} | {Pass/Fail} | {count} | 12 |

---

## Findings by Severity

### Critical

> Findings that enable remote code execution, full data breach, or complete authentication bypass.

#### {Finding title}

| Field | Value |
|-------|-------|
| **Severity** | Critical |
| **Pass** | {pass name} |
| **OWASP ID** | {A01:2025 / API1:2023 / etc.} |
| **CWE ID** | {CWE-XXX} |
| **CVSS Estimate** | {score} — `{vector string}` |
| **Endpoint** | `{method} {path}` |
| **What** | {description of the vulnerability} |
| **Evidence** | {request/response excerpt or code snippet demonstrating the issue} |
| **Reproduction Steps** | 1. {step} 2. {step} 3. {step} |
| **Impact** | {what an attacker could achieve} |
| **Root Cause** | `{file}:{line}` — {explanation} |
| **Remediation** | {specific code change or configuration fix} |
| **References** | {OWASP link, CWE link, relevant advisory} |

{Repeat for each critical finding}

### High

{Same format as Critical}

### Medium

{Same format as Critical}

### Low

{Same format as Critical — CVSS estimate optional for Low}

### Informational

> Recommendations and hardening suggestions. Not vulnerabilities but defense-in-depth improvements.

- {recommendation 1}
- {recommendation 2}
- {recommendation 3}

---

## Attack Surface Summary

| Dimension | Count | Notes |
|-----------|-------|-------|
| Total endpoints discovered | {N} | {breakdown by type} |
| Endpoints requiring auth | {N} | {percentage}% |
| API endpoints | {N} | {REST/GraphQL/WebSocket} |
| Form inputs | {N} | {count with validation} |
| File upload points | {N} | {types accepted} |
| WebSocket connections | {N} | {origin validated?} |
| External dependencies | {N} | {CDN scripts, APIs} |
| Admin interfaces | {N} | {protected?} |

---

## Compliance Status

### SOC 2 Overlap

| Criteria | Description | Status | Evidence |
|----------|-------------|--------|----------|
| CC6.1 | Logical access controls | {Pass/Fail/Partial} | {finding references} |
| CC6.6 | Encryption in transit | {Pass/Fail/Partial} | {finding references} |
| CC6.7 | Data integrity controls | {Pass/Fail/Partial} | {finding references} |
| CC7.1 | Monitoring and detection | {Pass/Fail/Partial} | {finding references} |
| CC8.1 | Change management | {Pass/Fail/Partial} | {finding references} |

### HIPAA Technical Safeguards (if applicable)

| Requirement | Description | Status | Evidence |
|-------------|-------------|--------|----------|
| 164.312(a) | Access controls | {Pass/Fail/Partial} | {finding references} |
| 164.312(b) | Audit controls | {Pass/Fail/Partial} | {finding references} |
| 164.312(c) | Integrity controls | {Pass/Fail/Partial} | {finding references} |
| 164.312(d) | Authentication | {Pass/Fail/Partial} | {finding references} |
| 164.312(e) | Transmission security | {Pass/Fail/Partial} | {finding references} |

### PCI-DSS v4.0 (if applicable)

| Requirement | Description | Status | Evidence |
|-------------|-------------|--------|----------|
| Req 2 | Secure configurations | {Pass/Fail/Partial} | {finding references} |
| Req 4 | Encrypt transmission | {Pass/Fail/Partial} | {finding references} |
| Req 6 | Secure development | {Pass/Fail/Partial} | {finding references} |
| Req 8 | Authentication | {Pass/Fail/Partial} | {finding references} |
| Req 10 | Logging & monitoring | {Pass/Fail/Partial} | {finding references} |
| Req 11 | Regular testing | {Pass/Fail/Partial} | {finding references} |

---

## Recommendations by Impact

| Rank | Finding/Theme | Impact | Effort | Severity | Action |
|------|---------------|--------|--------|----------|--------|
| 1 | {finding} | {Critical/High} | {hours} | {Critical} | {specific remediation} |
| 2 | {finding} | {Critical/High} | {hours} | {High} | {specific remediation} |
| 3 | {finding} | {High/Medium} | {hours} | {Medium} | {specific remediation} |

### Quick Wins (< 1 hour each)
- {easy fix 1}
- {easy fix 2}
- {easy fix 3}

### Sprint-Level Fixes (1-3 days)
- {medium fix 1}
- {medium fix 2}

### Architectural Changes (1+ sprints)
- {large fix 1}
- {large fix 2}

---

## What Is Secure

> Positive findings — controls that are properly implemented. Preserve these.

- {positive finding 1 — what is good and why}
- {positive finding 2}
- {positive finding 3}

---

## Audit Trail Summary

| Metric | Value |
|--------|-------|
| Scan start | {timestamp} |
| Scan end | {timestamp} |
| Duration | {minutes} |
| Total requests sent | {N} |
| Endpoints tested | {N} |
| Active payloads sent | {N} |
| Rate limit hits (429) | {N} |
| Errors encountered | {N} |
| Authorization level | {localhost/staging/production} |
| Cleanup verified | {Yes/No} |

Full audit trail: `security-audit/audit-trail.jsonl`

---

## Appendix

### A. Tier 0 Static Analysis Summary
{Key findings from source code analysis — secrets, patterns, dependency issues}

### B. Burp Scanner Results
{Raw Burp finding IDs and confidence levels}

### C. Request/Response Evidence
{Sanitized request/response pairs for key findings — all secrets REDACTED}

### D. Dependency Vulnerability List
{npm audit / pip-audit / bundler-audit output}

### E. Security Header Analysis
{Full header comparison table — expected vs actual for all endpoints}
```

---

## Quick Scorecard: `security-audit/security-audit-scorecard.md`

```markdown
# Security Audit Scorecard — {Project Name}

**SS: {score}/100 — {grade}** | **Date:** {date} | **Mode:** {passive|active|code-only}

## Pass Scores

| Pass | Score | Visual |
|------|-------|--------|
| Reconnaissance (1x) | {score}/5 | {bar_visual} |
| Headers & Config (2x) | {score}/5 | {bar_visual} |
| Authentication (3x) | {score}/5 | {bar_visual} |
| Authorization (3x) | {score}/5 | {bar_visual} |
| Injection (3x) | {score}/5 | {bar_visual} |
| XSS & Client-side (2x) | {score}/5 | {bar_visual} |
| CSRF & Clickjacking (2x) | {score}/5 | {bar_visual} |
| Cryptography (1x) | {score}/5 | {bar_visual} |
| API Security (2x) | {score}/5 | {bar_visual} |
| File Upload & SSRF (1x) | {score}/5 | {bar_visual} |
| Business Logic (1x) | {score}/5 | {bar_visual} |
| Supply Chain (2x) | {score}/5 | {bar_visual} |
| Error Handling (1x) | {score}/5 | {bar_visual} |
| Rate Limiting (1x) | {score}/5 | {bar_visual} |
| Compliance & Logging (1x) | {score}/5 | {bar_visual} |

## Top 3 Vulnerabilities
1. [{severity}] {vulnerability} — {OWASP ID}
2. [{severity}] {vulnerability} — {OWASP ID}
3. [{severity}] {vulnerability} — {OWASP ID}

## Top 3 Strengths
1. {positive finding}
2. {positive finding}
3. {positive finding}

## Finding Summary
| Severity | Count |
|----------|-------|
| Critical | {N} |
| High | {N} |
| Medium | {N} |
| Low | {N} |
| Info | {N} |
| **Total** | **{N}** |

## Quick Wins (< 1 hour each)
- {easy fix}
- {easy fix}
- {easy fix}

## Next Steps
- [ ] {action item 1 — addresses highest severity finding}
- [ ] {action item 2}
- [ ] {action item 3}
```

---

## Linear Issue Template

When filing security findings to Linear with `["Security Debt"]` label:

```markdown
## [{Severity}] {Vulnerability Title} — {OWASP ID}

**CWE:** {CWE-XXX}
**CVSS:** {score}
**Endpoint:** `{method} {path}`
**File:** `{file}:{line}`

### Description
{2-3 sentences describing the vulnerability and its impact}

### Evidence
{Sanitized request/response or code snippet — NO real credentials}

### Reproduction Steps
1. {step}
2. {step}
3. {step}

### Remediation
{Specific code change or configuration fix with example}

### References
- {OWASP link}
- {CWE link}
- {Framework-specific security guide link}

---
*Filed by /security-audit — {date}*
```
