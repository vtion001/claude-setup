# Pass 08: Cryptography & Transport Security

**OWASP Mapping:** A04:2025 (Cryptographic Failures), WSTG-CRYP-01 through WSTG-CRYP-04
**Weight:** 8% of Security Score
**Automation Level:** 70% fully automated, 20% AI-assisted, 10% manual judgment

---

## Purpose

Evaluate the application's use of cryptographic controls to protect data in transit and at rest. This pass covers TLS configuration, cipher suite strength, certificate validation, password hashing, key management, and encryption implementation. Cryptographic failures are the #4 risk in OWASP 2025, with weak algorithms, exposed keys, and missing transport encryption being the most common findings.

---

## Tier 0: Static Analysis (Code-Level)

### 0.1 Password Hashing Algorithms

```
Grep patterns:

# SECURE hashing algorithms (expected)
pattern: "bcrypt|argon2|argon2id|argon2i|scrypt"
expected: PRESENT for password storage
context: verify these are used for password hashing (not just imported)

# INSECURE hashing for passwords
pattern: "md5|MD5\(|createHash\(['\"]md5"
severity: CRITICAL — MD5 is broken for all security purposes
pattern: "sha1|SHA1\(|createHash\(['\"]sha1"
severity: CRITICAL — SHA-1 has known collision attacks
pattern: "sha256|SHA256\(|createHash\(['\"]sha256"
severity: HIGH — SHA-256 is fast; use bcrypt/argon2 for passwords
context: SHA-256 is fine for integrity checks, NOT for password hashing
pattern: "sha512|SHA512\(|createHash\(['\"]sha512"
severity: HIGH — same as SHA-256, too fast for password hashing

# Verify proper bcrypt configuration
pattern: "bcrypt.*(?:rounds|saltRounds|cost)\s*[:=]\s*(\d+)"
expected: rounds >= 10 (12 recommended as of 2025)
flag_if: rounds < 10

# Verify proper argon2 configuration
pattern: "argon2.*(?:memoryCost|memory|timeCost|time|parallelism)"
expected: memoryCost >= 19456 (19 MiB), timeCost >= 2, parallelism >= 1
```

### 0.2 Hardcoded Secrets and API Keys

```
# Generic secret patterns
pattern: "(password|passwd|pwd|secret|token|api[_-]?key|apikey|auth[_-]?token)\s*[:=]\s*['\"][^'\"]{8,}['\"]"
severity: CRITICAL — hardcoded credentials in source code
exclude: test files, example configs, documentation

# AWS keys
pattern: "AKIA[0-9A-Z]{16}"
severity: CRITICAL — AWS Access Key ID
pattern: "[0-9a-zA-Z/+]{40}"
context: check if adjacent to AWS key patterns
severity: CRITICAL — potential AWS Secret Access Key

# Private keys
pattern: "-----BEGIN (RSA |EC |DSA |OPENSSH )?PRIVATE KEY-----"
severity: CRITICAL — private key in source code

# JWT secrets
pattern: "jwt[_-]?secret\s*[:=]\s*['\"][^'\"]+['\"]"
severity: CRITICAL — hardcoded JWT signing secret
pattern: "(sign|verify)\(.*['\"][a-zA-Z0-9]{16,}['\"]"
severity: HIGH — inline signing key

# Database connection strings with passwords
pattern: "(mongodb|postgres|mysql|redis|amqp)://[^:]+:[^@]+@"
severity: CRITICAL — database credentials in source

# Generic high-entropy strings (potential secrets)
pattern: "['\"][0-9a-f]{32,}['\"]|['\"][A-Za-z0-9+/]{32,}={0,2}['\"]"
context: verify if these are secrets vs hashes/IDs
severity: MEDIUM — review for potential secrets

# Environment variable usage (CORRECT pattern)
pattern: "process\.env\.|os\.environ|ENV\[|getenv\(|env\("
expected: PRESENT — secrets should come from environment variables
```

### 0.3 Encryption Implementation

```
# Symmetric encryption algorithms
pattern: "aes-128|aes-256|AES|createCipheriv|createDecipheriv"
context: verify AES-256-GCM or AES-256-CBC with HMAC (not ECB mode)

# INSECURE encryption modes
pattern: "ECB|aes-\d+-ecb|DES|3DES|RC4|RC2|Blowfish|IDEA"
severity: HIGH — weak/broken encryption algorithm or mode
pattern: "createCipher\(" (not createCipheriv)
severity: HIGH — deprecated, uses weak key derivation

# Check IV/nonce handling
pattern: "createCipheriv\("
context: verify IV is randomly generated (not static/hardcoded)
pattern: "iv\s*[:=]\s*['\"][^'\"]+['\"]|nonce\s*[:=]\s*['\"][^'\"]+['\"]"
severity: CRITICAL — hardcoded IV/nonce, defeats encryption security

# Asymmetric encryption
pattern: "RSA.*1024|rsa.*1024"
severity: HIGH — RSA key size too small (minimum 2048 bits)
pattern: "RSA.*4096|rsa.*4096|RSA.*2048|rsa.*2048"
expected: PRESENT for RSA usage
```

### 0.4 Key Management

```
# Key storage locations
pattern: "\.pem|\.key|\.p12|\.pfx|\.jks"
context: verify private key files are in .gitignore
severity: HIGH if committed to repository

# Key derivation functions
pattern: "pbkdf2|PBKDF2|scrypt|hkdf|HKDF"
context: verify iterations >= 600,000 for PBKDF2-HMAC-SHA256 (OWASP 2023)
pattern: "iterations\s*[:=]\s*(\d+)"
flag_if: iterations < 600000 for PBKDF2

# Random number generation
pattern: "Math\.random\(\)"
severity: CRITICAL if used for security-sensitive values (tokens, keys, IDs)
expected_instead: "crypto.randomBytes|crypto.getRandomValues|uuid|nanoid|CSPRNG"
pattern: "crypto\.randomBytes|crypto\.getRandomValues|randomUUID"
expected: PRESENT for token/key generation
```

---

## Tier 1: Automated Scanning (10 Checks)

### Check 1: TLS Version Support

**Tools:** Burp TLS analysis
**WSTG:** WSTG-CRYP-01

```
Workflow:
1. Test TLS version support on the target:
   - TLS 1.0: MUST be disabled (deprecated since 2020)
   - TLS 1.1: MUST be disabled (deprecated since 2020)
   - TLS 1.2: SHOULD be supported (minimum acceptable)
   - TLS 1.3: SHOULD be supported (recommended, best performance)

2. Burp — inspect TLS handshake details:
   - Protocol version negotiated
   - Check for SSLv2/SSLv3 support (CRITICAL if enabled)
   - Verify TLS 1.2+ is enforced

3. Test TLS downgrade protection:
   - Attempt connection with TLS 1.0 only
   - Expected: Connection refused or TLS alert
   - VULNERABLE if server accepts TLS 1.0/1.1

4. Check for TLS_FALLBACK_SCSV support:
   - Prevents protocol downgrade attacks
   - Modern servers should support this extension
```

### Check 2: Cipher Suite Strength

**Tools:** Burp TLS configuration analysis
**WSTG:** WSTG-CRYP-01

```
Workflow:
1. Enumerate supported cipher suites:

   CRITICAL (must be disabled):
   - NULL ciphers (no encryption)
   - EXPORT ciphers (40/56-bit)
   - DES/3DES ciphers
   - RC4 ciphers
   - Anonymous key exchange (aDH, aECDH)

   HIGH (should be disabled):
   - CBC mode ciphers with TLS 1.0/1.1 (BEAST vulnerability)
   - SHA-1 based HMAC (prefer SHA-256/384)
   - RSA key exchange (no forward secrecy)
   - Static DH/ECDH (no forward secrecy)

   RECOMMENDED (should be enabled):
   - TLS_AES_256_GCM_SHA384 (TLS 1.3)
   - TLS_AES_128_GCM_SHA256 (TLS 1.3)
   - TLS_CHACHA20_POLY1305_SHA256 (TLS 1.3)
   - ECDHE_RSA_AES_256_GCM_SHA384 (TLS 1.2)
   - ECDHE_RSA_AES_128_GCM_SHA256 (TLS 1.2)

2. Verify forward secrecy:
   - All cipher suites should use ECDHE or DHE key exchange
   - RSA key exchange lacks forward secrecy
   - Flag if any non-FS cipher suite is enabled

3. Check cipher suite preference:
   - Server should enforce its own cipher preference order
   - Strongest ciphers should be preferred
```

### Check 3: Certificate Validation

**Tools:** Burp + Playwright
**WSTG:** WSTG-CRYP-01

```
Workflow:
1. Certificate chain analysis:
   - Valid certificate from trusted CA
   - Complete chain (no missing intermediates)
   - Not self-signed in production
   - Key size >= 2048 bits (RSA) or >= 256 bits (ECDSA)

2. Certificate expiry:
   - Check expiration date
   - Flag if expiring within 30 days
   - Flag if already expired (CRITICAL)

3. Hostname validation:
   - Subject CN or SAN matches the target domain
   - No wildcard certificates on sensitive domains
   - No certificate mismatch warnings

4. Certificate transparency:
   - Check for SCT (Signed Certificate Timestamp)
   - Verify CT logs inclusion

5. Playwright verification:
   - Navigate to the site and check for certificate errors
   - page.goto(url) — will throw on invalid certificates
   - Check browser security indicator
```

### Check 4: Mixed Content (HTTP on HTTPS Pages)

**Tools:** Playwright browser_evaluate
**WSTG:** WSTG-CRYP-03

```
Workflow:
1. Playwright — detect mixed content on each page:
   page.evaluate(() => {
     const resources = performance.getEntriesByType('resource');
     const mixed = resources.filter(r =>
       r.name.startsWith('http://') &&
       window.location.protocol === 'https:'
     );
     return {
       total: resources.length,
       mixedContent: mixed.map(r => ({
         url: r.name,
         type: r.initiatorType,
         size: r.transferSize
       })),
       hasMixedContent: mixed.length > 0
     };
   });

2. Categorize mixed content:
   ACTIVE mixed content (HIGH):
   - Scripts loaded over HTTP (<script src="http://...">)
   - Stylesheets loaded over HTTP (<link href="http://...">)
   - Iframes loaded over HTTP
   - XHR/Fetch requests to HTTP endpoints
   
   PASSIVE mixed content (MEDIUM):
   - Images loaded over HTTP
   - Video/audio loaded over HTTP
   - Fonts loaded over HTTP

3. Check CSP upgrade-insecure-requests directive:
   - If present, browser automatically upgrades HTTP to HTTPS
   - Verify: Content-Security-Policy: upgrade-insecure-requests

4. Check for hardcoded HTTP URLs in source code:
   pattern: "http://(?!localhost|127\.0\.0\.1|0\.0\.0\.0)"
   context: verify no production HTTP URLs exist in codebase
```

### Check 5: Sensitive Data in URLs

**Tools:** Burp proxy analysis
**WSTG:** WSTG-CRYP-03

```
Workflow:
1. Burp proxy — analyze all captured URLs for sensitive data:

   CRITICAL in URLs:
   - Passwords: ?password=, ?pwd=, ?passwd=
   - API keys: ?api_key=, ?apikey=, ?key=
   - Session tokens: ?session=, ?sid=, ?token=
   - Credit card numbers
   - Social Security Numbers

   HIGH in URLs:
   - JWT tokens in query parameters
   - OAuth access tokens in URL fragments
   - Reset password tokens in GET parameters (should be POST)
   - Email addresses with sensitive context

2. Check for token leakage via Referer header:
   - If sensitive token is in URL, Referer header leaks it to third parties
   - Verify Referrer-Policy: no-referrer or strict-origin-when-cross-origin

3. Check server access logs:
   - URLs with sensitive data are logged in access logs
   - Recommend POST body for sensitive parameters

4. Check browser history exposure:
   - Sensitive data in URLs is stored in browser history
   - Recommend using POST with request body or HTTP headers
```

### Check 6: Cookie Encryption (Signed/Encrypted Sessions)

**Tools:** Burp passive analysis
**WSTG:** WSTG-CRYP-04

```
Workflow:
1. Capture all Set-Cookie headers via Burp proxy:
   For each session/auth cookie, analyze:
   - Is the cookie value opaque (encrypted/hashed)?
   - Or does it contain readable data (base64-encoded JSON)?

2. Decode cookie values:
   - Base64 decode — check for readable JSON with user data
   - Check for JWT format (three base64-encoded segments)
   - Check for serialized objects (PHP, Java, Python pickle)

3. If cookie contains readable data:
   HIGH: User credentials, PII, or role information in cookie
   MEDIUM: Non-sensitive user preferences in unsigned cookie
   Verify: Is the cookie signed (HMAC) to prevent tampering?
   Verify: Is the cookie encrypted to prevent reading?

4. Test cookie tampering:
   - Modify cookie value and replay
   - If server accepts modified cookie without validation: CRITICAL
   - If server detects tampering (signature check): PASS

5. Check session cookie entropy:
   - Burp Sequencer — analyze session ID randomness
   - Minimum 64 bits of entropy
   - Should be generated by CSPRNG
```

### Check 7: Padding Oracle Vulnerabilities

**Tools:** Burp Scanner
**WSTG:** WSTG-CRYP-02

```
Workflow:
1. Identify encrypted values in:
   - Cookie values (especially session cookies)
   - Hidden form fields
   - URL parameters with base64-like encoded values
   - API response tokens

2. Burp Scanner — active scan for padding oracle:
   - Modifies encrypted ciphertext bytes
   - Analyzes timing and error response differences
   - Detects CBC padding oracle conditions

3. Manual verification via Burp Repeater:
   - Take encrypted cookie/parameter value
   - Flip last byte of ciphertext
   - Send request and analyze response:
     - Different error for invalid padding vs invalid data = VULNERABLE
     - Same error for both = likely NOT vulnerable
     - Timing difference between padding error and decryption error = VULNERABLE

4. Check for unauthenticated encryption:
   - AES-CBC without HMAC is vulnerable to padding oracle
   - AES-GCM is authenticated (not vulnerable)
   - Verify encryption mode in source code
```

### Check 8: HSTS Enforcement

**Tools:** Burp passive analysis
**WSTG:** WSTG-CRYP-01

```
Workflow:
1. Check Strict-Transport-Security header:
   Expected: Strict-Transport-Security: max-age=63072000; includeSubDomains; preload
   
   Analyze:
   - max-age >= 31536000 (1 year minimum)
   - includeSubDomains present (prevents subdomain HTTP)
   - preload present (for HSTS preload list submission)

2. Flag HSTS issues:
   CRITICAL: No HSTS header at all
   HIGH: max-age < 31536000 (less than 1 year)
   MEDIUM: Missing includeSubDomains
   LOW: Missing preload directive
   INFO: max-age < 63072000 (less than 2 years, OWASP recommends 2 years)

3. Test HSTS behavior:
   - First request via HTTP should redirect to HTTPS (301/302)
   - HSTS header should be set on HTTPS response (not HTTP)
   - After HSTS, subsequent HTTP requests should be auto-upgraded by browser

4. Check HSTS preload eligibility:
   - Serves valid certificate
   - Redirects HTTP to HTTPS on same host
   - All subdomains served over HTTPS
   - HSTS header on base domain with includeSubDomains and preload
   - max-age >= 31536000
```

### Check 9: Key Rotation Evidence

**Tools:** Code analysis (Grep + Read)
**WSTG:** WSTG-CRYP-04

```
Workflow:
1. Check for key rotation mechanisms:
   pattern: "rotate|rotation|rollover|key[_-]version|kid|key[_-]id"
   context: verify cryptographic key rotation is implemented

2. JWT key rotation:
   - Check for JWK Set (JWKS) endpoint: /.well-known/jwks.json
   - Verify multiple keys in JWKS (current + previous for rotation)
   - Check for key ID (kid) in JWT header
   - Verify old keys are eventually removed

3. Database encryption key rotation:
   - Check for key versioning in encrypted data
   - Verify re-encryption mechanism exists
   - Check for key management service (KMS) integration:
     pattern: "aws-sdk.*kms|KMS|vault|hashicorp|azure.*keyvault"

4. API key rotation:
   - Check for key expiration mechanism
   - Verify old keys can be revoked
   - Check for key generation/regeneration endpoints

5. Certificate rotation:
   - Check for automated certificate renewal (Let's Encrypt, cert-manager)
   - pattern: "certbot|acme|cert-manager|letsencrypt"
   - Verify certificates are not manually managed
```

### Check 10: Encryption at Rest Evidence

**Tools:** Code analysis (Grep + Read)
**WSTG:** WSTG-CRYP-04

```
Workflow:
1. Check for database encryption:
   pattern: "encrypt|pgcrypto|TDE|transparent.*encrypt|ENCRYPTION_KEY"
   context: verify sensitive columns/tables are encrypted

2. Check for field-level encryption:
   pattern: "encrypt.*field|field.*encrypt|column.*encrypt"
   context: PII, healthcare data, financial data should be encrypted at rest
   Sensitive fields: SSN, credit card, health records, passwords

3. Check for file/storage encryption:
   pattern: "server.*side.*encrypt|SSE|s3.*encrypt|blob.*encrypt"
   context: verify cloud storage encryption is enabled
   pattern: "AES.*256|aes-256|kms.*encrypt"

4. Check for backup encryption:
   - Database backups should be encrypted
   - File backups should be encrypted
   - Verify backup encryption is documented or configured

5. Check for data classification:
   - Are sensitive data fields identified?
   - Is there a data classification scheme?
   - Are encryption requirements tied to data sensitivity?
```

---

## Tier 2: AI Judgment (6 Contextual Questions)

### Q1: Cryptographic Algorithm Appropriateness
Are the cryptographic algorithms used appropriate for their purpose? Is bcrypt/argon2 used for passwords (not SHA-256)? Is AES-GCM used for encryption (not ECB)? Are key sizes sufficient (RSA >= 2048, AES >= 128, ECDSA >= 256)?

### Q2: Post-Quantum Readiness Assessment
Is the application using cryptographic algorithms that will be vulnerable to quantum computing attacks? RSA and ECDSA will be broken by sufficiently powerful quantum computers. Is there a migration path to post-quantum algorithms (CRYSTALS-Kyber, CRYSTALS-Dilithium)?

### Q3: Key Management Maturity
How mature is the application's key management? Are keys stored in a dedicated KMS/HSM? Is there a documented key rotation schedule? Are keys separated by environment (dev/staging/prod)? What is the blast radius if a single key is compromised?

### Q4: Secrets Management Architecture
How are secrets (API keys, database credentials, signing keys) managed? Are they in environment variables, a secrets manager (Vault, AWS Secrets Manager), or hardcoded? Is there a centralized secrets management strategy?

### Q5: Transport Security Completeness
Is TLS enforced on ALL communication channels, not just the main web interface? Check: database connections, cache connections (Redis), message queues, internal microservice communication, webhook callbacks, email (STARTTLS).

### Q6: Encryption Scope vs Data Sensitivity
Is the encryption coverage proportionate to data sensitivity? Are the most sensitive data fields (PII, PHI, financial data) encrypted at rest? Is there sensitive data that should be encrypted but is not? Are encryption boundaries aligned with compliance requirements?

---

## Severity Classification

### Critical (P1 — Score: 0/10)
- Passwords stored in MD5, SHA-1, or unsalted SHA-256
- Hardcoded database credentials, API keys, or signing secrets in source code
- Private keys committed to version control
- TLS 1.0/1.1 enabled or SSLv3 supported
- No TLS/HTTPS enforcement (application accessible over HTTP)
- Expired or invalid SSL certificate in production
- Math.random() used for session tokens, CSRF tokens, or encryption keys

### High (P2 — Score: 2/10)
- Weak bcrypt rounds (< 10) or PBKDF2 iterations (< 600,000)
- ECB encryption mode used for any data
- Hardcoded encryption IV/nonce (static, not random)
- RSA key size < 2048 bits
- Missing HSTS header entirely
- Mixed active content (scripts/stylesheets over HTTP on HTTPS page)
- Sensitive data (tokens, API keys) in URL query parameters
- Padding oracle vulnerability confirmed

### Medium (P3 — Score: 5/10)
- HSTS max-age < 1 year
- Missing includeSubDomains on HSTS
- CBC cipher suites without forward secrecy (TLS 1.2)
- Cookie values containing readable/decodable user data without signing
- Mixed passive content (images over HTTP on HTTPS page)
- No evidence of key rotation mechanism
- SHA-256 used for password hashing (fast but not broken)

### Low (P4 — Score: 7/10)
- Missing HSTS preload directive
- Missing CT (Certificate Transparency) enforcement
- Cipher suite order not optimized (weaker ciphers preferred)
- No post-quantum readiness plan
- Encryption at rest not documented but cloud provider handles it
- Key rotation interval > 1 year but mechanism exists

---

## False Positive Indicators

### Password Hashing False Positives
- **SHA-256 in non-password context:** SHA-256 used for file integrity checksums, HMAC signatures, or content hashing is correct. Only flag when used for password storage
- **MD5 in non-security context:** MD5 used for cache keys, ETags, or non-security checksums is acceptable (though SHA-256 is preferred)
- **Test file secrets:** Hardcoded secrets in test files, fixtures, or example configs are not production risks (but flag as INFO)

### TLS False Positives
- **Internal services:** TLS 1.0/1.1 on internal-only services behind a TLS-terminating proxy may be acceptable (still recommend upgrading)
- **Development/localhost:** No TLS on localhost development is expected — only flag for staging/production
- **Legacy client support:** Some applications intentionally support TLS 1.0 for legacy client compatibility — flag but note the business justification

### Mixed Content False Positives
- **Protocol-relative URLs:** `//example.com/script.js` is not mixed content — it inherits the page protocol
- **Localhost references:** HTTP localhost references in development code are expected
- **upgrade-insecure-requests:** If CSP includes upgrade-insecure-requests, HTTP references are automatically upgraded by the browser

---

## Remediation

### Password Hashing
1. **Use bcrypt (recommended):**
   ```javascript
   const bcrypt = require('bcrypt');
   const hash = await bcrypt.hash(password, 12); // 12 rounds
   const match = await bcrypt.compare(password, hash);
   ```

2. **Use Argon2id (best, if supported):**
   ```javascript
   const argon2 = require('argon2');
   const hash = await argon2.hash(password, {
     type: argon2.argon2id,
     memoryCost: 19456, // 19 MiB
     timeCost: 2,
     parallelism: 1
   });
   ```

3. **Migration from weak hashing:**
   - On user login, verify with old algorithm
   - If valid, re-hash with bcrypt/argon2 and store new hash
   - Gradually migrate all users on next login

### Secrets Management
1. Use environment variables for all secrets
2. Implement a secrets manager (HashiCorp Vault, AWS Secrets Manager, Azure Key Vault)
3. Add `.env` to `.gitignore`
4. Use git-secrets or pre-commit hooks to prevent secret commits
5. Rotate any secrets found in source code history immediately

### TLS Configuration
1. Disable TLS 1.0 and 1.1 — require TLS 1.2 minimum
2. Prefer TLS 1.3 cipher suites
3. Enable forward secrecy (ECDHE key exchange)
4. Set HSTS with long max-age, includeSubDomains, and preload
5. Automate certificate renewal (Let's Encrypt + cert-manager)
6. Use Mozilla SSL Configuration Generator for server-specific settings

### Encryption Implementation
1. Use AES-256-GCM for symmetric encryption (authenticated encryption)
2. Generate random IV/nonce for each encryption operation
3. Use CSPRNG (crypto.randomBytes) for all random values
4. Never use ECB mode for any data
5. Implement key rotation with key versioning
