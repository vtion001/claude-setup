# Pass 05 — Biometric Authentication

**Weight:** 2×
**MASVS:** MASVS-AUTH-8, MASVS-PLATFORM-2
**MSTG:** MSTG-AUTH-8, MSTG-AUTH-9

## What this audits

When the app gates sensitive operations (payments, viewing tokens,
displaying PII, large transactions) does it require **biometric
authentication** via `LocalAuthentication`, and is it done correctly?

## Tier 0 — static

```bash
grep -rn --include='*.swift' \
  -E 'LAContext|LAPolicy|evaluatePolicy|deviceOwnerAuthentication|biometryType|kSecAccessControlBiometry' \
  <project-root>

# Check for the FaceIDUsageDescription Info.plist key
plutil -p Info.plist | grep NSFaceIDUsageDescription
```

## Scoring (1–5)

| Score | Criteria |
|---|---|
| 5 | All sensitive operations gated by `LAPolicy.deviceOwnerAuthenticationWithBiometrics`. `NSFaceIDUsageDescription` set. Fallback to passcode handled. |
| 4 | Most sensitive ops gated. Minor: 1-2 operations should be but aren't. |
| 3 | Biometric used but with `LAPolicy.deviceOwnerAuthentication` (passcode-fallback-only allowed) where biometric should be required. |
| 2 | Biometric prompt exists but result is not enforced (e.g. always proceeds regardless of `evaluatePolicy` result). |
| 1 | Sensitive operations with no biometric gate at all. |

## Common findings + severity

| Finding | Severity |
|---|---|
| Payment / banking action without biometric gate | **Critical** |
| Viewing stored tokens / API keys without biometric | **High** |
| Missing `NSFaceIDUsageDescription` (FaceID device → permission alert hostile) | **High** |
| Biometric result ignored / always-succeed code path | **Critical** |
| Using `deviceOwnerAuthentication` (passcode fallback) for very-high-value ops | **Medium** |
| Re-prompting biometric on every screen load (annoyance, not security) | **Low** |

## Recommended fixes

```swift
import LocalAuthentication

@MainActor
final class BiometricGate {
    func authenticate(reason: String) async -> Result<Void, AuthError> {
        let ctx = LAContext()
        var error: NSError?

        // Biometric-only (no passcode fallback) for highest-value ops:
        guard ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics,
                                     error: &error) else {
            return .failure(.unavailable(error))
        }

        do {
            try await ctx.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics,
                                          localizedReason: reason)
            return .success(())
        } catch let err as LAError where err.code == .userCancel || err.code == .userFallback {
            return .failure(.cancelled)
        } catch {
            return .failure(.failed(error))
        }
    }

    enum AuthError: Error {
        case unavailable(NSError?)
        case cancelled
        case failed(Error)
    }
}
```

Always log the result and never proceed on `.failure`.

## What NOT to flag

- Apps with no sensitive operations to gate (e.g. weather, news reader)
- Onboarding flows that don't access any sensitive data yet
- One-time biometric setup at app launch (vs per-operation) — depends on
  threat model; document in CLAUDE.md
