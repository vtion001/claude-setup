# Security Audit — OWASP Mapping Reference

## OWASP Top 10 (2025)

| Rank | Code | Name | Key Concerns |
|------|------|------|-------------|
| 1 | A01:2025 | Broken Access Control | IDOR, privilege escalation, CORS misconfig, missing function-level controls, URL/parameter tampering, JWT manipulation. 40 mapped CWEs. |
| 2 | A02:2025 | Security Misconfiguration | Missing hardening, default creds, verbose errors, unnecessary features enabled, insecure headers, cloud storage permissions, directory listing. |
| 3 | A03:2025 | Software Supply Chain Failures | Unpatched dependencies, transitive vulnerabilities, insecure CI/CD, untrusted sources, typosquatting, missing SRI. Highest avg incidence rate (5.72%). |
| 4 | A04:2025 | Cryptographic Failures | Weak algorithms, exposed keys, missing TLS, deprecated hashes (MD5/SHA1), insecure IVs, ECB mode, no forward secrecy. Post-quantum readiness by 2030. |
| 5 | A05:2025 | Injection | SQL, XSS, NoSQL, OS command, ORM, LDAP, EL/OGNL, SSTI. XSS has 30K+ CVEs. Prompt injection noted as separate LLM concern. |
| 6 | A06:2025 | Insecure Design | Architectural flaws vs implementation bugs. Missing threat models, absent security controls, business logic vulnerabilities. Cannot be fixed by perfect implementation. 39 CWEs. |
| 7 | A07:2025 | Authentication Failures | Credential stuffing, weak passwords, missing MFA, session fixation, improper session invalidation, certificate mismatches. 36 CWEs. |
| 8 | A08:2025 | Software/Data Integrity Failures | Insecure CI/CD, auto-updates without verification, unsafe deserialization, missing digital signatures, untrusted artifact sources. |
| 9 | A09:2025 | Security Logging & Alerting Failures | Missing audit trails, unprotected logs, no real-time detection, alert fatigue, sensitive data in logs, log injection vulnerabilities. |
| 10 | A10:2025 | Mishandling of Exceptional Conditions | Failing open, sensitive info in errors, unhandled exceptions, NULL pointer deref, race conditions, resource leaks. 24 CWEs. |

## OWASP API Security Top 10 (2023)

| Code | Name | Description | Key CWEs |
|------|------|-------------|----------|
| API1:2023 | Broken Object Level Authorization | Missing ID-based access validation on endpoints. Attacker manipulates object IDs to access other users' data. | CWE-284, CWE-285, CWE-639 |
| API2:2023 | Broken Authentication | Incorrect auth implementation, token compromise, weak credential transport, missing rate limiting on auth endpoints. | CWE-287, CWE-306, CWE-798 |
| API3:2023 | Broken Object Property Level Authorization | Excessive data exposure (returning more fields than needed) combined with mass assignment (accepting fields that should be read-only). | CWE-213, CWE-915 |
| API4:2023 | Unrestricted Resource Consumption | DoS through bandwidth/CPU/memory/storage exhaustion. Missing rate limiting, pagination limits, query complexity limits. | CWE-400, CWE-770, CWE-799 |
| API5:2023 | Broken Function Level Authorization | Complex RBAC creating auth gaps. Admin functions accessible to regular users. HTTP method confusion (GET vs DELETE). | CWE-285, CWE-269 |
| API6:2023 | Unrestricted Access to Sensitive Business Flows | Missing business flow abuse protections. Automated ticket buying, comment spam, coupon abuse without friction. | CWE-799, CWE-837 |
| API7:2023 | Server Side Request Forgery | Unvalidated user-supplied URIs in API calls. Access to internal services, cloud metadata, localhost. | CWE-918 |
| API8:2023 | Security Misconfiguration | Improper settings, missing hardening, permissive CORS, verbose errors, unnecessary HTTP methods, missing TLS. | CWE-16, CWE-209, CWE-942 |
| API9:2023 | Improper Inventory Management | Deprecated APIs still accessible, exposed debug endpoints, undocumented endpoints, missing API versioning strategy. | CWE-1059 |
| API10:2023 | Unsafe Consumption of APIs | Weak security for third-party API integrations. Trusting external data without validation, following redirects blindly. | CWE-20, CWE-295 |

## WSTG v4.2 Test Category Cross-Reference

This table maps each WSTG test category to the security audit pass that covers it.

| WSTG Category | Tests | Primary Pass | Secondary Pass |
|---------------|-------|-------------|----------------|
| **WSTG-INFO** (Information Gathering) | 10 tests: search engine discovery, fingerprinting, metafile review, application enumeration, content review, entry points, execution paths, framework fingerprinting, app fingerprinting, architecture mapping | 01-Reconnaissance | — |
| **WSTG-CONF** (Configuration & Deployment) | 11 tests: network config, platform config, file extensions, backup files, admin interfaces, HTTP methods, HSTS, RIA cross-domain, file permissions, subdomain takeover, cloud storage | 02-Headers & Config | 01-Recon |
| **WSTG-IDNT** (Identity Management) | 5 tests: role definitions, user registration, account provisioning, account enumeration, username policy | 03-Authentication | 04-Authorization |
| **WSTG-ATHN** (Authentication) | 10 tests: credential transport, default credentials, lockout mechanisms, auth bypass, remember password, browser cache, password policy, security questions, password change/reset, alternative channel auth | 03-Authentication | — |
| **WSTG-AUTHZ** (Authorization) | 4 tests: directory traversal/file include, authorization bypass, privilege escalation, IDOR | 04-Authorization | — |
| **WSTG-SESS** (Session Management) | 9 tests: session management schema, cookie attributes, session fixation, exposed session vars, CSRF, logout, session timeout, session puzzling, session hijacking | 03-Authentication, 07-CSRF | — |
| **WSTG-INPV** (Input Validation) | 19 tests: reflected XSS, stored XSS, HTTP verb tampering, parameter pollution, SQL injection (multiple DB types), NoSQL injection, LDAP injection, XML injection, SSI injection, XPath injection, IMAP/SMTP injection, code injection (LFI/RFI), command injection, format string, incubated vulnerabilities, HTTP splitting/smuggling, host header injection, SSTI, SSRF | 05-Injection, 06-XSS | 10-Upload/SSRF |
| **WSTG-ERR** (Error Handling) | 2 tests: improper error handling, stack traces | 13-Error Handling | — |
| **WSTG-CRYP** (Cryptography) | 4 tests: weak TLS, padding oracle, sensitive info via unencrypted channels, weak encryption | 08-Cryptography | — |
| **WSTG-BUSL** (Business Logic) | 9 tests: data validation, request forgery, integrity checks, process timing, function use limits, workflow circumvention, application misuse defenses, unexpected file upload, malicious file upload | 11-Business Logic | 10-Upload/SSRF |
| **WSTG-CLNT** (Client-side) | 13 tests: DOM XSS, JS execution, HTML injection, client-side URL redirect, CSS injection, resource manipulation, CORS, cross-site flashing, clickjacking, WebSockets, web messaging, browser storage, cross-site script inclusion | 06-XSS | 07-CSRF |
| **WSTG-APIT** (API Testing) | 1 test: GraphQL security | 09-API Security | — |

## Pass-to-OWASP Mapping Table

This is the primary reference for mapping each audit pass to its OWASP coverage.

| Pass | OWASP Top 10 (2025) | API Top 10 (2023) | WSTG Categories | CWE Examples |
|------|---------------------|-------------------|-----------------|-------------|
| 01-Reconnaissance | — (Foundation pass) | API9 | WSTG-INFO (all 10) | CWE-200, CWE-538 |
| 02-Headers & Config | A02 | API8 | WSTG-CONF (all 11) | CWE-16, CWE-693, CWE-1021 |
| 03-Authentication | A07 | API2 | WSTG-ATHN (all 10), WSTG-SESS (1-4, 6-9), WSTG-IDNT (all 5) | CWE-287, CWE-384, CWE-613 |
| 04-Authorization | A01 | API1, API3, API5 | WSTG-AUTHZ (all 4) | CWE-639, CWE-285, CWE-862 |
| 05-Injection | A05 | — | WSTG-INPV (4-17) | CWE-89, CWE-78, CWE-90, CWE-91, CWE-94, CWE-1336 |
| 06-XSS & Client-side | A05 | — | WSTG-INPV (1-3), WSTG-CLNT (all 13) | CWE-79, CWE-1321, CWE-116 |
| 07-CSRF & Clickjacking | A01 | — | WSTG-SESS-05, WSTG-CLNT-09 | CWE-352, CWE-1021 |
| 08-Cryptography | A04 | — | WSTG-CRYP (all 4) | CWE-326, CWE-327, CWE-311 |
| 09-API Security | A02, A05 | API1-API10 (all) | WSTG-APIT-01 | CWE-284, CWE-400, CWE-918 |
| 10-File Upload & SSRF | A05 | API7 | WSTG-BUSL-08/09, WSTG-INPV-19 | CWE-434, CWE-918, CWE-22 |
| 11-Business Logic | A06 | API6 | WSTG-BUSL (all 9) | CWE-840, CWE-362, CWE-367 |
| 12-Supply Chain | A03, A08 | API10 | — | CWE-829, CWE-1357, CWE-502 |
| 13-Error Handling | A10 | API8 | WSTG-ERR (all 2) | CWE-209, CWE-200, CWE-755 |
| 14-Rate Limiting | — | API4, API6 | — | CWE-770, CWE-799, CWE-400 |
| 15-Compliance & Logging | A09 | — | — | CWE-778, CWE-117, CWE-532 |

## Common CWE Reference

| CWE | Name | Typical Finding |
|-----|------|-----------------|
| CWE-22 | Path Traversal | `../../etc/passwd` in file parameters |
| CWE-78 | OS Command Injection | User input in shell commands |
| CWE-79 | Cross-Site Scripting (XSS) | Unsanitized output in HTML context |
| CWE-89 | SQL Injection | User input in SQL queries |
| CWE-200 | Exposure of Sensitive Information | Stack traces, debug info in responses |
| CWE-209 | Error Message Information Leak | Database errors with schema details |
| CWE-285 | Improper Authorization | Missing access checks on endpoints |
| CWE-287 | Improper Authentication | Weak or bypassable auth mechanisms |
| CWE-311 | Missing Encryption of Sensitive Data | PII transmitted over HTTP |
| CWE-326 | Inadequate Encryption Strength | TLS 1.0/1.1, weak cipher suites |
| CWE-327 | Broken Crypto Algorithm | MD5/SHA1 for password hashing |
| CWE-352 | Cross-Site Request Forgery | Missing CSRF tokens on state changes |
| CWE-384 | Session Fixation | Session ID not rotated after login |
| CWE-400 | Uncontrolled Resource Consumption | No rate limiting on endpoints |
| CWE-434 | Unrestricted File Upload | Executable file upload allowed |
| CWE-502 | Deserialization of Untrusted Data | User-controlled serialized objects |
| CWE-532 | Insertion of Sensitive Info into Log | Passwords/tokens in application logs |
| CWE-613 | Insufficient Session Expiration | No idle/absolute session timeout |
| CWE-639 | Insecure Direct Object Reference | Sequential ID enumeration |
| CWE-693 | Protection Mechanism Failure | Missing security headers |
| CWE-770 | Allocation Without Limits | No pagination or query limits |
| CWE-798 | Hard-coded Credentials | Secrets in source code |
| CWE-829 | Untrusted Functionality Inclusion | CDN scripts without SRI |
| CWE-862 | Missing Authorization | No auth check on admin endpoints |
| CWE-918 | Server-Side Request Forgery | User-controlled URLs in server requests |
| CWE-1021 | Improper Restriction of Rendered UI | Missing X-Frame-Options/CSP |
| CWE-1321 | Prototype Pollution | `__proto__` injection in JavaScript |
| CWE-1336 | Server-Side Template Injection | Expression evaluation in templates |
| CWE-1357 | Reliance on Uncontrolled Component | Outdated dependencies with known CVEs |
