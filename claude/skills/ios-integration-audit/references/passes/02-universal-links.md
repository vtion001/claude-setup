# Pass 02 — Universal Links

**Weight:** 2×

## What this audits
- Associated Domains entitlement
- `apple-app-site-association` file at `https://<domain>/.well-known/apple-app-site-association`
- AASA `paths` allowlist (not wildcard)
- Handling in `.onContinueUserActivity(NSUserActivityTypeBrowsingWeb)`

## Tier 0
```bash
# Associated Domains in entitlements
grep -rn --include='*.entitlements' 'associated-domains' <project-root>

# User activity handlers
grep -rn --include='*.swift' 'NSUserActivityTypeBrowsingWeb\|onContinueUserActivity' <project-root>

# Fetch AASA if domain known
# curl -s https://<domain>/.well-known/apple-app-site-association | jq
```

## Scoring
| Score | Criteria |
|---|---|
| 5 | Associated Domains entitlement + AASA scoped to paths + handlers route correctly |
| 4 | Universal Links work; AASA paths could be tighter |
| 3 | Custom URL scheme only; no Universal Links |
| 2 | AASA returns wildcard `*` (every URL caught) |
| 1 | Associated Domains declared but AASA missing → silent breakage |

## Common findings
| Finding | Severity |
|---|---|
| Custom URL scheme used in marketing links (vs Universal Link) | **Medium** |
| AASA wildcard | **Medium** |
| No handler for incoming Universal Link | **High** |
| Universal Link entitlement without AASA file | **High** |

## What NOT to flag
- Apps with no web counterpart (Universal Links require a domain you control)
- Internal tools deployed via TestFlight only
