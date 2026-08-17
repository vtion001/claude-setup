# Pass 04 — Certificate Pinning

**Weight:** 2×
**MASVS:** MASVS-NETWORK-3
**MSTG:** MSTG-NETWORK-3, MSTG-NETWORK-4

## What this audits

For sensitive endpoints (OAuth, payment, account APIs), does the app
pin the server's certificate or public key so a compromised CA can't
issue a rogue cert and MITM the user?

## Tier 0 — static

```bash
# URLSession delegate with pinning logic
grep -rn --include='*.swift' \
  -E 'urlSession\(_:didReceive:.*completionHandler|SecTrustEvaluate|SecCertificateCopyData|SecTrustGetCertificateAtIndex' \
  <project-root>

# AppAuth / Alamofire pin configuration
grep -rn --include='*.swift' \
  -E 'ServerTrustPolicy|publicKeysOf|certificatesIn|pinnedCertificates' \
  <project-root>

# TrustKit setup
grep -rn --include='*.swift' \
  -E 'TrustKit\.initSharedInstance|kTSKPublicKeyHashes' \
  <project-root>
```

## Scoring (1–5)

| Score | Criteria |
|---|---|
| 5 | Pinning for all sensitive endpoints with backup pin + rotation plan in CLAUDE.md or doc. |
| 4 | Pinning for OAuth + payment. Backup pin present. Rotation doc light. |
| 3 | Pinning for OAuth only. No backup pin (risks app-bricking on cert rotation). |
| 2 | Plans to pin but URLSession delegate is empty or pinning code is unreachable. |
| 1 | No pinning anywhere. Sensitive endpoints rely solely on system CA trust. |

## Common findings + severity

| Finding | Severity |
|---|---|
| OAuth token endpoint without pinning | **High** |
| Payment / banking endpoint without pinning | **Critical** |
| Pinning code without backup pin (rotation = bricked app) | **Medium** |
| Pinning to leaf cert (instead of intermediate or public key) | **Medium** (rotation risk) |
| Pinning logic that always returns `.useCredential` regardless of trust eval | **Critical** (effectively disabled) |

## Recommended fixes

Use **AppAuth-iOS** for OAuth (it integrates with `ASWebAuthenticationSession`
which has system pinning) and **TrustKit** for arbitrary URLSession
pinning. Both are SPM-installable.

Minimal URLSession delegate pinning (no library):
```swift
final class PinningDelegate: NSObject, URLSessionDelegate {
    /// Public-key hashes for the API (SHA-256 of subjectPublicKeyInfo).
    /// Include current + backup — when current rotates, app still trusts.
    let pinnedHashes: Set<String> = [
        "<base64 SHA-256 of current SPKI>",
        "<base64 SHA-256 of backup SPKI>"
    ]

    func urlSession(_ session: URLSession,
                    didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        guard let trust = challenge.protectionSpace.serverTrust,
              let serverHash = SPKIHasher.sha256Hash(of: trust),
              pinnedHashes.contains(serverHash) else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }
        completionHandler(.useCredential, URLCredential(trust: trust))
    }
}
```

Pair with a rotation plan: include the next year's cert SPKI hash as a
backup, document the rotation date in CLAUDE.md.

## What NOT to flag

- Apps that only call public, low-sensitivity APIs (read-only data
  feeds with no auth state)
- `oauth2.googleapis.com` if the app exclusively uses
  `ASWebAuthenticationSession` (which has system-level pinning)
- Development-only network logging without prod usage
