# Pass 01 — OAuth + PKCE Compliance

**Weight:** 3×
**Standard:** RFC 8252 + RFC 7636

## What this audits

For every OAuth-using flow:
1. Uses `ASWebAuthenticationSession` (NEVER `WKWebView` for OAuth) — RFC 8252 §5
2. PKCE is implemented with S256 code_challenge_method (NEVER `plain`)
3. No client secret on the iOS client
4. State parameter present + verified on callback (CSRF protection)
5. Redirect URI uses a custom URL scheme OR Universal Link (NOT a localhost loopback for prod)

## Tier 0
```bash
# ASWebAuthenticationSession adoption (correct)
grep -rln --include='*.swift' 'ASWebAuthenticationSession' <project-root>

# WKWebView used for OAuth (anti-pattern)
grep -rln --include='*.swift' 'WKWebView' <project-root> \
  | xargs grep -l 'oauth\|authorize\|auth/\?response_type' 2>/dev/null

# PKCE method
grep -rn --include='*.swift' 'code_challenge_method\|code_verifier\|code_challenge\|S256' <project-root>

# Client secret in source (NEVER)
grep -rn --include='*.swift' 'client_secret\|clientSecret' <project-root> \
  | grep -v 'tests\|fixtures\|allowlist'
```

## Scoring
| Score | Criteria |
|---|---|
| 5 | ASWebAuthenticationSession + PKCE-S256 + state + no client secret |
| 4 | Mostly compliant; minor issue (state parameter missing) |
| 3 | PKCE present but state missing → CSRF risk |
| 2 | WKWebView used for OAuth |
| 1 | No PKCE; client secret in source |

## Common findings
| Finding | Severity |
|---|---|
| `WKWebView` used for OAuth authorize URL | **Critical** (App Store rejection risk + phishing surface) |
| Missing PKCE | **Critical** |
| `code_challenge_method = plain` | **High** |
| State not verified on callback | **High** (CSRF) |
| `client_secret` in source | **Critical** + rotate immediately |
| Custom URL scheme reused across apps (`oauth://callback`) | **Medium** (any app can claim it) |

## Pookoo
Per exploration: uses `ASWebAuthenticationSession` + PKCE (correct). 
Token storage is the open issue — defers to /ios-security-audit pass 01.

## What NOT to flag
- Native Apple integrations (Sign in with Apple uses its own session)
- Internal-only OAuth flows over localhost during dev (not prod)
