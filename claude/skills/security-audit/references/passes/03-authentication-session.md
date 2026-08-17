# Pass 03: Authentication & Session Security

**Weight:** 12% of Security Score
**OWASP Mapping:** A07:2025 (Authentication Failures), WSTG-ATHN-01 through WSTG-ATHN-10, WSTG-SESS-01 through WSTG-SESS-09
**Focus:** Authentication mechanisms (login, registration, password reset, MFA), session management (cookies, tokens, timeouts), and identity security (JWT, OAuth). Authentication failures are the #7 risk in OWASP 2025 with 36 mapped CWEs.
**Automation Level:** 60% fully automated, 30% AI-assisted, 10% manual judgment

---

## Tier 0: Static Analysis

### 0.1 Password Hashing Algorithm Check

Verify the application uses secure password hashing (bcrypt, argon2, scrypt) and not weak algorithms.

**Grep patterns:**

```
# Secure hashing (GOOD — verify these exist)
pattern: (bcrypt|argon2|scrypt|pbkdf2|PBKDF2)
glob: "*.{js,ts,py,php,rb,java,go}"

# Insecure hashing (BAD — flag these)
pattern: (md5|MD5|sha1|SHA1|sha256|SHA256)\s*\(
glob: "*.{js,ts,py,php,rb,java,go}"

# crypto.createHash with weak algorithm
pattern: createHash\s*\(\s*['"]?(md5|sha1|sha256)['"]?\)
glob: "*.{js,ts,mjs}"

# hashlib with weak algorithm (Python)
pattern: hashlib\.(md5|sha1|sha256)\s*\(
glob: "*.py"

# Direct hash usage without salt indicator
pattern: (\.hash\s*\(|hash_password|hashPassword|password_hash)
glob: "*.{js,ts,py,php,rb}"
```

**Critical findings:**
- MD5 or SHA1 used for password hashing = Critical
- SHA256 without salt/key stretching = High
- No password hashing found at all = Critical (plaintext storage suspected)

### 0.2 JWT Implementation Analysis

Check JWT configuration for known vulnerability patterns.

**Grep patterns:**

```
# JWT library usage
pattern: (jsonwebtoken|jose|jwt|JWT|PyJWT|pyjwt|firebase-admin)
glob: "*.{js,ts,py,php,rb}"

# Algorithm specification (check for 'none' or missing validation)
pattern: (algorithm|algorithms)\s*[:=]\s*['"]?(none|HS256|RS256)
glob: "*.{js,ts,py,php}"

# JWT verify without algorithm restriction
pattern: jwt\.(verify|decode)\s*\(
glob: "*.{js,ts,mjs}"

# JWT sign
pattern: jwt\.sign\s*\(
glob: "*.{js,ts,mjs}"

# Weak JWT secrets
pattern: (JWT_SECRET|jwt_secret|TOKEN_SECRET|token_secret)\s*[:=]\s*['"][^'"]{1,15}['"]
glob: "*.{js,ts,py,php,env}"

# Missing expiration
pattern: (expiresIn|exp|expiration)
glob: "*.{js,ts,py,php}"
```

**Critical findings:**
- `algorithm: 'none'` accepted = Critical
- JWT secret shorter than 32 characters = High
- Missing `expiresIn` / `exp` claim = High
- `jwt.decode()` used instead of `jwt.verify()` = Critical

### 0.3 Session Configuration

Check session middleware configuration for secure defaults.

**Grep patterns:**

```
# Express session config
pattern: (express-session|cookie-session|session\s*\(\s*\{)
glob: "*.{js,ts,mjs}"

# Session timeout settings
pattern: (maxAge|rolling|resave|saveUninitialized|cookie\s*:\s*\{)
glob: "*.{js,ts,mjs}"

# Session store (should not be MemoryStore in production)
pattern: (MemoryStore|memory|connect-mongo|connect-redis|connect-pg)
glob: "*.{js,ts,mjs}"

# Django session settings
pattern: (SESSION_COOKIE_AGE|SESSION_EXPIRE_AT_BROWSER_CLOSE|SESSION_COOKIE_SECURE|SESSION_COOKIE_HTTPONLY)
glob: "**/settings.py"

# Laravel session config
pattern: (lifetime|expire_on_close|encrypt|secure|http_only|same_site)
glob: "**/session.php"

# Session regeneration
pattern: (regenerate|regenerateId|session_regenerate_id|rotateSession)
glob: "*.{js,ts,py,php}"
```

**Critical findings:**
- MemoryStore used in production = High (no session persistence, no scaling)
- `secure: false` for cookies on HTTPS site = High
- `httpOnly: false` for session cookies = High
- No session regeneration after login = Medium

### 0.4 Hardcoded Credentials

Search for hardcoded usernames, passwords, and authentication bypasses in source code.

**Grep patterns:**

```
# Hardcoded credentials
pattern: (admin_password|default_password|master_password|root_password)\s*[:=]\s*['"]
glob: "*.{js,ts,py,php,rb,java,go,yml,yaml}"

# Backdoor patterns
pattern: (backdoor|bypass|skip_auth|disable_auth|no_auth|auth_bypass)
glob: "*.{js,ts,py,php,rb}"

# Test/demo credentials left in code
pattern: (testuser|testpass|demouser|demopass|admin123|password123)
glob: "*.{js,ts,py,php,rb,json}"

# Commented-out auth checks
pattern: (//\s*(if|check).*auth|#\s*(if|check).*auth)
glob: "*.{js,ts,py,php}"
```

### 0.5 Password Reset Implementation

Check password reset flow for security issues.

**Grep patterns:**

```
# Reset token generation
pattern: (resetToken|reset_token|passwordResetToken|forgotPassword|forgot_password)
glob: "*.{js,ts,py,php,rb}"

# Token generation method (should use crypto-secure random)
pattern: (randomBytes|crypto\.random|secrets\.token|uuid|Math\.random)
glob: "*.{js,ts,py,php}"

# Token expiration
pattern: (resetExpire|tokenExpiry|reset_expires|expires_at|expiresAt)
glob: "*.{js,ts,py,php}"

# Password reset email
pattern: (sendPasswordReset|send_reset_email|resetPasswordEmail|mailer.*reset)
glob: "*.{js,ts,py,php}"
```

**Critical findings:**
- `Math.random()` used for token generation = Critical (predictable)
- No token expiration = High
- Token not single-use = Medium

---

## Tier 1: Automated Scanning

### 1.1 Credential Transport Security

**Purpose:** Verify all authentication requests are transmitted over HTTPS.

**Burp Proxy Workflow:**
1. Navigate to login page with Playwright
2. Submit login form with test credentials
3. Verify in Burp proxy that ALL auth-related requests use HTTPS
4. Check for mixed content (login page on HTTPS but form action on HTTP)

**Playwright Commands:**
```
browser_navigate → {target}/login
browser_evaluate → {
  const forms = document.querySelectorAll('form');
  return Array.from(forms).map(f => ({
    action: f.action,
    method: f.method,
    isHTTPS: f.action.startsWith('https://') || f.action.startsWith('/'),
    hasPasswordField: !!f.querySelector('input[type="password"]')
  }));
}
```

**Check for:**
- Form action using HTTP instead of HTTPS
- Login page loaded over HTTP
- Credentials in URL query string (GET request for login)
- Autocomplete not disabled on password fields (browser caching)

### 1.2 Brute Force Protection

**Purpose:** Verify account lockout or rate limiting after failed login attempts.

**Burp Intruder Workflow (RATE-LIMITED — max 10 attempts):**
1. Capture a valid login request in Burp proxy
2. Configure Intruder with the login endpoint
3. Use Sniper attack with 10 incorrect password payloads
4. Set 3-second delay between requests
5. Analyze responses for lockout indicators

**Expected behavior after 5-10 failures:**
- 429 Too Many Requests response
- Account lockout message
- CAPTCHA challenge
- Increasing delay between allowed attempts
- Temporary IP block

**What to record:**
- Number of attempts before lockout triggers
- Type of lockout (account-based vs IP-based)
- Lockout duration
- Whether lockout message reveals if account exists

### 1.3 Username Enumeration

**Purpose:** Detect if the application reveals whether a username/email exists through response differences.

**Burp Intruder Workflow:**
1. Send login request with known valid username + wrong password
2. Send login request with definitely invalid username + wrong password
3. Compare responses using Burp Comparer

**Comparison points:**
- Response body content (different error messages)
- Response length (byte-level difference)
- Response time (timing side channel)
- HTTP status code differences
- Set-Cookie header differences

**Test on multiple endpoints:**
```
POST /login — "Invalid password" vs "User not found"
POST /register — "Email already taken" vs success
POST /forgot-password — "Reset email sent" vs "User not found"
GET /api/users/check?email=test@example.com — existence check APIs
```

**Severity:** Medium if different error messages. Low if only timing difference.

### 1.4 Password Policy Strength

**Purpose:** Verify the application enforces a strong password policy.

**Playwright Form Testing Workflow:**
1. Navigate to registration or password change page
2. Test a series of weak passwords

**Test passwords:**
```
a             — Single character (too short)
12345678      — Numbers only (no complexity)
password      — Common password
aaaaaaaaa     — Single character repeated
Aa1!          — Strong characters but too short (4 chars)
abcdefghijklm — Long but lowercase only
Password1     — No special character
```

**Playwright Commands:**
```
browser_navigate → {target}/register (or /change-password)
browser_fill → password field with test password
browser_click → submit button
browser_evaluate → {
  // Check for client-side validation messages
  const errors = document.querySelectorAll('[class*="error"], [class*="invalid"], [role="alert"]');
  return Array.from(errors).map(e => e.textContent.trim());
}
```

**Expected password policy (minimum):**
- Minimum 8 characters (12+ recommended)
- Mixed case required
- At least one number
- At least one special character
- Not in common password list (e.g., Have I Been Pwned API)

### 1.5 MFA Bypass Testing

**Purpose:** Verify MFA cannot be bypassed through common techniques.

**Burp Repeater + Playwright Workflow:**
1. Complete first factor authentication
2. At MFA prompt, capture the request in Burp
3. Test bypass techniques:

**Bypass tests:**
```
# Skip MFA step — go directly to authenticated page
browser_navigate → {target}/dashboard (after first factor, skip MFA)

# Force browse past MFA
# Modify MFA verification request (Burp Repeater):
# - Remove MFA token parameter
# - Send empty MFA token
# - Send previously used MFA token
# - Change response from 403 to 200 (response manipulation)

# Check for MFA status in JWT/cookie
# Decode session token, look for mfa_verified: false
# Try modifying to mfa_verified: true
```

**Severity:** Critical if any bypass succeeds.

### 1.6 Session ID Entropy

**Purpose:** Verify session tokens are generated with sufficient randomness.

**Burp Sequencer Workflow:**
1. Collect at least 100 session tokens from the login endpoint
2. Submit tokens to Burp Sequencer for statistical analysis
3. Analyze character-level and bit-level randomness
4. Check for patterns or predictability

**Automated collection (Burp Intruder):**
1. Configure Intruder to send login requests repeatedly
2. Extract `Set-Cookie` values from responses
3. Feed extracted tokens to Sequencer

**Requirements:**
- Minimum 64 bits of entropy
- Token length minimum 16 hex characters (128 bits recommended)
- Generated by CSPRNG (crypto.randomBytes, secrets module)
- No sequential or time-based components

**Severity:** Critical if entropy < 64 bits. High if patterns detected.

### 1.7 Session Fixation

**Purpose:** Verify the application regenerates session IDs after authentication.

**Burp Repeater Workflow:**
1. Visit the application unauthenticated — capture session cookie
2. Record the pre-authentication session ID
3. Log in with valid credentials
4. Compare pre-auth and post-auth session IDs

**Test procedure:**
```
# Step 1: Get pre-auth session
GET {target}/ HTTP/1.1
→ Set-Cookie: session=PRE_AUTH_TOKEN

# Step 2: Login with pre-auth session
POST {target}/login HTTP/1.1
Cookie: session=PRE_AUTH_TOKEN
→ Check if Set-Cookie issues a NEW token

# Step 3: Fixation attack
# If session is not regenerated:
# Attacker sets victim's session cookie to KNOWN_VALUE
# Victim logs in
# Attacker uses KNOWN_VALUE to access victim's session
```

**Severity:** High if session ID is not regenerated after login.

### 1.8 Session Timeout

**Purpose:** Verify both idle timeout and absolute timeout are enforced.

**Playwright Time-Based Workflow:**
1. Log in and record the session token
2. Wait for the idle timeout period (check application config)
3. Attempt to use the session after timeout
4. Verify the session is invalidated

**Playwright Commands:**
```
browser_navigate → {target}/login
# Complete login flow
browser_navigate → {target}/dashboard
# Verify authenticated
# Wait for idle timeout (if known — check session config from Tier 0)
# Then attempt access
browser_navigate → {target}/dashboard
# Should redirect to login
```

**Expected timeouts:**
- High-value applications (financial, medical): 2-5 minute idle timeout
- Standard applications: 15-30 minute idle timeout
- Absolute timeout: 4-8 hours regardless of activity

**Severity:** Medium if no idle timeout. High for high-value apps without short timeout.

### 1.9 Logout Completeness

**Purpose:** Verify that logout invalidates the session server-side, not just client-side.

**Burp Repeater Workflow:**
1. Log in and capture the session token
2. Perform logout action
3. Attempt to reuse the old session token

```
# Step 1: Login → capture session token
POST {target}/login → Set-Cookie: session=VALID_TOKEN

# Step 2: Logout
POST {target}/logout
Cookie: session=VALID_TOKEN

# Step 3: Reuse old token
GET {target}/dashboard
Cookie: session=VALID_TOKEN
→ Should return 401/403 or redirect to login
→ If returns 200 with authenticated content = FAIL
```

**Also check:**
- `Clear-Site-Data` header in logout response
- All related cookies cleared (not just session cookie)
- JWT: if using JWTs, check for token blacklist/revocation mechanism
- localStorage/sessionStorage: check if logout clears client-side storage

**Playwright Commands:**
```
browser_evaluate → {
  // After logout, check if storage is cleared
  return {
    localStorage: Object.keys(localStorage),
    sessionStorage: Object.keys(sessionStorage),
    cookies: document.cookie
  };
}
```

### 1.10 JWT Security

**Purpose:** Test for common JWT vulnerabilities including algorithm confusion, weak secrets, and header injection.

**Burp + Code Analysis Workflow:**

**Algorithm None Attack (Burp Repeater):**
```
# Decode existing JWT
# Modify header: {"alg": "none", "typ": "JWT"}
# Remove signature (trailing dot remains)
# Send modified token
# Also test: {"alg": "None"}, {"alg": "NONE"}, {"alg": "nOnE"}
```

**Key Confusion Attack (Burp Repeater):**
```
# If application uses RS256:
# Get the public key
# Re-sign the token using HMAC-SHA256 with the public key as the secret
# Set alg to HS256
# Send modified token
```

**Weak Secret Detection:**
```
# Capture JWT from login response
# Attempt to brute-force the HMAC secret using common passwords
# Tools: hashcat, jwt-cracker
# Check if secret is in common wordlists
```

**Header Injection:**
```
# JWK injection: Add attacker's public key in JWT header
# JKU injection: Point to attacker's key server
# KID injection: "../../../dev/null" path traversal
```

**Payload Analysis:**
```
# Decode JWT payload (base64, no key needed)
# Check for sensitive data: passwords, SSN, PII
# Check for missing exp claim
# Check for overly long expiration
# Check for missing iss/aud claims
```

### 1.11 OAuth Flow Security

**Purpose:** Test OAuth/OIDC implementation for common vulnerabilities.

**Burp Repeater Workflow:**

```
# redirect_uri manipulation
# Original: redirect_uri=https://app.com/callback
# Test: redirect_uri=https://evil.com/callback
# Test: redirect_uri=https://app.com.evil.com/callback
# Test: redirect_uri=https://app.com/callback/../evil
# Test: redirect_uri=https://app.com/callback?next=https://evil.com

# State parameter
# Remove state parameter entirely
# Reuse state parameter from previous flow
# Use empty state parameter

# Scope escalation
# Original: scope=read
# Test: scope=read write admin
# Test: scope=read%20admin

# Authorization code reuse
# Use the same authorization code twice
# The second use should be rejected
```

**Severity:** High for redirect_uri bypass. Medium for missing state parameter.

### 1.12 Cookie Attributes for Authentication

**Purpose:** Verify authentication cookies have all required security attributes.

**Burp Passive Analysis:**
1. Capture all Set-Cookie headers during authentication flow
2. Analyze each auth-related cookie

**Required attributes for session/auth cookies:**

| Attribute | Value | Finding if Missing |
|-----------|-------|-------------------|
| `Secure` | Present | High — cookie sent over HTTP |
| `HttpOnly` | Present | High — accessible to JavaScript (XSS) |
| `SameSite` | `Strict` or `Lax` | Medium — CSRF risk |
| `Path` | `/` (or appropriate scope) | Low |
| `Domain` | Not overly broad | Medium |
| `__Host-` prefix | For session cookies | Info |
| `Max-Age` | Reasonable duration | Low |

### 1.13 Remember Me Token Security

**Purpose:** Verify "remember me" functionality uses secure persistent tokens.

**Burp Analysis Workflow:**
1. Log in with "remember me" enabled
2. Capture the persistent cookie/token
3. Analyze token structure and entropy

**Checks:**
- Token should not contain the password hash
- Token should not be the same as the session ID
- Token should be a cryptographically random value
- Token should be stored hashed server-side
- Token should be bound to the specific user/device
- Token should have a reasonable maximum lifetime (30 days typical)

### 1.14 Password Reset Flow

**Purpose:** Test the complete password reset flow for security vulnerabilities.

**Burp Repeater + Playwright Workflow:**

```
# Step 1: Request reset
POST {target}/forgot-password
email=victim@example.com

# Step 2: Analyze reset token
# Check token in reset link:
# - Length (should be 32+ characters)
# - Entropy (should be random, not predictable)
# - Not derived from email/username/timestamp

# Step 3: Token reuse
# Use reset token to change password
# Try using the same token again → should fail

# Step 4: Token expiration
# Request reset token
# Wait past expiration (typically 1 hour)
# Try to use expired token → should fail

# Step 5: Multiple token requests
# Request reset twice
# Only the latest token should be valid

# Step 6: Host header poisoning
POST {target}/forgot-password
Host: evil.com
email=victim@example.com
# Check if reset link points to evil.com
```

**Playwright Commands:**
```
browser_navigate → {target}/forgot-password
browser_fill → email field
browser_click → submit
browser_evaluate → {
  // Check for timing information in response
  const responseTime = performance.now();
  const messages = document.querySelectorAll('[class*="success"], [class*="message"], [role="alert"]');
  return {
    responseTime,
    messages: Array.from(messages).map(m => m.textContent.trim())
  };
}
```

---

## Tier 2: AI Judgment

### Question 1: Authentication Architecture Appropriateness
Is the chosen authentication mechanism (session-based, JWT, OAuth) appropriate for this application type? Are there architectural concerns with the implementation?

### Question 2: Password Storage Confidence
Based on code analysis, how confident are we that passwords are stored securely? Is the hashing algorithm, salt generation, and work factor appropriate for the threat model?

### Question 3: Session Lifecycle Completeness
Does the session lifecycle cover all critical transitions: creation, regeneration after privilege change, timeout (idle + absolute), and complete invalidation on logout?

### Question 4: JWT Security Posture
If JWTs are used: Is the algorithm locked? Are secrets strong enough? Is token revocation possible? Are tokens stored securely client-side? Is the token payload minimal?

### Question 5: OAuth/OIDC Implementation Maturity
If OAuth is used: Is the implementation following current best practices (PKCE, state parameter, strict redirect URI matching)? Are there legacy grant types (implicit) still in use?

### Question 6: Account Recovery Security
Is the password reset flow resistant to account takeover? Are reset tokens sufficiently random, single-use, time-limited, and delivered securely?

### Question 7: Multi-Factor Authentication Strength
If MFA exists: Is it mandatory or optional? Can it be bypassed? Are backup codes implemented securely? Is the MFA method phishing-resistant (WebAuthn vs SMS)?

### Question 8: Credential Stuffing Resilience
Beyond rate limiting, what defenses exist against credential stuffing? Is there breach password detection, anomaly detection, or device fingerprinting?

---

## Severity Classification

### Critical
- Plaintext password storage (no hashing)
- JWT `alg: none` accepted
- JWT key confusion attack successful
- Authentication bypass (accessing protected resources without login)
- Session fixation with no regeneration
- Password reset token predictable or reusable indefinitely
- MFA bypass successful
- Hardcoded backdoor credentials in production

### High
- MD5 or SHA1 used for password hashing
- Weak JWT secret (brute-forceable)
- No brute force protection (unlimited login attempts)
- Session cookies missing `Secure` or `HttpOnly` flags
- Session not invalidated on logout (server-side)
- OAuth redirect_uri bypass
- Password reset via Host header injection
- No session timeout on high-value application
- Username enumeration via different error messages

### Medium
- SHA256 without proper key stretching for passwords
- JWT tokens with excessive expiration (> 24 hours)
- Missing MFA on administrative accounts
- Session timeout too long (> 30 minutes idle)
- Missing `SameSite` attribute on session cookies
- Weak password policy (no complexity requirements)
- Remember me token with excessive lifetime
- OAuth missing state parameter

### Low
- Password policy does not check breached passwords
- Session ID longer than necessary but still secure
- Missing `__Host-` prefix on session cookies
- OAuth state parameter present but not cryptographically bound
- Missing `Clear-Site-Data` header on logout
- Autocomplete not disabled on login forms

---

## False Positive Indicators

1. **API tokens vs session tokens** — Long-lived API tokens for service-to-service auth may legitimately have longer timeouts than user session tokens.
2. **Development credentials** — Test/demo credentials in seed scripts or test fixtures are not hardcoded credentials in production.
3. **JWT decode vs verify** — Some code paths legitimately decode JWTs without verification (e.g., reading claims before verification, or in client-side code where verification happens server-side).
4. **OAuth for SSO only** — If OAuth is used only for SSO (not API access), some grant types and flows may differ from API OAuth best practices.
5. **Passwordless authentication** — Applications using magic links or WebAuthn may not have traditional password policies. Evaluate the alternative mechanism's security instead.
6. **Rate limiting at infrastructure level** — Brute force protection may be implemented at the WAF/CDN level rather than in application code. Verify with actual testing.
7. **CSRF tokens as MFA supplement** — Some "MFA bypass" findings may be CSRF-protected endpoints that don't need MFA for every request.
8. **Short-lived JWTs with refresh tokens** — A 15-minute JWT with a secure refresh token mechanism is a valid pattern. Don't flag short JWT expiry paired with refresh as "missing session management."

---

## Remediation

### Password Hashing
```javascript
// Node.js — use bcrypt with cost factor 12+
const bcrypt = require('bcrypt');
const hash = await bcrypt.hash(password, 12);
const isValid = await bcrypt.compare(password, hash);

// Or argon2 (preferred)
const argon2 = require('argon2');
const hash = await argon2.hash(password, { type: argon2.argon2id, memoryCost: 65536, timeCost: 3 });
const isValid = await argon2.verify(hash, password);
```

### JWT Hardening
```javascript
// Lock algorithm, set expiration, use strong secret
const jwt = require('jsonwebtoken');
const token = jwt.sign(payload, process.env.JWT_SECRET, {
  algorithm: 'RS256',  // Use asymmetric if possible
  expiresIn: '15m',
  issuer: 'your-app',
  audience: 'your-app-users'
});

// Verify with algorithm restriction
const decoded = jwt.verify(token, publicKey, {
  algorithms: ['RS256'],  // NEVER allow 'none'
  issuer: 'your-app',
  audience: 'your-app-users'
});
```

### Session Security
```javascript
// Express session with secure defaults
app.use(session({
  secret: process.env.SESSION_SECRET, // 64+ character random string
  name: '__Host-sid',
  resave: false,
  saveUninitialized: false,
  store: new RedisStore({ client: redisClient }), // NOT MemoryStore
  cookie: {
    secure: true,
    httpOnly: true,
    sameSite: 'strict',
    maxAge: 30 * 60 * 1000, // 30 minutes
    path: '/'
  }
}));

// Regenerate session after login
req.session.regenerate((err) => {
  req.session.userId = user.id;
  req.session.save();
});
```

### Password Reset Security
```javascript
// Generate cryptographically secure reset token
const crypto = require('crypto');
const resetToken = crypto.randomBytes(32).toString('hex');
const hashedToken = crypto.createHash('sha256').update(resetToken).digest('hex');

// Store hashed token with expiration
await db.user.update({
  where: { email },
  data: {
    resetToken: hashedToken,
    resetExpires: new Date(Date.now() + 3600000), // 1 hour
  }
});

// Send unhashed token in email, verify by hashing submitted token
```

### Brute Force Protection
```javascript
// Rate limiting on auth endpoints
const rateLimit = require('express-rate-limit');
const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 5, // 5 attempts per window
  message: 'Too many login attempts. Please try again later.',
  standardHeaders: true,
  legacyHeaders: false,
  keyGenerator: (req) => req.body.email || req.ip, // Per-account limiting
});
app.post('/login', authLimiter, loginHandler);
```
