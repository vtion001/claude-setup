# Security Audit — Scoring Rubric

## Per-Pass Scoring Scale (1-5)

| Score | Label | Meaning |
|-------|-------|---------|
| **5** | Hardened | No vulnerabilities found. Security controls exceed requirements. Defense-in-depth present. |
| **4** | Good | Minor issues only (informational/low). Core security controls properly implemented. |
| **3** | Acceptable | Some medium-severity issues. Security controls present but incomplete or misconfigured. |
| **2** | Vulnerable | High-severity issues found. Missing or bypassable security controls. Exploitation possible. |
| **1** | Critical | Critical-severity issues. Active exploitation trivial. Immediate remediation required. |

## Security Score (SS) Weights

| # | Pass | Weight | Weight Units | Rationale |
|---|------|--------|-------------|-----------|
| 01 | Reconnaissance | 1x | 1 | Foundation — not a vulnerability itself |
| 02 | Headers & Config | 2x | 2 | Easy wins, broad impact on attack surface |
| 03 | Authentication | 3x | 3 | Critical — identity compromise enables everything |
| 04 | Authorization | 3x | 3 | Critical — data breach, privilege escalation |
| 05 | Injection | 3x | 3 | Critical — code execution, data theft |
| 06 | XSS & Client-side | 2x | 2 | High — user session compromise |
| 07 | CSRF & Clickjacking | 2x | 2 | Medium — action hijacking |
| 08 | Cryptography | 1x | 1 | Data protection at rest and in transit |
| 09 | API Security | 2x | 2 | High — growing attack surface |
| 10 | File Upload & SSRF | 1x | 1 | Medium — server-side compromise vector |
| 11 | Business Logic | 1x | 1 | Medium — context-dependent |
| 12 | Supply Chain | 2x | 2 | High — transitive risk, hard to detect |
| 13 | Error Handling | 1x | 1 | Low — information disclosure |
| 14 | Rate Limiting | 1x | 1 | Low — availability |
| 15 | Compliance & Logging | 1x | 1 | Compliance alignment, audit readiness |

### Weight Summary

| Weight | Passes | Count | Units |
|--------|--------|-------|-------|
| 3x | Auth, Authz, Injection | 3 | 9 |
| 2x | Config, XSS, CSRF, API, Supply Chain | 5 | 10 |
| 1x | Recon, Crypto, Upload, Logic, Errors, Rate Limit, Compliance | 7 | 7 |
| **Total** | | **15** | **26** |

## Formula

```
SS = (SUM of pass_score * weight) / (SUM of max_score * weight) * 100
   = (SUM of pass_score * weight) / (5 * 26) * 100
   = (SUM of pass_score * weight) / 130 * 100
```

**Example calculation:**
- Auth (3x) scores 4 → 4 * 3 = 12
- Authz (3x) scores 3 → 3 * 3 = 9
- Injection (3x) scores 5 → 5 * 3 = 15
- Config (2x) scores 4 → 4 * 2 = 8
- XSS (2x) scores 4 → 4 * 2 = 8
- CSRF (2x) scores 5 → 5 * 2 = 10
- API (2x) scores 3 → 3 * 2 = 6
- Supply Chain (2x) scores 4 → 4 * 2 = 8
- Recon (1x) scores 5 → 5 * 1 = 5
- Crypto (1x) scores 4 → 4 * 1 = 4
- Upload (1x) scores 5 → 5 * 1 = 5
- Logic (1x) scores 4 → 4 * 1 = 4
- Errors (1x) scores 3 → 3 * 1 = 3
- Rate Limit (1x) scores 4 → 4 * 1 = 4
- Compliance (1x) scores 3 → 3 * 1 = 3

Total weighted = 104 / 130 * 100 = **80/100 — Production-ready**

## Score Ranges

| Range | Grade | Label | Meaning |
|-------|-------|-------|---------|
| 90-100 | A+ / A | Hardened | Defense-in-depth. Ready for hostile environments. Exceeds compliance requirements. |
| 75-89 | B+ / B | Production-ready | Solid security posture. Minor improvements recommended. Meets compliance baselines. |
| 60-74 | C+ / C | Needs attention | Notable gaps. Should not go to production without addressing high-severity findings. |
| 40-59 | D+ / D | Vulnerable | Significant vulnerabilities. Active exploitation likely. Immediate sprint required. |
| 0-39 | F | Critical risk | Fundamental security failures. Application should not be exposed to any network. |

## Finding Severity Mapping

| Severity | Impact | Examples | Per-Finding Score | Linear Priority |
|----------|--------|----------|------------------|-----------------|
| **Critical** | Remote code execution, full data breach, authentication bypass | SQLi with data access, RCE via deserialization, auth bypass via JWT `alg:none`, admin panel without auth | 0/10 | P1 — Urgent |
| **High** | Significant data exposure, session hijacking, privilege escalation | Stored XSS, SSRF to internal services, vertical privilege escalation, CSRF on state-changing actions | 2/10 | P2 — High |
| **Medium** | Limited data exposure, defense weakening | Missing security headers, weak CORS policy, verbose error messages, missing CSRF on non-critical forms | 5/10 | P3 — Medium |
| **Low** | Minimal direct impact, best practice violations | Verbose server headers, cookie without Secure flag on localhost, missing X-Content-Type-Options | 7/10 | P4 — Low |
| **Info** | Recommendations and hardening suggestions | SRI missing on non-critical CDN resources, HSTS preload not configured, additional CSP directives | 9/10 | No issue filed |
| **Pass** | No issues found | Clean scan, all controls verified | 10/10 | No issue filed |

## CVSS v3.1 Estimate Guide

For each finding, estimate a CVSS v3.1 base score:

| CVSS Range | Severity | Example Vector |
|------------|----------|----------------|
| 9.0-10.0 | Critical | `AV:N/AC:L/PR:N/UI:N/S:C/C:H/I:H/A:H` — Network, Low complexity, No privileges, No interaction |
| 7.0-8.9 | High | `AV:N/AC:L/PR:L/UI:R/S:C/C:H/I:L/A:N` — Requires auth or user interaction |
| 4.0-6.9 | Medium | `AV:N/AC:H/PR:L/UI:R/S:U/C:L/I:L/A:N` — High complexity or limited impact |
| 0.1-3.9 | Low | `AV:N/AC:H/PR:H/UI:R/S:U/C:L/I:N/A:N` — Requires admin + user interaction |

## Pass Score Aggregation

When a pass has multiple findings of different severities, the pass score is determined by the **worst finding**:

- Any Critical finding → Pass scores 1
- Any High finding (no Criticals) → Pass scores 2
- Any Medium finding (no High/Critical) → Pass scores 3
- Only Low/Info findings → Pass scores 4
- No findings → Pass scores 5

If a pass has findings but also strong compensating controls, AI judgment (Tier 2) may adjust the score up by 1 point maximum, with documented justification.
