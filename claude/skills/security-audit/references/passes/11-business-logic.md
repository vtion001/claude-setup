# Pass 11: Business Logic Vulnerabilities

**Weight:** 5% of Security Score
**OWASP Mapping:** A06:2025 (Insecure Design), WSTG-BUSL-01 through WSTG-BUSL-09
**Automation Level:** 10% fully automated, 40% AI-assisted, 50% manual judgment
**Difficulty:** High -- business logic flaws are context-dependent and cannot be detected by signature-based scanning alone

---

## Overview

Business logic vulnerabilities arise when application workflows, rules, or constraints can be subverted through unexpected user behavior. Unlike injection or XSS, these flaws exist in the design itself -- scanners cannot detect them because the requests are technically valid. This pass requires deep understanding of the application's intended behavior to identify deviations.

**Key Principle:** Every multi-step process, numeric calculation, and business rule is a potential attack surface. The question is always: "What happens if the user does something the developer did not anticipate?"

---

## Tier 0: Static Analysis (Code Review)

### 0.1 Race Condition Patterns

Search for non-atomic read-modify-write operations, missing database transactions, and absent locking mechanisms.

**Grep patterns:**

```
# Missing transactions around balance/inventory operations
Pattern: (balance|inventory|stock|quantity|credits|points|wallet).*[+-=]
Files: **/*.{js,ts,py,rb,php,java,go}
Context: Check if wrapped in transaction/lock

# Non-atomic counter increments
Pattern: (findOne|findById|get|fetch|load).*\n.*(save|update|put|patch)
Files: **/*.{js,ts,py,rb,php,java}
Context: Read-then-write without atomic operation

# Missing database transaction wrappers
Pattern: (async\s+function|def\s+)\w*(purchase|checkout|transfer|withdraw|redeem|apply|claim)
Files: **/*.{js,ts,py,rb,php}
Context: Verify transaction/lock wraps the entire operation

# Optimistic concurrency without version checking
Pattern: (UPDATE|update)\s.*WHERE\s+id\s*=
Files: **/*.{js,ts,py,sql}
Context: Missing version/timestamp in WHERE clause
```

**Read patterns:**

```
# Check ORM configuration for transaction support
Files: config/database.*, ormconfig.*, prisma/schema.prisma, models/*.py
Look for: transaction isolation level, pessimistic locking config

# Check queue/job processor for idempotency
Files: jobs/*.*, workers/*.*, queues/*.*
Look for: idempotency keys, deduplication, exactly-once processing
```

### 0.2 Numeric Input Validation

Search for missing validation on numeric inputs that affect pricing, quantities, or calculations.

**Grep patterns:**

```
# Price/amount fields without validation
Pattern: (price|amount|total|cost|fee|rate|discount)\s*[=:]\s*(req\.|request\.|params\.|body\.)
Files: **/*.{js,ts,py,rb,php}
Context: No parseInt/parseFloat with min/max validation

# Quantity without bounds checking
Pattern: (quantity|qty|count|num|limit)\s*[=:]\s*(req\.|request\.|params\.|body\.)
Files: **/*.{js,ts,py,rb,php}
Context: No Math.max(0, ...) or >= 0 check

# Division operations without zero-check
Pattern: /\s*(req\.|request\.|params\.|body\.|input\.)
Files: **/*.{js,ts,py,rb,php}
Context: Missing zero-division guard

# Integer overflow risk (large number handling)
Pattern: parseInt|Number\(|int\(|Integer\.parseInt
Files: **/*.{js,ts,py,java}
Context: No MAX_SAFE_INTEGER / bounds check
```

### 0.3 Multi-Step Process Integrity

Search for workflows that lack step validation or state machine enforcement.

**Grep patterns:**

```
# Step/stage parameters accepted from client
Pattern: (step|stage|phase|state|status)\s*[=:]\s*(req\.|request\.|params\.|body\.)
Files: **/*.{js,ts,py,rb,php}
Context: Client controls workflow progression

# Missing state machine or workflow engine
Pattern: (if|switch).*\.(step|stage|status)\s*===?\s*['"]
Files: **/*.{js,ts,py,rb,php}
Context: Ad-hoc state checking instead of enforced state machine

# Order/payment status transitions without validation
Pattern: (status|state)\s*=\s*['"]?(completed|paid|approved|shipped|verified)
Files: **/*.{js,ts,py,rb,php}
Context: Direct status assignment without transition validation
```

---

## Tier 1: Automated Scanning (Burp MCP + Playwright)

### Check 11.1: Workflow Bypass (Skip Steps in Multi-Step Processes)

**Tools:** Burp Repeater + Playwright
**WSTG:** WSTG-BUSL-06

```
WORKFLOW:
1. Use Playwright to complete the full multi-step process normally (e.g., registration, checkout, application)
2. Record all HTTP requests for each step via Burp Proxy
3. Use Burp Repeater to send the FINAL step's request directly, skipping intermediate steps
4. Check if the operation completes without prior steps

BURP REPEATER:
- Capture Step 3 (final) request
- Send it without completing Step 1 or Step 2
- Observe: Does the server validate that prior steps were completed?
- Check for session-based step tracking vs. client-side step tracking

PLAYWRIGHT:
- Navigate directly to the final step URL (if URL-based)
- Attempt to submit the final form without visiting prior pages
- Check if hidden fields or tokens from prior steps are required

INDICATORS OF VULNERABILITY:
- Final step succeeds without prior steps
- Server returns 200/201 instead of 400/403
- No server-side session tracking of completed steps
```

### Check 11.2: Race Conditions (Parallel Request Submission)

**Tools:** Burp Intruder (single-packet attack)
**WSTG:** WSTG-BUSL-05

```
WORKFLOW:
1. Identify operations with limits (coupon redemption, balance transfer, inventory claim)
2. Set up Burp Intruder with the same request duplicated 10-20 times
3. Use single-packet attack (HTTP/2) or last-byte sync to send all requests simultaneously
4. Check if the limit was exceeded

BURP INTRUDER CONFIGURATION:
- Attack type: Sniper (same payload in same position)
- Payload: Same valid request body repeated
- Concurrency: Maximum (single-packet if HTTP/2 available)
- Connection: Use single TCP connection with HTTP/2 multiplexing

SPECIFIC TESTS:
a) Coupon/discount code: Apply same code in 10 parallel requests
b) Balance transfer: Transfer full balance 10 times simultaneously
c) Inventory claim: Claim last item 10 times simultaneously
d) Vote/like: Submit same vote 10 times simultaneously
e) Account creation: Create same username 10 times simultaneously

INDICATORS OF VULNERABILITY:
- Multiple successful responses (more than 1 coupon applied)
- Balance went negative
- Inventory count went below zero
- Duplicate records created
```

### Check 11.3: Numeric Manipulation (Negative Quantities, Zero Prices, Overflow)

**Tools:** Burp Repeater
**WSTG:** WSTG-BUSL-01

```
WORKFLOW:
1. Capture a legitimate transaction request (purchase, transfer, etc.)
2. Modify numeric fields with edge-case values
3. Send modified requests via Burp Repeater
4. Observe server response and database state

PAYLOAD MATRIX:
| Field Type    | Test Values                                           |
|---------------|-------------------------------------------------------|
| Quantity      | -1, -100, 0, 0.5, 0.001, 99999999, 2147483647        |
| Price/Amount  | -0.01, -1, 0, 0.001, 0.009 (rounding), 999999999.99  |
| Discount %    | -1, 0, 100, 101, 150, 999                             |
| Integer IDs   | 0, -1, 2147483648 (INT overflow), NaN, Infinity       |
| Float values  | NaN, Infinity, -Infinity, 1e308, Number.MIN_VALUE     |

SPECIFIC SCENARIOS:
a) Add item with quantity -1: Does the cart total decrease?
b) Set price to 0 or negative via parameter tampering
c) Set discount to 101% -- does refund exceed original price?
d) Transfer negative amount -- does recipient lose money?
e) Integer overflow on quantity -- does it wrap to negative?

INDICATORS OF VULNERABILITY:
- Negative total prices accepted
- Orders created with zero or negative amounts
- Discount exceeds 100%
- Balance manipulation via negative transfers
```

### Check 11.4: Business Rule Bypass (Discount/Promo Code Abuse)

**Tools:** Burp Repeater + Burp Intruder
**WSTG:** WSTG-BUSL-01, WSTG-BUSL-02

```
WORKFLOW:
1. Identify business rules: promo codes, referral bonuses, loyalty rewards, trial limits
2. Test each rule for bypass possibilities
3. Use Burp Repeater for targeted tests, Intruder for enumeration

SPECIFIC TESTS:
a) Apply same promo code multiple times in same order
b) Apply promo code after order total calculated but before payment
c) Stack multiple different promo codes when only one should be allowed
d) Use expired promo codes (modify expiry in request if sent client-side)
e) Apply promo code to excluded product categories
f) Referral bonus: Refer yourself (same email/phone variants)
g) Trial period: Reset trial by changing email/device fingerprint
h) Free tier limits: Bypass by creating multiple accounts

BURP INTRUDER (for code enumeration):
- Pattern: PROMO-§001§ through PROMO-§999§
- Attack type: Sniper
- Payload: Number range 001-999
- Check for: 200 responses with discount applied

INDICATORS OF VULNERABILITY:
- Multiple discounts applied to single order
- Expired codes accepted
- Self-referral bonus awarded
- Trial limit bypassed
```

### Check 11.5: Feature Abuse (Legitimate Features for Unintended Purposes)

**Tools:** Playwright + Burp
**WSTG:** WSTG-BUSL-07

```
WORKFLOW:
1. Enumerate all user-facing features
2. Consider how each feature could be misused
3. Test misuse scenarios with Playwright (UI) and Burp (API)

SPECIFIC SCENARIOS:
a) Password reset as username enumeration oracle
b) Email/notification features as spam relay
c) File export as data exfiltration (export all records)
d) Search functionality as data scraping tool
e) User profile as XSS/content injection platform
f) Invitation system as phishing vector
g) Webhook/callback URLs as SSRF vector
h) API documentation as attack surface map

PLAYWRIGHT WORKFLOW:
- Use password reset with valid/invalid emails, compare responses
- Test notification features with external email addresses
- Attempt bulk data export without admin privileges
- Use search with wildcards to enumerate records

INDICATORS OF VULNERABILITY:
- Different error messages for valid/invalid usernames
- Notifications sent to arbitrary external addresses
- Unlimited data export without pagination or rate limiting
- Search returns excessive data without access controls
```

### Check 11.6: Data Integrity (Modify Read-Only Fields in Transit)

**Tools:** Burp Repeater
**WSTG:** WSTG-BUSL-02, WSTG-BUSL-03

```
WORKFLOW:
1. Capture legitimate update/create requests via Burp Proxy
2. Add or modify fields that should be server-controlled
3. Send modified requests via Burp Repeater
4. Check if server accepted the unauthorized modifications

FIELDS TO TAMPER:
| Category          | Fields to Add/Modify                          |
|-------------------|-----------------------------------------------|
| Pricing           | price, unit_price, total, subtotal, tax        |
| Permissions       | role, isAdmin, permissions, access_level       |
| Ownership         | user_id, owner_id, created_by, tenant_id       |
| Status            | status, state, verified, approved, is_active   |
| Timestamps        | created_at, updated_at, expires_at             |
| Computed values   | balance, score, rating, rank                   |

BURP REPEATER WORKFLOW:
- Original: {"name": "John", "email": "john@test.com"}
- Tampered: {"name": "John", "email": "john@test.com", "role": "admin", "balance": 999999}
- Check: Did the server ignore the extra fields or apply them?

INDICATORS OF VULNERABILITY:
- Server accepts and persists unauthorized field changes
- User can modify their own role/permissions
- Price can be set by client-side request
- Read-only timestamps can be overwritten
```

### Check 11.7: Process Timing (Timing-Based Logic Flaws)

**Tools:** Burp Intruder
**WSTG:** WSTG-BUSL-04

```
WORKFLOW:
1. Identify time-dependent operations (expiring tokens, limited-time offers, auction bids)
2. Test boundary conditions around time limits
3. Measure response timing for information leakage

SPECIFIC TESTS:
a) Use expired invitation/token -- does it still work within a grace period?
b) Submit bid after auction closes -- race between close and submit
c) Use time-limited discount after expiry (clock skew exploitation)
d) TOCTOU: Check eligibility then delay action -- does re-check occur?
e) Session timeout: Submit request after idle timeout -- does it process?

BURP INTRUDER TIMING ANALYSIS:
- Send same request with timestamps at boundary (expiry - 1s, expiry, expiry + 1s)
- Compare response times for valid vs. invalid tokens (timing oracle)
- Test timezone handling (submit with different TZ offsets)

INDICATORS OF VULNERABILITY:
- Expired tokens accepted within grace period
- No server-side time validation (client time trusted)
- Timing differences reveal token validity
- TOCTOU gap allows unauthorized operations
```

### Check 11.8: File Upload Logic (Unexpected Types and Sizes)

**Tools:** Burp Repeater
**WSTG:** WSTG-BUSL-08, WSTG-BUSL-09

```
WORKFLOW:
1. Identify all file upload endpoints
2. Test with unexpected file types and sizes
3. Test filename manipulation
4. Test processing logic (what happens after upload)

SPECIFIC TESTS:
a) Upload file exceeding stated size limit
b) Upload file type not in allowlist (e.g., .exe where only .pdf expected)
c) Upload empty file (0 bytes)
d) Upload file with no extension
e) Upload file with double extension (.pdf.exe)
f) Upload file with null byte in name (file.pdf%00.exe)
g) Upload very long filename (255+ characters)
h) Upload file with special characters in name (../../etc/passwd)
i) Upload same file twice -- does deduplication work correctly?
j) Upload while quota exceeded -- does it fail gracefully?

BURP REPEATER WORKFLOW:
- Modify Content-Type header (image/jpeg -> application/x-php)
- Modify filename in Content-Disposition
- Modify file content while keeping valid headers
- Send multipart request with missing boundary

INDICATORS OF VULNERABILITY:
- Server accepts files exceeding size limit
- Dangerous file types not rejected
- Filename traversal succeeds
- Processing errors expose internal paths
- No virus/malware scanning on uploaded files
```

### Check 11.9: Function Use Limits (Rate Limits on Business Functions)

**Tools:** Burp Intruder
**WSTG:** WSTG-BUSL-05

```
WORKFLOW:
1. Identify business functions with intended limits (free tier, trial, quotas)
2. Test if limits are enforced server-side
3. Test if limits can be bypassed

SPECIFIC TESTS:
a) Free tier API calls: Send requests beyond the stated limit
b) Daily/monthly quotas: Send requests after quota exhausted
c) Per-user limits: Test if creating new session bypasses limit
d) Feature gating: Access premium features with free account token
e) Export limits: Export more records than allowed

BURP INTRUDER CONFIGURATION:
- Send N+10 requests where N is the stated limit
- Monitor for: 429 responses, error messages, silent acceptance
- Test with different session tokens to check per-session vs per-user limits
- Test with different IP addresses (via X-Forwarded-For) to check IP-based limits

INDICATORS OF VULNERABILITY:
- Limits not enforced (all requests succeed)
- Limits enforced client-side only (API accepts unlimited)
- Limits reset by session/cookie change
- Premium features accessible without subscription check
```

---

## Tier 2: AI Judgment Questions

After completing Tier 0 and Tier 1 checks, evaluate these contextual questions:

### Question 1: State Machine Integrity
Does the application enforce a proper state machine for multi-step workflows? Can any step be skipped, repeated, or executed out of order? Are state transitions validated server-side with each request?

### Question 2: Atomicity of Critical Operations
Are financial transactions, inventory operations, and limit-enforced actions implemented atomically? Could concurrent requests exploit a read-modify-write gap? Is there evidence of database transactions or distributed locks?

### Question 3: Trust Boundary for Numeric Values
Does the server independently calculate all prices, totals, taxes, and discounts? Or does it trust any numeric values submitted by the client? Are there server-side bounds checks on all numeric inputs?

### Question 4: Negative Path Coverage
Has the application been designed to handle negative/zero/overflow values in all numeric fields? Are there explicit validation rules that reject values outside business-valid ranges?

### Question 5: Time-Based Security
Are all time-dependent operations validated against server time (not client time)? Are expiring tokens checked at execution time (not just at initial validation)? Is there TOCTOU protection for time-sensitive operations?

### Question 6: Abuse Case Modeling
Is there evidence of abuse case modeling (password reset enumeration, notification spam, data scraping)? Do legitimate features have safeguards against misuse (rate limits, CAPTCHA, monitoring)?

### Question 7: Idempotency
Are critical operations idempotent or protected against replay? Can the same request be submitted multiple times with different outcomes each time? Are idempotency keys used for financial operations?

### Question 8: Data Integrity Enforcement
Does the server enforce data integrity by ignoring client-submitted values for server-controlled fields (role, balance, timestamps)? Is there evidence of allowlisting accepted fields vs. blocklisting dangerous ones?

---

## Severity Classification

### Critical (P1) -- Score: 0/10
- Race condition allowing unlimited fund/credit generation
- Complete workflow bypass allowing unauthorized actions (e.g., skip payment)
- Negative quantity/price manipulation creating refunds or credits
- Business rule bypass with financial impact (unlimited discounts)

### High (P2) -- Score: 2/10
- Partial workflow bypass (skip non-critical steps)
- Data integrity violation allowing role/permission escalation
- Feature abuse enabling mass data exfiltration
- Function use limit bypass on paid features

### Medium (P3) -- Score: 5/10
- Non-financial race conditions (duplicate votes, duplicate entries)
- Promo code reuse with limited impact
- Timing-based logic flaws with narrow exploitation window
- File upload logic issues without code execution risk

### Low (P4) -- Score: 7/10
- Function use limits enforced inconsistently
- Minor data integrity issues (modifiable non-sensitive fields)
- Theoretical race conditions with no practical exploit path
- Missing idempotency on non-critical operations

---

## False Positive Indicators

1. **Intentional Design:** Some applications intentionally allow multiple discount codes or flexible workflows. Verify with product owner before flagging.
2. **Rate-Limited Race Conditions:** If the application has rate limiting that prevents parallel requests at the infrastructure level, race condition findings may be false positives.
3. **Idempotent APIs:** APIs that return the same result for duplicate requests (GET operations, idempotent PUT) are not vulnerable to replay.
4. **Optimistic UI:** Some applications show optimistic updates client-side but validate server-side. Check the actual server response and database state, not just the UI.
5. **Computed Fields:** Some APIs accept extra fields but silently ignore them (mass assignment protection). Verify by checking the actual database record, not just the API response.
6. **Staged Environments:** Race conditions that only succeed in local/dev environments due to removed concurrency controls may not reproduce in production with proper database clustering.

---

## Remediation

### Workflow Bypass
- Implement server-side state machine with explicit transition validation
- Store workflow state in server session or database, never in client-side hidden fields
- Validate that all prerequisite steps are completed before allowing each step
- Use cryptographically signed step tokens that encode completed steps

### Race Conditions
- Use database transactions with appropriate isolation level (SERIALIZABLE for financial operations)
- Implement optimistic locking with version counters on contested resources
- Use atomic database operations (UPDATE ... WHERE balance >= amount)
- Apply distributed locks (Redis SETNX) for cross-service operations
- Use idempotency keys for all financial/mutating operations

### Numeric Manipulation
- Validate all numeric inputs server-side with explicit min/max bounds
- Never trust client-submitted prices, totals, or discount amounts
- Recalculate all financial values server-side before processing
- Use decimal/BigDecimal types for currency (never floating point)
- Implement explicit rejection of negative values where not business-valid

### Business Rule Enforcement
- Store rule application state server-side (e.g., "promo code X used by user Y")
- Validate all business rules at the moment of execution, not just at input
- Implement audit logging for all business rule applications
- Use database unique constraints to prevent duplicate applications

### Data Integrity
- Use allowlisted field sets for API input (whitelist, not blacklist)
- Ignore/strip client-submitted values for server-controlled fields
- Implement field-level authorization (who can modify which fields)
- Log all field modification attempts for audit trail

### Function Use Limits
- Enforce limits server-side with atomic counter operations
- Use per-user (not per-session) limit tracking
- Store usage counts in database with atomic increments
- Return clear 429/402 responses when limits are exceeded
- Implement grace period alerts before hard cutoff
