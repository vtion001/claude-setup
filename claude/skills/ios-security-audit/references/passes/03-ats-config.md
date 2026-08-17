# Pass 03 — App Transport Security (ATS) Configuration

**Weight:** 3×
**MASVS:** MASVS-NETWORK-1, MASVS-NETWORK-2
**MSTG:** MSTG-NETWORK-1, MSTG-NETWORK-2

## What this audits

`Info.plist`'s `NSAppTransportSecurity` block + every `NSExceptionDomains`
entry. ATS is iOS's default-deny network policy. Every weakening must be
justified.

## Tier 0 — Info.plist extraction

```bash
plutil -p Info.plist | grep -A 20 NSAppTransportSecurity
```

Pull these keys:
- `NSAllowsArbitraryLoads` (must be NO for production)
- `NSAllowsArbitraryLoadsInWebContent` (only justified for in-app browser)
- `NSAllowsLocalNetworking` (justified for local-network services like
  Ollama; flag as known waiver)
- `NSExceptionDomains` (per-domain exceptions)
- `NSExceptionAllowsInsecureHTTPLoads` (per-domain HTTP allowed)
- `NSExceptionMinimumTLSVersion` (anything below TLSv1.2 = High)
- `NSExceptionRequiresForwardSecrecy` (false = High)
- `NSIncludesSubdomains`

## Scoring (1–5)

| Score | Criteria |
|---|---|
| 5 | No exceptions. `NSAllowsArbitraryLoads` = NO. Default policy applies app-wide. |
| 4 | 1–2 justified exceptions (e.g. local network, in-app browser) documented in CLAUDE.md. |
| 3 | Several exceptions, some without clear justification. |
| 2 | `NSAllowsArbitraryLoads` = YES with no exception domains scoping it back. |
| 1 | `NSAllowsArbitraryLoads` = YES + production traffic flowing over arbitrary loads. |

## Common findings + severity

| Finding | Severity |
|---|---|
| `NSAllowsArbitraryLoads` = YES, no scoping | **Critical** |
| `NSExceptionMinimumTLSVersion` < 1.2 | **High** |
| `NSExceptionRequiresForwardSecrecy` = NO without rationale | **High** |
| `NSAllowsLocalNetworking` without code-side scoping (host=127.0.0.1) | **Medium** |
| Per-domain exception for a 3rd-party that supports TLS1.2 | **High** |
| Stale exception for a sunsetted domain | **Low** |

## Recommended fixes

Remove the exception. If the third party genuinely doesn't support
TLS1.2+, escalate to them — the App Store policy expects ATS compliance.
For local-network exceptions, document the host scope in code:

```swift
// Justified: Ollama runs locally only, not exposed beyond the device.
// Pinned in Info.plist via NSAllowsLocalNetworking; here we double-check
// the host is loopback before issuing requests.
guard host == "localhost" || host == "127.0.0.1" else {
    throw NetworkError.disallowedHost(host)
}
```

## What NOT to flag

- `NSAllowsLocalNetworking` for local-only services with code-side
  host scoping (annotate as "Acknowledged waiver" with file:line)
- Empty `NSAppTransportSecurity` dict (means: default ATS, all good)
