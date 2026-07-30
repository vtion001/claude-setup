# Security Audit — Burp Suite MCP Workflow Sequences

Reusable Burp Suite MCP tool call sequences for the `/security-audit` skill. Each workflow is a
step-by-step procedure that can be invoked during the relevant audit pass.

**Important:** All workflows must respect the rate limits and safety guardrails defined in
`references/safety-guardrails.md`. Never send destructive payloads. Always log every request.

---

## Workflow 0: Connection Setup & Pre-flight Verification

**Used by:** Run once before Phase 5 (Passive) / Phase 6 (Active) whenever Burp MCP tools are needed.
**Purpose:** Confirm the Burp Suite MCP server is reachable and its tools are loaded before scanning.
**Safety:** Read-only connectivity checks. No payloads.

### Burp MCP server config (`.mcp.json`)

```json
{ "mcpServers": { "burp": { "type": "sse", "url": "http://127.0.0.1:9876" } } }
```

- **URL must be the root path, not `/sse`.** Burp's MCP extension (Burp → Settings → Extensions → MCP) serves the SSE handshake at `/` — a GET returns `event: endpoint` / `data: ?sessionId=...`. Pointing at `/sse` returns `404` and the `burp` tools fail to load with no obvious error.
- **MCP servers load only at Claude Code startup.** After editing `.mcp.json`, restart the session before the tools appear; mid-session edits do not hot-reload.

### Steps

1. **Reachability pre-flight (curl)**
   ```bash
   curl -s --max-time 5 http://127.0.0.1:9876/ | head -3
   ```
   - `event: endpoint` + `sessionId`  → server up, correct path → proceed
   - `404 Not Found`                   → wrong path; ensure `.mcp.json` url is root (`:9876`), not `/sse`
   - `000` / connection refused        → server unreachable (see WSL note below, or start Burp's MCP server)

2. **WSL → Windows host (if applicable)**
   When Burp runs on Windows and Claude Code runs in WSL, default NAT networking cannot reach
   `127.0.0.1:9876` on the Windows side. Enable mirrored networking:
   ```ini
   # ~/.wslconfig  (Windows user profile)
   [wsl2]
   networkingMode=mirrored
   ```
   Then run `wsl --shutdown` from Windows and restart. **Fallback** (if mirrored mode can't apply):
   Windows `netsh portproxy` `0.0.0.0:9876` → `127.0.0.1:9876` plus a firewall allow rule, and point
   `.mcp.json` at the WSL gateway IP (e.g. `172.21.144.1:9876`) instead of `127.0.0.1`.

3. **Confirm tools are loaded**
   After restart, search the loaded tools for `burp scanner intruder collaborator`. If they are absent,
   re-check the `.mcp.json` URL (step 1) — a `/sse` path is the most common cause of silent non-loading.

4. **Disposable DB reminder**
   Active scanning writes junk records (sessions, PII) into the target app's database. Point the app at a
   **disposable local DB** before Phase 6 — never run an active scan against a database you care about.

---

## Workflow 1: Passive Traffic Analysis

**Used by:** All passes during Phase 5 (Passive Scanning)
**Purpose:** Intercept and analyze traffic without sending any additional requests.
**Safety:** Completely safe — no attack payloads sent.

### Steps

1. **Configure Burp Proxy**
   ```
   Tool: burp_proxy_configure
   Input:
     listener_port: 8080
     intercept_mode: "passive"  # Do not modify or hold requests
     scope: "{APP_URL}"
   Expected: Proxy listener active on 127.0.0.1:8080
   ```

2. **Route Playwright through Burp Proxy**
   ```
   Tool: playwright browser_navigate
   Input:
     url: "{APP_URL}"
     proxy: "http://127.0.0.1:8080"
   Expected: Page loads, traffic flows through Burp
   ```

3. **Navigate through application pages**
   For each discovered route:
   ```
   Tool: playwright browser_navigate
   Input:
     url: "{APP_URL}{route}"
   Expected: Page loads, Burp captures request/response
   ```

4. **Capture passive scan results**
   ```
   Tool: burp_scanner_get_findings
   Input:
     scan_type: "passive"
     scope: "{APP_URL}"
   Expected: JSON array of passive findings (missing headers, cookie issues, info disclosure)
   ```

5. **Export sitemap**
   ```
   Tool: burp_target_get_sitemap
   Input:
     scope: "{APP_URL}"
   Expected: Complete sitemap of discovered endpoints with request/response pairs
   ```

6. **Analyze results**
   For each finding:
   - Map to OWASP ID and CWE
   - Determine severity
   - Cross-reference with Tier 0 source code analysis
   - Filter false positives based on context

---

## Workflow 2: Active Scan

**Used by:** Passes 02-15 during Phase 6 (Active Scanning)
**Purpose:** Run Burp active scanner on specific endpoints with crafted payloads.
**Safety:** Requires authorization. Rate-limited. No destructive payloads.

### Pre-flight Checks

1. Verify authorization level permits active scanning
2. Confirm rate limit is set (default varies by target type)
3. Display confirmation prompt to user
4. Wait for user approval

### Steps

1. **Define scan scope**
   ```
   Tool: burp_scanner_configure
   Input:
     target_url: "{APP_URL}"
     scope_includes: ["{APP_URL}/*"]
     scope_excludes: ["/logout", "/delete-account", "/admin/reset"]
     max_requests_per_second: {RATE_LIMIT}
     scan_type: "active"
     follow_redirects: true
     max_crawl_depth: 5
   Expected: Scanner configured with scope and rate limits
   ```

2. **Set scan policy (exclude destructive checks)**
   ```
   Tool: burp_scanner_set_policy
   Input:
     enabled_checks: [
       "sql_injection",
       "xss_reflected",
       "xss_stored",
       "path_traversal",
       "command_injection",
       "ssti",
       "ssrf",
       "xxe",
       "header_injection",
       "open_redirect",
       "cors_misconfiguration",
       "information_disclosure"
     ]
     disabled_checks: [
       "dos_testing",
       "brute_force",
       "file_upload_exploit"
     ]
     payload_options:
       max_payload_length: 500
       exclude_destructive: true  # Critical safety flag
   Expected: Scan policy applied
   ```

3. **Start active scan**
   ```
   Tool: burp_scanner_start
   Input:
     target_url: "{APP_URL}"
     credentials:
       type: "{AUTH_METHOD}"
       token: "{AUTH_TOKEN}"
   Expected: Scan ID returned, scan begins
   ```

4. **Monitor scan progress**
   ```
   Tool: burp_scanner_get_status
   Input:
     scan_id: "{SCAN_ID}"
   Expected: Progress percentage, current phase, requests sent, findings count
   ```
   Repeat every 10 seconds until complete.

5. **Retrieve findings**
   ```
   Tool: burp_scanner_get_findings
   Input:
     scan_id: "{SCAN_ID}"
     min_confidence: "tentative"
   Expected: JSON array of findings with severity, confidence, evidence
   ```

6. **For each finding, get detailed evidence**
   ```
   Tool: burp_scanner_get_finding_detail
   Input:
     finding_id: "{FINDING_ID}"
   Expected: Full request/response, payload used, detection method, remediation advice
   ```

---

## Workflow 3: Intruder Sniper Attack

**Used by:** Pass 04 (Authorization IDOR), Pass 05 (Injection), Pass 13 (Error Handling)
**Purpose:** Test a single parameter position with a payload list.
**Safety:** Rate-limited. Payloads are detection-only, not destructive.

### Steps

1. **Capture base request**
   ```
   Tool: burp_proxy_get_request
   Input:
     url: "{TARGET_ENDPOINT}"
     method: "{HTTP_METHOD}"
   Expected: Full HTTP request with headers and body
   ```

2. **Configure Intruder**
   ```
   Tool: burp_intruder_configure
   Input:
     attack_type: "sniper"
     base_request: "{CAPTURED_REQUEST}"
     positions: [
       {
         parameter: "{PARAM_NAME}",
         location: "{url_param|body_param|header|cookie}",
         markers: ["{START_MARKER}", "{END_MARKER}"]
       }
     ]
     rate_limit: {RATE_LIMIT}
   Expected: Intruder configured with single position
   ```

3. **Load payload list**
   ```
   Tool: burp_intruder_set_payloads
   Input:
     position: 0
     payload_type: "simple_list"
     payloads: [
       # For IDOR testing:
       "1", "2", "3", "100", "999", "0", "-1", "null", "undefined",
       # For SQLi detection:
       "'", "''", "1' OR '1'='1", "1' AND '1'='2", "1; SELECT 1--",
       "1' AND SLEEP(5)--",
       # For path traversal:
       "../../../etc/hostname", "....//....//etc/hostname",
       # Choose appropriate list based on pass
     ]
   Expected: Payloads loaded
   ```

4. **Start attack**
   ```
   Tool: burp_intruder_start
   Expected: Attack ID returned
   ```

5. **Monitor and collect results**
   ```
   Tool: burp_intruder_get_results
   Input:
     attack_id: "{ATTACK_ID}"
   Expected: Array of results with payload, status code, response length, response time
   ```

6. **Analyze results for anomalies**
   Compare response codes, lengths, and times across all payloads.
   - Status code change = potential finding
   - Response length change = potential data leak
   - Response time increase (>5s) = potential blind injection
   - Different error message = potential enumeration vector

---

## Workflow 4: Intruder Battering Ram Attack

**Used by:** Pass 03 (Auth — testing same credential across multiple fields)
**Purpose:** Send the same payload to all marked positions simultaneously.
**Safety:** Rate-limited. Limited to 10 attempts for auth testing.

### Steps

1. **Capture login request**
   ```
   Tool: burp_proxy_get_request
   Input:
     url: "{LOGIN_ENDPOINT}"
     method: "POST"
   Expected: Login request with username/password fields
   ```

2. **Configure Intruder**
   ```
   Tool: burp_intruder_configure
   Input:
     attack_type: "battering_ram"
     base_request: "{LOGIN_REQUEST}"
     positions: [
       { parameter: "username", location: "body_param" },
       { parameter: "password", location: "body_param" }
     ]
     rate_limit: 1  # 1 req/sec for auth testing
     max_requests: 10  # Hard limit for safety
   Expected: Intruder configured with battering ram mode
   ```

3. **Load default credential payloads**
   ```
   Tool: burp_intruder_set_payloads
   Input:
     position: "all"  # Same payload to all positions
     payload_type: "simple_list"
     payloads: [
       "admin", "test", "user", "root", "demo",
       "password", "123456", "admin123", "default", "guest"
     ]
   Expected: Payloads loaded
   ```

4. **Start attack**
   ```
   Tool: burp_intruder_start
   Expected: Attack ID returned
   ```

5. **Analyze for successful login indicators**
   ```
   Tool: burp_intruder_get_results
   Input:
     attack_id: "{ATTACK_ID}"
   Expected: Results — look for 302 redirects, session cookies, different response lengths
   ```

---

## Workflow 5: Repeater Request Modification

**Used by:** All passes for manual verification of findings
**Purpose:** Manually modify and resend individual requests to verify vulnerabilities.
**Safety:** Single requests only. Human-directed.

### Steps

1. **Send request to Repeater**
   ```
   Tool: burp_repeater_send
   Input:
     method: "{METHOD}"
     url: "{FULL_URL}"
     headers: {
       "Authorization": "Bearer {TOKEN}",
       "Content-Type": "application/json",
       "{CUSTOM_HEADER}": "{CUSTOM_VALUE}"
     }
     body: "{REQUEST_BODY}"
   Expected: Full response with status, headers, body, timing
   ```

2. **Modify and resend (example: auth bypass test)**
   ```
   Tool: burp_repeater_send
   Input:
     method: "GET"
     url: "{ADMIN_ENDPOINT}"
     headers: {
       # Omit Authorization header to test unauthenticated access
       "Content-Type": "application/json"
     }
   Expected: Should return 401/403. If 200 — finding confirmed.
   ```

3. **Modify and resend (example: IDOR test)**
   ```
   Tool: burp_repeater_send
   Input:
     method: "GET"
     url: "/api/users/{OTHER_USER_ID}/profile"
     headers: {
       "Authorization": "Bearer {CURRENT_USER_TOKEN}"
     }
   Expected: Should return 403. If 200 with other user data — IDOR confirmed.
   ```

4. **Modify and resend (example: header injection)**
   ```
   Tool: burp_repeater_send
   Input:
     method: "GET"
     url: "{TARGET_URL}"
     headers: {
       "Host": "evil.com",
       "X-Forwarded-Host": "evil.com",
       "X-Forwarded-For": "127.0.0.1"
     }
   Expected: Check if response reflects injected host
   ```

5. **Compare responses**
   ```
   Tool: burp_comparer_diff
   Input:
     request_1: "{ORIGINAL_RESPONSE}"
     request_2: "{MODIFIED_RESPONSE}"
   Expected: Highlighted differences showing impact of modification
   ```

---

## Workflow 6: Sequencer Token Analysis

**Used by:** Pass 03 (Authentication — session token entropy)
**Purpose:** Statistically analyze randomness of session tokens and CSRF tokens.
**Safety:** Passive analysis of captured tokens. No attack payloads.

### Steps

1. **Capture token-generating requests**
   ```
   Tool: burp_sequencer_configure
   Input:
     request_url: "{LOGIN_ENDPOINT}"
     request_method: "POST"
     request_body: "username={TEST_USER}&password={TEST_PASS}"
     token_location: "{cookie|header|body}"
     token_name: "{SESSION_COOKIE_NAME}"
     sample_size: 100  # Number of tokens to collect
   Expected: Sequencer configured to capture tokens
   ```

2. **Start token collection**
   ```
   Tool: burp_sequencer_start
   Expected: Collection begins, tokens captured from responses
   ```

3. **Get analysis results**
   ```
   Tool: burp_sequencer_get_results
   Expected:
     overall_quality: "{excellent|reasonable|poor}"
     effective_entropy_bits: {N}  # Should be >= 64
     character_level_analysis: {...}
     bit_level_analysis: {...}
     fips_test_results: {...}
   ```

4. **Evaluate token quality**
   - Entropy >= 64 bits: Pass
   - Entropy 32-63 bits: Medium concern (predictable under high traffic)
   - Entropy < 32 bits: Critical — tokens are predictable
   - Failed FIPS tests: Weak PRNG in use
   - Pattern detected: Possible sequential or time-based generation

---

## Workflow 7: Session Token Capture

**Used by:** Pass 03 (Authentication), Pass 04 (Authorization)
**Purpose:** Capture and store authenticated session tokens for use in subsequent tests.
**Safety:** No attack payloads. Tokens stored only in memory during scan.

### Steps

1. **Navigate to login page**
   ```
   Tool: playwright browser_navigate
   Input:
     url: "{APP_URL}/login"
   Expected: Login page loads
   ```

2. **Fill and submit login form**
   ```
   Tool: playwright browser_fill_form
   Input:
     fields: [
       { selector: "input[name='email']", value: "{TEST_EMAIL}" },
       { selector: "input[name='password']", value: "{TEST_PASSWORD}" }
     ]
     submit_selector: "button[type='submit']"
   Expected: Form submitted, redirect to authenticated page
   ```

3. **Capture cookies via Playwright**
   ```
   Tool: playwright browser_evaluate
   Input:
     expression: "document.cookie"
   Expected: Cookie string with session token
   ```

4. **Capture tokens from Burp proxy**
   ```
   Tool: burp_proxy_get_response_headers
   Input:
     url: "{LOGIN_ENDPOINT}"
   Expected: Set-Cookie headers with session tokens, any Authorization tokens in response body
   ```

5. **Extract JWT from localStorage/sessionStorage (if applicable)**
   ```
   Tool: playwright browser_evaluate
   Input:
     expression: "JSON.stringify({localStorage: {...localStorage}, sessionStorage: {...sessionStorage}})"
   Expected: Any JWT or auth tokens stored in browser storage
   ```

6. **Store tokens for subsequent requests**
   Save captured tokens:
   - Session cookie value
   - JWT access token
   - CSRF token (if present)
   - Refresh token (if present)

   **CRITICAL:** Never log token values in the audit report. Use [REDACTED] in all output.

---

## Workflow 8: Header Injection Testing

**Used by:** Pass 02 (Headers), Pass 05 (Injection)
**Purpose:** Test for host header injection and other header-based attacks.
**Safety:** Detection-only payloads. No data modification.

### Steps

1. **Test Host header injection**
   ```
   Tool: burp_repeater_send
   Input:
     method: "GET"
     url: "{APP_URL}/password-reset"
     headers:
       Host: "evil.example.com"
   Expected: Check if response or email contains evil.example.com
   ```

2. **Test X-Forwarded-Host override**
   ```
   Tool: burp_repeater_send
   Input:
     method: "GET"
     url: "{APP_URL}"
     headers:
       Host: "{LEGITIMATE_HOST}"
       X-Forwarded-Host: "evil.example.com"
   Expected: Check if X-Forwarded-Host overrides Host in response
   ```

3. **Test duplicate Host headers**
   ```
   Tool: burp_repeater_send
   Input:
     method: "GET"
     url: "{APP_URL}"
     headers:
       Host: "{LEGITIMATE_HOST}"
     additional_headers:
       - "Host: evil.example.com"
   Expected: Check which Host value the server uses
   ```

4. **Test IP-based access bypass headers**
   ```
   Tool: burp_intruder_configure
   Input:
     attack_type: "sniper"
     base_request: "GET {ADMIN_URL} HTTP/1.1\r\nHost: {HOST}\r\n{MARKER_HEADER}: 127.0.0.1\r\n"
     positions: [{ parameter: "MARKER_HEADER", location: "header_name" }]
   ```
   ```
   Tool: burp_intruder_set_payloads
   Input:
     position: 0
     payloads: [
       "X-Forwarded-For",
       "X-Real-IP",
       "X-Originating-IP",
       "X-Remote-IP",
       "X-Client-IP",
       "X-Host",
       "True-Client-IP",
       "Cluster-Client-IP",
       "X-Forwarded",
       "Forwarded-For"
     ]
   Expected: Test if any header grants access to admin
   ```

5. **Analyze results**
   - Any 200 response to admin = Critical finding (auth bypass via header)
   - Host reflected in response = Potential cache poisoning or phishing
   - Different response content = Server processes the injected header

---

## Workflow 9: API Endpoint Discovery

**Used by:** Pass 01 (Reconnaissance), Pass 09 (API Security)
**Purpose:** Discover API endpoints through multiple methods.
**Safety:** Read-only discovery. No attack payloads.

### Steps

1. **Check for OpenAPI/Swagger documentation**
   ```
   Tool: burp_intruder_configure
   Input:
     attack_type: "sniper"
     base_request: "GET {MARKER_PATH} HTTP/1.1\r\nHost: {HOST}\r\n"
     positions: [{ parameter: "MARKER_PATH", location: "url_path" }]
   ```
   ```
   Tool: burp_intruder_set_payloads
   Input:
     position: 0
     payloads: [
       "/api-docs", "/swagger.json", "/swagger/v1/swagger.json",
       "/openapi.json", "/openapi.yaml", "/api/docs",
       "/api/swagger", "/api/v1/docs", "/api/v2/docs",
       "/docs", "/redoc", "/api-docs.json",
       "/.well-known/openapi.json", "/graphql",
       "/graphiql", "/playground", "/altair"
     ]
   Expected: Any 200 response reveals API documentation
   ```

2. **Check for GraphQL introspection**
   ```
   Tool: burp_repeater_send
   Input:
     method: "POST"
     url: "{APP_URL}/graphql"
     headers:
       Content-Type: "application/json"
     body: '{"query": "{ __schema { types { name fields { name } } } }"}'
   Expected: If 200 with schema data — introspection enabled (finding)
   ```

3. **Extract endpoints from JavaScript bundles**
   ```
   Tool: playwright browser_evaluate
   Input:
     expression: |
       const scripts = Array.from(document.querySelectorAll('script[src]'));
       scripts.map(s => s.src);
   Expected: List of JS bundle URLs
   ```
   Then for each bundle:
   ```
   Tool: burp_repeater_send
   Input:
     method: "GET"
     url: "{JS_BUNDLE_URL}"
   Expected: JavaScript source — search for API paths using regex
   ```

4. **Parse Burp sitemap for API patterns**
   ```
   Tool: burp_target_get_sitemap
   Input:
     filter: "/api/"
   Expected: All discovered API endpoints from crawling
   ```

5. **Test common API version paths**
   ```
   Tool: burp_intruder_configure
   Input:
     attack_type: "sniper"
     positions: [{ parameter: "version", location: "url_path" }]
   ```
   ```
   Tool: burp_intruder_set_payloads
   Input:
     position: 0
     payloads: [
       "/api/v1/users", "/api/v2/users", "/api/v3/users",
       "/api/internal/users", "/api/admin/users",
       "/api/debug/info", "/api/health", "/api/status",
       "/api/config", "/api/env"
     ]
   Expected: Discover undocumented or deprecated API versions
   ```

---

## Workflow 10: Rate Limit Testing

**Used by:** Pass 14 (Rate Limiting & DoS Resilience)
**Purpose:** Verify rate limiting is properly implemented.
**Safety:** Controlled test with maximum 20 requests. Stops on first 429.

### Steps

1. **Establish baseline**
   ```
   Tool: burp_repeater_send
   Input:
     method: "{METHOD}"
     url: "{TARGET_ENDPOINT}"
     headers:
       Authorization: "Bearer {TOKEN}"
   Expected: Normal 200 response — record response time as baseline
   ```

2. **Graduated rate test**
   ```
   Tool: burp_intruder_configure
   Input:
     attack_type: "sniper"
     base_request: "{BASELINE_REQUEST}"
     positions: [{ parameter: "counter", location: "header", name: "X-Request-ID" }]
     rate_limit: 5  # Start at 5 req/sec
     max_requests: 20  # Hard cap
     stop_on_status: [429]  # Stop immediately on rate limit
   ```
   ```
   Tool: burp_intruder_set_payloads
   Input:
     position: 0
     payload_type: "numbers"
     from: 1
     to: 20
     step: 1
   Expected: Sequential requests with incrementing IDs
   ```

3. **Analyze rate limit response**
   ```
   Tool: burp_intruder_get_results
   Input:
     attack_id: "{ATTACK_ID}"
   Expected:
     - At what request count did 429 appear?
     - Does Retry-After header exist?
     - Is the rate limit per-IP, per-user, or per-endpoint?
     - What is the limit window (requests per minute/second)?
   ```

4. **Test rate limit bypass (single request each)**
   ```
   Tool: burp_repeater_send
   Input:
     method: "{METHOD}"
     url: "{TARGET_ENDPOINT}"
     headers:
       Authorization: "Bearer {TOKEN}"
       X-Forwarded-For: "1.2.3.4"
   Expected: Does changing X-Forwarded-For bypass the rate limit?
   ```

5. **Record findings**
   - 429 appears: Rate limiting works — record threshold
   - No 429 after 20 requests: Rate limiting missing — finding
   - X-Forwarded-For bypass works: Rate limit bypassable — finding
   - No Retry-After header: Missing best practice — low finding

---

## Workflow 11: CSRF Token Validation

**Used by:** Pass 07 (CSRF & Clickjacking)
**Purpose:** Verify CSRF tokens are properly validated on state-changing endpoints.
**Safety:** Tests token validation only. No data modification.

### Steps

1. **Capture legitimate request with CSRF token**
   ```
   Tool: burp_proxy_get_request
   Input:
     url: "{STATE_CHANGING_ENDPOINT}"
     method: "POST"
   Expected: Request with CSRF token (in header, body, or cookie)
   ```

2. **Test: Missing CSRF token**
   ```
   Tool: burp_repeater_send
   Input:
     method: "POST"
     url: "{STATE_CHANGING_ENDPOINT}"
     headers:
       Authorization: "Bearer {TOKEN}"
       Content-Type: "application/json"
     body: "{REQUEST_BODY_WITHOUT_CSRF_TOKEN}"
   Expected: Should return 403/422. If 200 — CSRF protection missing.
   ```

3. **Test: Empty CSRF token**
   ```
   Tool: burp_repeater_send
   Input:
     method: "POST"
     url: "{STATE_CHANGING_ENDPOINT}"
     headers:
       Authorization: "Bearer {TOKEN}"
       X-CSRF-Token: ""
     body: "{REQUEST_BODY}"
   Expected: Should return 403/422. If 200 — empty token accepted.
   ```

4. **Test: Invalid/random CSRF token**
   ```
   Tool: burp_repeater_send
   Input:
     method: "POST"
     url: "{STATE_CHANGING_ENDPOINT}"
     headers:
       Authorization: "Bearer {TOKEN}"
       X-CSRF-Token: "aaaa-bbbb-cccc-dddd-invalid-token"
     body: "{REQUEST_BODY}"
   Expected: Should return 403/422. If 200 — token not validated.
   ```

5. **Test: Reused CSRF token (replay)**
   ```
   Tool: burp_repeater_send
   Input:
     method: "POST"
     url: "{STATE_CHANGING_ENDPOINT}"
     headers:
       Authorization: "Bearer {TOKEN}"
       X-CSRF-Token: "{PREVIOUSLY_USED_TOKEN}"
     body: "{REQUEST_BODY}"
   Expected: Should return 403/422. If 200 — token reuse allowed.
   ```

6. **Test: Cross-user CSRF token**
   ```
   Tool: burp_repeater_send
   Input:
     method: "POST"
     url: "{STATE_CHANGING_ENDPOINT}"
     headers:
       Authorization: "Bearer {USER_A_TOKEN}"
       X-CSRF-Token: "{USER_B_CSRF_TOKEN}"
     body: "{REQUEST_BODY}"
   Expected: Should return 403/422. If 200 — tokens not user-bound.
   ```

7. **Check SameSite cookie attribute**
   ```
   Tool: burp_proxy_get_response_headers
   Input:
     url: "{LOGIN_ENDPOINT}"
     header_filter: "Set-Cookie"
   Expected: Cookies should have SameSite=Strict or SameSite=Lax
   ```

---

## Workflow 12: Authentication Brute Force (Rate-Limited)

**Used by:** Pass 03 (Authentication — lockout mechanism verification)
**Purpose:** Verify account lockout after failed login attempts.
**Safety:** Maximum 10 attempts. 1 request/second. Uses known-invalid credentials only.

### Pre-flight Checks

1. Confirm target has a login endpoint
2. Verify rate limit is set to 1 req/sec
3. Confirm max attempts is 10 (hardcoded safety limit)
4. Display brute force test confirmation prompt
5. Wait for user approval

### Steps

1. **Configure low-rate Intruder**
   ```
   Tool: burp_intruder_configure
   Input:
     attack_type: "sniper"
     base_request: |
       POST {LOGIN_ENDPOINT} HTTP/1.1
       Host: {HOST}
       Content-Type: application/json

       {"email": "{TEST_EMAIL}", "password": "{MARKER}"}
     positions: [{ parameter: "password", location: "body_param" }]
     rate_limit: 1  # 1 request per second — safety requirement
     max_requests: 10  # Hard limit — never exceed
   Expected: Intruder configured for slow brute force test
   ```

2. **Load invalid password payloads**
   ```
   Tool: burp_intruder_set_payloads
   Input:
     position: 0
     payload_type: "simple_list"
     payloads: [
       "wrong1", "wrong2", "wrong3", "wrong4", "wrong5",
       "wrong6", "wrong7", "wrong8", "wrong9", "wrong10"
     ]
   Expected: 10 known-bad passwords loaded
   ```

3. **Start attack**
   ```
   Tool: burp_intruder_start
   Expected: Attack begins at 1 req/sec
   ```

4. **Monitor for lockout**
   ```
   Tool: burp_intruder_get_results
   Input:
     attack_id: "{ATTACK_ID}"
   Expected: Watch for:
     - Response changes from "Invalid credentials" to "Account locked"
     - Status code changes (200 -> 429 or 200 -> 423)
     - CAPTCHA challenge appears
     - Response time increases (artificial delay)
   ```

5. **Evaluate lockout mechanism**
   - Lockout after 3-5 attempts: Good
   - Lockout after 6-10 attempts: Acceptable
   - No lockout after 10 attempts: Finding — brute force possible
   - IP-based lockout only: Partial — can be bypassed with IP rotation
   - CAPTCHA after N attempts: Good secondary defense
   - Progressive delay: Good — makes brute force impractical

6. **Verify lockout recovery**
   Wait 15 minutes, then:
   ```
   Tool: burp_repeater_send
   Input:
     method: "POST"
     url: "{LOGIN_ENDPOINT}"
     body: '{"email": "{TEST_EMAIL}", "password": "wrong_again"}'
   Expected: Check if account auto-unlocks or requires admin intervention
   ```

---

## General Notes for All Workflows

### Error Handling

If any Burp MCP tool call fails:
1. Log the error with timestamp and context
2. Do not retry destructive operations
3. For connection errors, wait 5 seconds and retry once
4. For 5xx responses from target, reduce rate by 50%
5. For persistent failures, skip the check and note it as "Unable to test"

### Audit Trail Integration

Every workflow step must log to `security-audit/audit-trail.jsonl`:
```json
{
  "timestamp": "2026-06-02T14:30:22.456Z",
  "workflow": "active_scan",
  "step": 3,
  "tool": "burp_scanner_start",
  "target": "https://staging.example.com",
  "method": "POST",
  "path": "/api/users",
  "payload_type": "sqli_blind_time",
  "response_code": 200,
  "response_time_ms": 245,
  "finding": null,
  "pass": "05-injection",
  "tier": "Tier 1"
}
```

### Rate Limit Compliance

All workflows enforce these limits:
- **localhost:** max 50 req/sec
- **staging:** max 20 req/sec
- **production:** max 5 req/sec

If the target returns 429:
1. Stop immediately
2. Wait for Retry-After header value (or 30 seconds)
3. Resume at 50% of previous rate
4. Log the rate adjustment
