# Pass 15: Compliance & Security Logging

**Weight:** 2% of Security Score
**OWASP Mapping:** A09:2025 (Security Logging & Alerting Failures), SOC 2 Trust Service Criteria, HIPAA Technical Safeguards (45 CFR 164.312), PCI-DSS v4.0 Requirements
**Automation Level:** 30% fully automated, 50% AI-assisted, 20% manual judgment
**Difficulty:** Medium to High -- requires understanding of compliance frameworks and audit expectations

---

## Overview

Security logging and compliance validation ensures the application generates adequate audit trails, protects log integrity, avoids logging sensitive data, and aligns with applicable regulatory frameworks. OWASP ranks logging failures at #9 because without proper logging, breaches go undetected, incident response is impossible, and compliance requirements are unmet.

**Key Principle:** Logs must answer four questions for every security-relevant event: WHO did WHAT, WHEN, and from WHERE. Simultaneously, logs must never contain sensitive data (passwords, tokens, PII) that would create a secondary breach vector.

**Compliance Note:** This pass checks for alignment with SOC 2, HIPAA, and PCI-DSS requirements that overlap with web application security. It does not replace a formal compliance audit but identifies gaps that would be flagged during one.

---

## Tier 0: Static Analysis (Code Review)

### 0.1 Logging Middleware and Configuration

Search for logging infrastructure and configuration.

**Grep patterns:**

```
# Node.js logging libraries
Pattern: (winston|pino|bunyan|morgan|log4js|winston-daily-rotate|signale)
Files: package.json, **/*.{js,ts}
Context: Check for structured logging, log levels, transport configuration

# Python logging
Pattern: (logging\.getLogger|logging\.config|structlog|loguru)
Files: **/*.py, logging.conf, logging.yml
Context: Check for proper configuration with handlers and formatters

# Java logging
Pattern: (LoggerFactory\.getLogger|log4j|logback|java\.util\.logging|SLF4J)
Files: **/*.java, logback.xml, log4j2.xml
Context: Check for structured logging and appropriate log levels

# PHP logging
Pattern: (Monolog|Log::|logger->|PSR\\Log)
Files: **/*.php, config/logging.php
Context: Check for log channels and level configuration

# Go logging
Pattern: (log\.New|zap\.New|logrus\.New|zerolog)
Files: **/*.go
Context: Check for structured logging with context

# General log level configuration
Pattern: (LOG_LEVEL|log\.level|loglevel|logging\.level)\s*[=:]\s*['"]?(debug|trace|verbose)
Files: **/*.{env,yml,yaml,json,ini,conf,properties}
Context: Debug/trace level in production exposes excessive detail
```

### 0.2 Audit Trail Implementation

Search for audit logging of security-relevant events.

**Grep patterns:**

```
# Authentication event logging
Pattern: (log|logger|audit)\.(info|warn|error).*\b(login|logout|auth|signin|signout|session)\b
Files: **/*.{js,ts,py,rb,php,java,go}
Context: Verify both successful and failed auth events are logged

# Authorization event logging
Pattern: (log|logger|audit)\.(info|warn|error).*\b(access|permission|forbidden|unauthorized|denied|role)\b
Files: **/*.{js,ts,py,rb,php,java,go}
Context: Access control decisions should be logged

# Data modification logging
Pattern: (log|logger|audit)\.(info|warn).*\b(create|update|delete|modify|change|remove)\b
Files: **/*.{js,ts,py,rb,php,java,go}
Context: CRUD operations on sensitive data should have audit trail

# Admin action logging
Pattern: (log|logger|audit)\.(info|warn).*\b(admin|config|setting|permission|role|user)\b
Files: **/*.{js,ts,py,rb,php,java,go}
Context: Administrative actions require enhanced audit logging

# Audit table/model
Pattern: (audit|audit_log|activity_log|event_log|security_log)
Files: **/*.{sql,prisma,py,rb,js,ts}
Context: Dedicated audit trail table/collection
```

### 0.3 Sensitive Data in Logs

Search for logging statements that may capture sensitive information.

**Grep patterns:**

```
# Direct sensitive field logging
Pattern: (log|logger|console)\.(info|debug|warn|error|log).*\b(password|passwd|pwd|secret|token|bearer|authorization|credit.?card|ssn|social.?security|cvv|cvc|pin)\b
Files: **/*.{js,ts,py,rb,php,java,go}
Context: Sensitive fields must never appear in log output

# Request body logging (may contain credentials)
Pattern: (log|logger|console)\.(info|debug|log).*\b(req\.body|request\.body|request\.data|request\.json|body|payload)\b
Files: **/*.{js,ts,py,rb,php}
Context: Full request body logging captures form submissions including passwords

# HTTP header logging (may contain auth tokens)
Pattern: (log|logger|console)\.(info|debug|log).*\b(headers|req\.headers|request\.headers)\b
Files: **/*.{js,ts,py,rb,php}
Context: Header logging captures Authorization, Cookie, and API key headers

# Database query logging with parameters
Pattern: (log|logger|console)\.(info|debug|log).*\b(query|sql|statement)\b.*\b(param|value|bind|arg)\b
Files: **/*.{js,ts,py,rb,php}
Context: Query logging with bound parameters may expose sensitive data

# Error logging with full context
Pattern: (log|logger|console)\.error\(\s*(err|error|e|ex)\s*,?\s*(req|request|ctx|context)?\s*\)
Files: **/*.{js,ts,py,rb,php}
Context: Error objects with request context may contain sensitive data
```

### 0.4 Log Injection Prevention

Search for user input that flows into log statements without sanitization.

**Grep patterns:**

```
# Direct user input in log messages
Pattern: (log|logger|console)\.(info|warn|error|debug|log)\s*\(\s*[`'"].*\$\{.*req\.|.*\$\{.*request\.|.*\+\s*req\.|.*\+\s*request\.
Files: **/*.{js,ts}
Context: String interpolation of user input in logs enables log injection

# Python f-string/format in logging
Pattern: (logging|logger)\.(info|warn|error|debug)\s*\(\s*f['"]
Files: **/*.py
Context: f-strings in logging bypass lazy evaluation and risk injection

# Log message with unvalidated user input
Pattern: (log|logger)\.(info|warn|error)\s*\(.*\b(username|email|name|input|param|query)\b
Files: **/*.{js,ts,py,rb,php,java}
Context: User-controlled values in logs should be sanitized (strip newlines, control chars)
```

---

## Tier 1: Automated Scanning (Burp MCP + Playwright)

### Check 15.1: Login Event Logging

**Tools:** Code analysis + Playwright
**OWASP:** A09:2025

```
WORKFLOW:
1. Review authentication code for logging statements (Tier 0)
2. Use Playwright to perform login actions and verify logging

PLAYWRIGHT TEST SEQUENCE:
a) Successful login:
   - Navigate to login page
   - Enter valid credentials
   - Submit and verify login success
   - Check: Is this event logged? (verify via log output, admin panel, or audit trail)

b) Failed login:
   - Navigate to login page
   - Enter invalid credentials
   - Submit and verify login failure
   - Check: Is this event logged with username and IP?

c) Account lockout:
   - Submit 5+ failed login attempts
   - Check: Is the lockout event logged?

d) Logout:
   - Perform logout action
   - Check: Is the logout event logged?

REQUIRED LOG FIELDS (per event):
- Timestamp (ISO 8601, UTC)
- Event type (login_success, login_failure, logout, lockout)
- User identifier (username or user ID -- NOT password)
- Source IP address
- User agent
- Result (success/failure)
- Session ID (hashed, not raw)

INDICATORS OF VULNERABILITY:
- No logging of failed login attempts
- No logging of successful logins
- Missing IP address or user agent in log entries
- Password included in log entry
- No distinction between failed and successful events
```

### Check 15.2: High-Value Transaction Logging

**Tools:** Code analysis
**OWASP:** A09:2025

```
WORKFLOW:
1. Identify high-value transactions in the application:
   - Financial transactions (payments, transfers, refunds)
   - Account modifications (password change, email change, role change)
   - Data operations (export, bulk delete, import)
   - Administrative actions (user management, config changes)
   - Security events (MFA enable/disable, API key generation)
2. Check if each transaction type has corresponding audit log entries

CODE REVIEW CHECKLIST:
[ ] Payment/financial endpoints log: amount, currency, parties, result
[ ] Password change logs: user ID, timestamp, source IP (NOT old/new password)
[ ] Role/permission changes log: who changed, what changed, who was affected
[ ] Data exports log: who exported, what data, how many records
[ ] Configuration changes log: setting name, old value, new value, who changed
[ ] API key operations log: creation, revocation, who performed
[ ] MFA events log: enable, disable, recovery code use

INDICATORS OF VULNERABILITY:
- Financial transactions not logged at all
- Missing "who" (no user identifier in log entry)
- Missing "what changed" (no before/after values)
- No audit trail for administrative actions
- Bulk operations logged as single entry without detail
```

### Check 15.3: Log Injection

**Tools:** Burp Intruder
**OWASP:** A09:2025

```
WORKFLOW:
1. Identify inputs that are likely logged (username, search query, error triggers)
2. Inject log-forging payloads
3. If log access is available, verify injection

PAYLOADS:
a) Newline injection (forge log entries):
   - username: "admin\n2026-06-02T00:00:00Z INFO Login successful for admin"
   - search: "query\r\nERROR Critical security event detected"

b) ANSI escape code injection (if logs viewed in terminal):
   - username: "admin\x1b[31mERROR\x1b[0m"

c) Format string injection (if using printf-style logging):
   - username: "%s%s%s%s%s%s%s%s%s%s"
   - username: "%n%n%n%n%n%n%n%n"

d) Large input (log flooding):
   - username: "A" * 10000 (10KB username field)

e) Unicode/control character injection:
   - username: "admin\u0000\u0008\u007f"

INDICATORS OF VULNERABILITY:
- Newlines in user input create fake log entries
- ANSI codes render in terminal-based log viewers
- Format string specifiers cause crashes or data leakage
- No input length limit on logged fields
- No sanitization of control characters before logging
```

### Check 15.4: Sensitive Data in Logs

**Tools:** Code analysis (Grep)
**OWASP:** A09:2025

```
WORKFLOW:
1. Search codebase for logging statements (Tier 0 patterns)
2. Trace data flow from sensitive fields to log outputs
3. Check log configuration for field masking/redaction

SENSITIVE DATA CATEGORIES:
- Authentication: passwords, tokens, API keys, session IDs
- Personal: SSN, date of birth, full name + address
- Financial: credit card numbers, bank accounts, CVV
- Health: medical records, diagnoses, prescriptions (HIPAA)
- Technical: database connection strings, encryption keys, internal IPs

CHECK LOG CONFIGURATION FOR:
- Field masking/redaction rules
- Sensitive field allowlist/blocklist
- Log level filtering (debug logs with sensitive data not in production)
- Log retention policies

CODE PATTERNS TO FLAG:
```javascript
// BAD: Logs password
logger.info('Login attempt', { username, password });

// BAD: Logs full request body (may contain credentials)
logger.debug('Request received', req.body);

// BAD: Logs authorization header
logger.info('API call', { headers: req.headers });

// GOOD: Redacted logging
logger.info('Login attempt', { username, password: '[REDACTED]' });

// GOOD: Selective field logging
logger.info('API call', { method: req.method, path: req.path, userId: req.user?.id });
```

INDICATORS OF VULNERABILITY:
- Passwords appear in log output
- Full request bodies logged without field filtering
- Authorization headers logged in plaintext
- Credit card numbers logged without masking
- No log redaction/masking configuration
```

### Check 15.5: Log Integrity Protection

**Tools:** Code analysis
**OWASP:** A09:2025

```
WORKFLOW:
1. Check log storage and transport configuration
2. Verify log integrity mechanisms

CHECKS:
a) Log transport security:
   - Are logs sent over encrypted channels (TLS)?
   - Are log aggregation endpoints authenticated?
   - Is the log transport reliable (queue-based, not UDP)?

b) Log storage:
   - Are logs stored in append-only storage?
   - Is there write protection preventing log modification?
   - Are logs stored separately from the application server?
   - Is there log rotation with retention policy?

c) Tamper detection:
   - Are log entries signed or hashed?
   - Is there a separate integrity monitoring system?
   - Would log deletion be detected?

d) Access control:
   - Who can read application logs?
   - Who can modify or delete logs?
   - Is log access itself logged (meta-audit)?

FILES TO CHECK:
- Log rotation config: logrotate.conf, winston-daily-rotate config
- Log shipping config: filebeat.yml, fluentd.conf, vector.toml
- Cloud logging: CloudWatch config, GCP Logging config, Azure Monitor
- SIEM integration: Splunk forwarder, Elastic agent, Datadog agent

INDICATORS OF VULNERABILITY:
- Logs stored on same server as application (single point of compromise)
- No log rotation (disk exhaustion risk)
- Logs accessible to application runtime user (modifiable after breach)
- No centralized log aggregation (logs lost if server compromised)
- No retention policy (compliance violation)
```

### Check 15.6: HIPAA Technical Safeguards

**Tools:** Combined analysis
**Regulation:** 45 CFR 164.312

```
APPLICABILITY: Only if the application handles Protected Health Information (PHI)

SAFEGUARD CHECKS:

a) Access Control (164.312(a)):
   [ ] Unique User Identification: Each user has unique ID (no shared accounts)
   [ ] Emergency Access Procedure: Documented break-glass process
   [ ] Automatic Logoff: Session timeout configured (idle and absolute)
   [ ] Encryption and Decryption: PHI encrypted at rest

b) Audit Controls (164.312(b)):
   [ ] Activity logging: All access to PHI is logged
   [ ] Log retention: Minimum 6 years for HIPAA
   [ ] Log review: Regular review process documented
   [ ] User activity tracking: Who accessed what PHI, when

c) Integrity Controls (164.312(c)):
   [ ] Data integrity verification: Checksums or signatures on PHI
   [ ] Tamper detection: Mechanism to detect unauthorized modifications
   [ ] Backup verification: Regular backup integrity testing

d) Transmission Security (164.312(e)):
   [ ] Encryption in transit: TLS 1.2+ for all PHI transmission
   [ ] Integrity controls: HMAC or similar for PHI in transit

e) Person/Entity Authentication (164.312(d)):
   [ ] MFA for PHI access
   [ ] Certificate-based authentication for system-to-system
   [ ] Strong password policy enforcement

GREP PATTERNS:
# PHI field identification
Pattern: (patient|diagnosis|medication|prescription|treatment|medical|health|clinical|dob|date.?of.?birth|ssn|insurance|npi|mrn)
Files: **/*.{js,ts,py,rb,php,sql,prisma}
Context: Identify all PHI-related data fields and verify protection

INDICATORS OF NON-COMPLIANCE:
- PHI accessible without authentication
- No audit trail for PHI access
- PHI transmitted without encryption
- Session timeout > 15 minutes for PHI access
- Shared accounts with PHI access
- No MFA for PHI-accessing users
```

### Check 15.7: PCI-DSS Web Security Requirements

**Tools:** Combined analysis
**Regulation:** PCI-DSS v4.0

```
APPLICABILITY: Only if the application handles cardholder data (CHD)

REQUIREMENT CHECKS:

a) Requirement 2 -- Secure Configuration:
   [ ] No default credentials on any system component
   [ ] Unnecessary services/protocols disabled
   [ ] Security parameters documented and enforced

b) Requirement 3 -- Protect Stored CHD:
   [ ] PAN (Primary Account Number) stored encrypted (AES-256 or equivalent)
   [ ] PAN masked when displayed (first 6, last 4 only)
   [ ] No CVV/CVC stored after authorization
   [ ] Encryption keys managed with proper rotation

c) Requirement 4 -- Encrypt CHD in Transit:
   [ ] TLS 1.2+ for all CHD transmission
   [ ] No CHD in URLs/query strings
   [ ] No CHD in cookies or local storage

d) Requirement 6 -- Secure Development:
   [ ] OWASP Top 10 addressed in development
   [ ] Code review process documented
   [ ] Custom code tested for common vulnerabilities
   [ ] Public-facing web apps protected (WAF or code review)

e) Requirement 8 -- Strong Authentication:
   [ ] MFA for administrative access
   [ ] Password complexity and rotation policy
   [ ] Account lockout after repeated failures

f) Requirement 10 -- Logging and Monitoring:
   [ ] All access to CHD logged
   [ ] All admin actions logged
   [ ] Log entries include: user ID, event type, date/time, success/failure, origin
   [ ] Logs secured against tampering
   [ ] Log review process documented
   [ ] Log retention: minimum 12 months, 3 months immediately available

GREP PATTERNS:
# Cardholder data identification
Pattern: (card.?number|pan|credit.?card|debit.?card|card.?holder|expir|cvv|cvc|track.?data|magnetic.?stripe)
Files: **/*.{js,ts,py,rb,php,sql,prisma}
Context: Identify all CHD fields and verify PCI-DSS protection

INDICATORS OF NON-COMPLIANCE:
- Full PAN stored without encryption
- CVV stored after transaction authorization
- CHD in URL parameters or log files
- No MFA for admin access
- Missing audit trail for CHD access
- Logs retained less than 12 months
```

### Check 15.8: SOC 2 Security Criteria

**Tools:** Combined analysis
**Framework:** AICPA Trust Service Criteria

```
APPLICABILITY: Required for SaaS/cloud service providers

CRITERIA CHECKS:

a) CC6.1 -- Logical Access Controls:
   [ ] Role-based access control (RBAC) implemented
   [ ] Principle of least privilege enforced
   [ ] Access reviews performed regularly
   [ ] User provisioning/deprovisioning process
   [ ] Privileged access management

b) CC6.6 -- Encryption in Transit:
   [ ] TLS 1.2+ for all external connections
   [ ] Certificate management and rotation
   [ ] HSTS enabled with appropriate max-age

c) CC6.7 -- Data Integrity:
   [ ] Input validation on all data entry points
   [ ] Output encoding to prevent injection
   [ ] Data validation checksums where appropriate

d) CC7.1 -- Monitoring and Detection:
   [ ] Security event monitoring in place
   [ ] Intrusion detection/prevention system
   [ ] Anomaly detection for unusual access patterns
   [ ] Incident response plan documented

e) CC7.2 -- Incident Response:
   [ ] Documented incident response procedures
   [ ] Incident classification and escalation
   [ ] Communication plan for security incidents
   [ ] Post-incident review process

f) CC8.1 -- Change Management:
   [ ] Version control for all code changes
   [ ] Code review process before deployment
   [ ] Testing requirements before production release
   [ ] Rollback procedures documented
   [ ] Separation of development and production environments

INDICATORS OF NON-COMPLIANCE:
- No RBAC or access control framework
- Missing change management documentation
- No incident response plan
- No separation of environments (dev/staging/prod)
- No security monitoring or alerting
- No access review process
```

### Check 15.9: Alerting Mechanisms

**Tools:** Code analysis
**OWASP:** A09:2025

```
WORKFLOW:
1. Check for security event alerting configuration
2. Verify alert thresholds and notification channels

CHECKS:
a) Alert triggers:
   [ ] Multiple failed login attempts (brute force detection)
   [ ] Login from new geographic location
   [ ] Administrative actions outside business hours
   [ ] Rate limit violations
   [ ] Application errors exceeding threshold
   [ ] Security scan detection
   [ ] Data export above normal volume

b) Alert channels:
   [ ] Email notifications configured
   [ ] Slack/Teams integration for real-time alerts
   [ ] PagerDuty/OpsGenie for critical alerts
   [ ] SMS for emergency escalation

c) Alert configuration:
   [ ] Appropriate thresholds (not too noisy, not too quiet)
   [ ] Escalation paths defined
   [ ] On-call rotation configured
   [ ] Alert suppression/deduplication

FILES TO CHECK:
- Monitoring config: prometheus/alerts.yml, datadog-monitors.yml
- Application config: alert-rules.*, notification-config.*
- CI/CD: .github/workflows/ (security scanning alerts)
- Error tracking: sentry.*, bugsnag.*, rollbar.*

INDICATORS OF VULNERABILITY:
- No security alerting configured
- Alerts only go to email (high latency, easy to miss)
- No escalation path for critical security events
- Alert fatigue (too many low-priority alerts)
- No after-hours alerting capability
```

### Check 15.10: Data Classification

**Tools:** Code analysis
**OWASP:** A09:2025

```
WORKFLOW:
1. Identify all data types stored by the application
2. Check if data classification is implemented
3. Verify appropriate protection levels per classification

DATA CLASSIFICATION LEVELS:
- Public: Marketing content, public pages (minimal protection)
- Internal: Business data, analytics (access control required)
- Confidential: User PII, financial data (encryption + access control + audit)
- Restricted: PHI, CHD, authentication secrets (maximum protection)

CHECKS:
a) Data inventory:
   [ ] All data types documented
   [ ] Data classification labels assigned
   [ ] Data owner identified for each type

b) Protection alignment:
   [ ] Restricted data encrypted at rest and in transit
   [ ] Confidential data access controlled and audited
   [ ] Internal data protected from public access
   [ ] Data retention policies defined per classification

c) Data handling:
   [ ] Restricted data masked in non-production environments
   [ ] Data minimization practiced (collect only what is needed)
   [ ] Data disposal procedures documented
   [ ] Cross-border data transfer compliance

GREP PATTERNS:
# Identify sensitive data models/schemas
Pattern: (email|phone|address|ssn|dob|salary|account.?number|routing.?number|tax.?id|passport|driver.?license)
Files: **/*.{prisma,sql,py,rb,js,ts}
Context: Map all PII/sensitive fields and verify classification

INDICATORS OF VULNERABILITY:
- No data classification scheme
- Sensitive data stored without encryption
- No data retention policy
- Production data used in development/testing
- No data minimization (collecting unnecessary PII)
- Missing privacy policy or data processing agreement
```

---

## Tier 2: AI Judgment Questions

### Question 1: Logging Completeness
Does the application log all security-relevant events as defined by OWASP logging guidelines? Are there gaps in the audit trail that would prevent forensic investigation of a security incident?

### Question 2: Log Usefulness
Would the current logging be sufficient to reconstruct the sequence of events during a breach? Can logs answer: Who was affected? What data was accessed? When did it start? How did the attacker gain access?

### Question 3: Compliance Alignment
Based on the application's data types and user base, which compliance frameworks apply (SOC 2, HIPAA, PCI-DSS, GDPR)? Are there material gaps between current logging/security practices and the applicable requirements?

### Question 4: Detection Capability
If an attacker gained access today, how long would it take to detect the breach based on current monitoring and alerting? Is there real-time detection capability, or only post-incident log review?

### Question 5: Log Hygiene
Are logs clean enough for automated analysis (structured JSON, consistent fields, ISO timestamps)? Could an attacker pollute logs to hide their activity (log injection)?

### Question 6: Proportional Response
Are security controls proportional to the data sensitivity? Is the application over-secured for public data or under-secured for restricted data? Is there evidence of thoughtful risk assessment?

---

## Severity Classification

### Critical (P1) -- Score: 0/10
- No security event logging at all (authentication, authorization, data access)
- Passwords or encryption keys appearing in log output
- HIPAA-regulated PHI accessible without audit trail
- PCI-DSS cardholder data stored without encryption
- Fail-open on logging failure (logging error bypasses security controls)

### High (P2) -- Score: 2/10
- Failed login attempts not logged (brute-force attacks undetectable)
- No alerting mechanism for security events
- Sensitive data (tokens, PII) in log output
- Log injection vulnerability allowing log forging
- No log integrity protection (logs modifiable by application)
- Missing compliance controls for applicable framework (HIPAA/PCI)

### Medium (P3) -- Score: 5/10
- Incomplete audit trail (some high-value transactions not logged)
- Logs stored only on application server (lost if compromised)
- No log retention policy or retention too short
- Alerting configured but with excessive thresholds
- No data classification scheme

### Low (P4) -- Score: 7/10
- Log entries missing some recommended fields (user agent, session ID)
- Log format inconsistent across services (hard to correlate)
- Alerting present but only via email (no real-time channel)
- Data classification exists but not consistently applied
- Log level too verbose in production (debug level enabled)

---

## False Positive Indicators

1. **External Logging Service:** The application may use an external logging service (Datadog, Splunk, CloudWatch) that handles log integrity, retention, and alerting. Check external service configuration before flagging missing features in application code.
2. **Infrastructure-Level Logging:** WAF, API Gateway, and load balancer logs may provide the audit trail even if application-level logging is minimal. Verify the complete logging architecture.
3. **Compliance Not Applicable:** Not all applications handle regulated data. Do not flag HIPAA non-compliance for an application that does not process PHI. Do not flag PCI-DSS for applications without payment processing.
4. **Log Redaction in Transit:** Some logging pipelines redact sensitive data in the log shipper (Fluentd, Logstash) rather than in application code. The application logs may contain sensitive data that is stripped before storage.
5. **Separate Audit Service:** Some architectures use a dedicated audit service (event sourcing, audit log microservice) rather than application-level logging. The application may emit audit events to a message queue rather than writing logs directly.
6. **Development vs. Production:** Debug-level logging with sensitive data in development is acceptable as long as it is disabled in production configuration.

---

## Remediation

### Structured Logging Implementation

```javascript
// Express.js structured logging with pino
const pino = require('pino');

const logger = pino({
  level: process.env.LOG_LEVEL || 'info',
  timestamp: pino.stdTimeFunctions.isoTime,
  redact: {
    paths: ['req.headers.authorization', 'req.headers.cookie', 'password', 'token', 'secret', 'ssn', 'creditCard'],
    censor: '[REDACTED]'
  },
  serializers: {
    req: (req) => ({
      method: req.method,
      url: req.url,
      remoteAddress: req.remoteAddress,
      userAgent: req.headers['user-agent']
    })
  }
});
```

### Audit Trail Pattern

```javascript
// Audit event structure
function auditLog(event) {
  logger.info({
    type: 'audit',
    event: event.action,        // 'login_success', 'data_export', 'role_change'
    actor: {
      userId: event.userId,
      ip: event.ip,
      userAgent: event.userAgent
    },
    target: {
      type: event.targetType,   // 'user', 'order', 'setting'
      id: event.targetId
    },
    changes: event.changes,     // { field: { from: old, to: new } }
    result: event.result,       // 'success' | 'failure'
    timestamp: new Date().toISOString()
  });
}
```

### Log Injection Prevention

```javascript
// Sanitize user input before logging
function sanitizeForLog(input) {
  if (typeof input !== 'string') return input;
  return input
    .replace(/[\r\n]/g, ' ')          // Remove newlines (prevent log forging)
    .replace(/[\x00-\x1f\x7f]/g, '')  // Remove control characters
    .substring(0, 500);                // Limit length
}

logger.info('Login attempt', { username: sanitizeForLog(req.body.username) });
```

### Security Event Alerting

```yaml
# Example: Prometheus alerting rules
groups:
  - name: security_alerts
    rules:
      - alert: BruteForceDetected
        expr: rate(login_failures_total[5m]) > 10
        for: 2m
        labels:
          severity: high
        annotations:
          summary: "Brute force attack detected"
          description: "More than 10 failed logins per minute for 2 minutes"

      - alert: UnusualDataExport
        expr: data_export_records_total > 10000
        for: 1m
        labels:
          severity: high
        annotations:
          summary: "Large data export detected"

      - alert: AdminActionAfterHours
        expr: admin_actions_total > 0 and (hour() < 6 or hour() > 22)
        labels:
          severity: medium
        annotations:
          summary: "Administrative action outside business hours"
```

### Compliance Checklist Templates

**HIPAA Minimum Viable Logging:**
- All PHI access logged with user ID, timestamp, action, data accessed
- Failed access attempts logged and alerted
- Log retention minimum 6 years
- Log integrity protection (immutable storage or WORM)
- Regular log review process documented

**PCI-DSS Minimum Viable Logging:**
- All access to cardholder data logged
- All administrative actions logged
- Log entries include: user, event type, date/time, success/failure, origin, affected data
- Logs protected against tampering
- Log retention: 12 months minimum, 3 months immediately accessible
- Daily log review process

**SOC 2 Minimum Viable Controls:**
- RBAC with documented access policies
- Change management with version control and code review
- Incident response plan with defined roles and escalation
- Monitoring and alerting for security events
- Regular access reviews and deprovisioning
- Encryption in transit (TLS 1.2+) and at rest for sensitive data
