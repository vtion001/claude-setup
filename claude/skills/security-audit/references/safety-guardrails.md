# Security Audit — Safety Guardrails

## Authorization Levels

| Level | Detection | What's Allowed | What's Blocked |
|-------|-----------|----------------|----------------|
| **localhost** | URL contains `localhost`, `127.0.0.1`, `0.0.0.0`, `::1` | Full active scanning, all 15 passes, all Burp tools, max 50 req/sec | Nothing blocked |
| **staging** | URL contains `staging`, `dev`, `test`, `sandbox`, `preview`, `preprod` — OR `--authorize staging` flag | Full active scanning, all 15 passes, all Burp tools, max 20 req/sec | Requires `--authorize staging` flag |
| **production** | All other owned domains — requires `--authorize production --domain {domain}` | Passive scanning by default. Active scanning only with explicit `--active` flag. Max 5 req/sec | Destructive payloads, data modification, brute force beyond 10 attempts, DoS testing |
| **third-party** | Domain not owned by the user | **NOTHING** — hard block | ALL scanning. Display: "Third-party targets require explicit written authorization from the domain owner. This tool cannot verify such authorization." |

## Rate Limits

| Target Type | Default Rate | Max Rate | Burst Allowed | Backoff on 429 |
|-------------|-------------|----------|---------------|----------------|
| localhost | 20 req/sec | 50 req/sec | 10 req burst | 1s exponential |
| staging | 10 req/sec | 20 req/sec | 5 req burst | 2s exponential |
| production | 2 req/sec | 5 req/sec | 2 req burst | 5s exponential |

Rate can be overridden via `--rate {N}` but CANNOT exceed the max for the target type.

If the target returns `429 Too Many Requests`:
1. Immediately stop sending requests
2. Wait for the `Retry-After` header value (or backoff interval)
3. Resume at 50% of previous rate
4. Log the rate adjustment

## Destructive Payload Blocklist

**These payloads must NEVER be sent to any target, regardless of authorization level.**

### SQL Destruction
- `DROP TABLE` / `DROP DATABASE` / `DROP SCHEMA`
- `DELETE FROM` / `DELETE *` / `TRUNCATE TABLE`
- `UPDATE ... SET` (mass update patterns)
- `ALTER TABLE ... DROP`
- `INSERT INTO` (mass insert patterns)
- `CREATE USER` / `GRANT ALL`

### OS Command Destruction
- `rm -rf` / `rmdir /s /q` / `del /f /s /q`
- `format` / `fdisk` / `mkfs`
- `shutdown` / `reboot` / `halt` / `poweroff`
- `dd if=/dev/zero` / `dd if=/dev/urandom`
- `kill -9` / `killall` / `taskkill /f`
- `:(){:|:&};:` (fork bomb)

### File System Destruction
- `> /dev/sda` / write to raw devices
- `chmod -R 777 /` / `chmod -R 000`
- `chown -R` (mass ownership change)

### Application Destruction
- Mass account deletion payloads
- Bulk data wipe API calls
- Configuration reset endpoints
- Factory reset triggers
- Encryption key deletion

### Exfiltration
- `curl | bash` / `wget | sh` (remote code execution chains)
- Base64-encoded reverse shells
- DNS exfiltration tunnels
- ICMP data channels

**Safe alternatives for testing:**
- Instead of `DROP TABLE`: Use `SELECT 1` or `SLEEP(5)` for blind SQLi confirmation
- Instead of destructive commands: Use `whoami`, `id`, `hostname` for command injection confirmation
- Instead of file deletion: Use `ls`, `cat /etc/hostname` for path traversal confirmation
- Instead of data modification: Use read-only queries with `LIMIT 1`

## Confirmation Prompt Templates

### Standard Active Scan Confirmation

```
ACTIVE SCANNING CONFIRMATION
Target: {APP_URL}
Authorization: {localhost|staging|production}
Rate limit: {N} req/sec
Passes: {list of passes}
Estimated requests: {count}
Estimated duration: {minutes}

Active scanning sends crafted payloads to detect vulnerabilities.
Payloads include SQLi probes, XSS vectors, header manipulation, and parameter fuzzing.
NO destructive payloads will be sent.

Proceed with active scanning? [y/N]
```

### Production Active Scan Confirmation (Double Confirmation)

```
PRODUCTION ACTIVE SCAN — ELEVATED RISK

Domain: {domain}
URL: {APP_URL}
Rate limit: {N} req/sec (max 5 for production)
Passes: {list of passes}

This will send attack payloads to a PRODUCTION system.
Ensure you have:
  - Written authorization to test this domain
  - Notified your security team
  - Confirmed no critical user traffic will be affected

Type the full domain name to confirm: ___
```

### Brute Force Test Confirmation

```
BRUTE FORCE TEST
Target: {login_endpoint}
Max attempts: 10 (hardcoded safety limit)
Rate: 1 req/sec
Purpose: Verify account lockout mechanism

This test will submit 10 login attempts with invalid credentials.
Proceed? [y/N]
```

## Audit Trail Requirements

Every request sent during the audit MUST be logged:

| Field | Required | Example |
|-------|----------|---------|
| `timestamp` | Yes | `2026-06-02T14:30:22.456Z` |
| `target` | Yes | `https://staging.example.com` |
| `method` | Yes | `POST` |
| `path` | Yes | `/api/users/login` |
| `payload_type` | Yes | `sqli_blind_time` / `xss_reflected` / `passive` |
| `response_code` | Yes | `200` / `403` / `500` |
| `response_time_ms` | Yes | `245` |
| `finding` | If applicable | `Blind SQLi confirmed via 5s time delay` |
| `pass` | Yes | `05-injection` |
| `tier` | Yes | `Tier 1` |

Log format: JSON Lines (`.jsonl`) saved to `security-audit/audit-trail.jsonl`

## Cleanup Checklist

After every audit, verify and clean up:

- [ ] Remove test user accounts created during scanning
- [ ] Delete uploaded test files (polyglot images, oversized files, etc.)
- [ ] Remove injected test data (comments, posts, records created by payloads)
- [ ] Clear Burp proxy state and intercepted traffic
- [ ] Invalidate captured session tokens
- [ ] Delete local copies of sensitive response data
- [ ] Verify no persistent XSS payloads remain stored on target
- [ ] Verify no test CSRF tokens or state remain
- [ ] Archive audit trail log
- [ ] Generate cleanup confirmation entry in audit trail

## Escalation Template

When a finding requires manual verification (Tier 2 cannot confirm):

```markdown
## Manual Verification Required

**Finding:** {description}
**Pass:** {pass name}
**Confidence:** {Low|Medium} — automated tools could not confirm
**Potential severity:** {Critical|High|Medium|Low}

### Why manual verification is needed:
{Explanation — e.g., business logic context required, multi-step exploit chain, 
environment-specific behavior, false positive indicators present}

### Suggested manual test steps:
1. {step 1}
2. {step 2}
3. {step 3}

### Evidence collected:
- Request: {request details}
- Response: {response snippet}
- Code reference: `{file}:{line}`

### Risk if unverified:
{What could happen if this is a real vulnerability and goes unpatched}
```

## Emergency Stop Conditions

Immediately halt all scanning if any of these occur:

1. **Target returns 5xx errors on >50% of requests** — possible service degradation
2. **Rate limit responses (429) persist after backoff** — target under stress
3. **Target becomes unreachable** — possible crash or WAF block
4. **Unexpected data modification detected** — payload had unintended effect
5. **Real user data appears in responses** — scope contamination risk
6. **Authorization token expires and cannot be refreshed** — scan operating unauthenticated

On emergency stop:
1. Cease all requests immediately
2. Log the stop reason with timestamp
3. Report partial results up to the stop point
4. Run cleanup checklist
5. Recommend manual investigation of the stop cause
