# Pass 01 — Secrets Storage

**Weight:** 3× (highest — plaintext tokens are an immediate ship-blocker)
**MASVS:** MASVS-STORAGE-1, MASVS-STORAGE-2
**MSTG:** MSTG-STORAGE-1 through MSTG-STORAGE-7

## What this audits

Where the app persists sensitive data (OAuth tokens, API keys, session
cookies, biometric templates, PII, payment tokens, refresh tokens) and
whether the storage mechanism provides the confidentiality + integrity
guarantees those data types require.

Specifically:
1. **Persistence sinks** — UserDefaults, NSUbiquitousKeyValueStore,
   FileManager (Documents, Application Support, Caches, tmp), in-memory
   only, Keychain, SwiftData, Core Data, plist files
2. **Sensitive-data flow** — does an OAuth token / API key reach any
   non-Keychain sink at any point in its lifecycle?
3. **Backup exposure** — is sensitive data in a directory that's iCloud /
   iTunes backup-eligible without `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`
   or the equivalent file protection class?
4. **Source-code leaks** — hardcoded keys, hardcoded credentials, secrets
   committed in git (checked via `git log --all -p | grep`)

## Tier 0 — static grep

```bash
# Pattern 1: UserDefaults storing things that look like tokens/keys/secrets.
grep -rn --include='*.swift' \
  -E 'UserDefaults\.standard\.(set|setValue|object).*\b(token|secret|key|password|credential|accessToken|refreshToken|apiKey|api_key|bearer)\b' \
  <project-root>

# Pattern 2: Hardcoded credential strings.
grep -rn --include='*.swift' \
  -E '(let|var|static\s+let|static\s+var)\s+\w*(token|secret|password|apiKey|api_key|bearer)\w*\s*[:=]\s*"[A-Za-z0-9_+/=\-]{16,}"' \
  <project-root>

# Pattern 3: AWS / Stripe / common key-shape patterns.
grep -rn --include='*.swift' --include='*.plist' \
  -E '(AKIA[0-9A-Z]{16}|sk_live_[0-9a-zA-Z]{24,}|sk_test_[0-9a-zA-Z]{24,}|xox[bp]-[0-9]+-[0-9]+-[0-9a-zA-Z]+|ya29\.[0-9A-Za-z\-_]+)' \
  <project-root>

# Pattern 4: PropertyList writing.
grep -rn --include='*.swift' \
  -E 'PropertyListEncoder\(\)\.encode\(.*\b(token|secret|key|password)\b' \
  <project-root>

# Pattern 5: FileManager writes to Documents/Caches with sensitive names.
grep -rn --include='*.swift' \
  -E 'FileManager\.default\..*urls\(for: \.(document|caches|library).*token|.*credential.*\.write' \
  <project-root>
```

Output JSON:
```json
{
  "userdefaults_secret_sinks": [{"file": "...", "line": N, "snippet": "..."}],
  "hardcoded_strings": [...],
  "shape_matches": [...],
  "plist_writes": [...],
  "filemanager_writes": [...],
  "git_committed_secrets": [...]
}
```

## Tier 1 — runtime probe (optional)

Launch the app in the simulator. After authenticating (if a Maestro
flow exists), use `xcrun simctl get_app_container booted <bundle>` to
inspect:
- `Library/Preferences/<bundle>.plist` — dump and grep for token-like
  strings (UserDefaults persists here)
- `Documents/`, `Library/Application Support/`, `Library/Caches/` — for
  any file whose name or content suggests sensitive data

Skip Tier 1 under `--static`.

## Tier 2 — AI reasoning

For each Tier 0 hit, decide:

1. **Is this actually sensitive?** A `userColorPreference` "key" is a
   false positive. A `accessToken` is a true positive.
2. **Could a co-installed app read this?** Pre-iOS 8.3 UserDefaults was
   readable across the app sandbox boundary; since 8.3 only the app
   itself reads its own UserDefaults — BUT iCloud backup of UserDefaults
   exposes it to anyone with the backup.
3. **Is there a Keychain alternative being used elsewhere?** If yes,
   recommend migrating to the same wrapper. If no, recommend introducing
   one (and reference the project's existing `Services/` structure for
   placement).
4. **What's the blast radius?** Single user's OAuth token = Critical.
   API key shared across all installs = Critical + immediate rotation.

When the project uses `@AppStorage("...")` for a secret, treat it as
equivalent severity to `UserDefaults.standard.set` — `@AppStorage` is
UserDefaults under the hood.

## Scoring (1–5)

| Score | Criteria |
|---|---|
| 5 | All secrets in Keychain with appropriate `kSecAttrAccessible*` + ACL. No hardcoded keys. No PropertyList writes. Verified via Tier 1. |
| 4 | Keychain used consistently. 1–2 Low-severity Tier 0 hits that are false positives (config keys, not credentials). |
| 3 | Mostly Keychain. Some configuration/preference values misclassified as sensitive. No actual exposed secrets. |
| 2 | At least one true secret stored outside Keychain (UserDefaults / FileManager / plist), OR a missing-Keychain-wrapper pattern across multiple secrets. |
| 1 | OAuth tokens, refresh tokens, API keys, or PII in UserDefaults / FileManager / source code. Immediate Critical finding. |

## Common findings + severity

| Finding | Severity |
|---|---|
| OAuth access + refresh token in UserDefaults | **Critical** |
| Long-lived API key in UserDefaults | **Critical** |
| API key hardcoded in source / Info.plist | **Critical** + rotate |
| Bearer token written to `Documents/` directory | **Critical** |
| PII (email, address, payment partials) in UserDefaults | **High** |
| Session ID in `Library/Caches/` (purged but readable until purge) | **High** |
| Biometric or face data persisted outside Keychain | **Critical** |
| Push token in plist (low sensitivity but still a sink) | **Low** |
| `@AppStorage("userPreference")` storing a feature flag | **Not a finding** |

## Recommended fixes

**Migrate to Keychain via a wrapper.** Don't use raw Security framework
calls in business logic — wrap them.

```swift
// Add to Pookoo/Services/KeychainStore.swift
import Foundation
import Security

enum KeychainStore {
    enum KeychainError: Error {
        case unhandled(status: OSStatus)
        case notFound
        case decodingFailed
    }

    /// Save a string under a key. Replaces any existing entry.
    /// Default accessibility: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
    /// — token survives reboots once the user unlocks once, but never leaves
    /// the device (excluded from iCloud backups).
    static func save(_ value: String,
                     forKey key: String,
                     accessible: CFString = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly) throws {
        let data = Data(value.utf8)
        let attrs: [String: Any] = [
            kSecClass as String:            kSecClassGenericPassword,
            kSecAttrService as String:      "com.pookoo.app",
            kSecAttrAccount as String:      key,
            kSecAttrAccessible as String:   accessible,
            kSecValueData as String:        data
        ]
        SecItemDelete(attrs as CFDictionary)
        let status = SecItemAdd(attrs as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeychainError.unhandled(status: status) }
    }

    static func read(_ key: String) throws -> String {
        let query: [String: Any] = [
            kSecClass as String:        kSecClassGenericPassword,
            kSecAttrService as String:  "com.pookoo.app",
            kSecAttrAccount as String:  key,
            kSecReturnData as String:   true,
            kSecMatchLimit as String:   kSecMatchLimitOne
        ]
        var item: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess else {
            if status == errSecItemNotFound { throw KeychainError.notFound }
            throw KeychainError.unhandled(status: status)
        }
        guard let data = item as? Data, let s = String(data: data, encoding: .utf8) else {
            throw KeychainError.decodingFailed
        }
        return s
    }

    static func delete(_ key: String) {
        let query: [String: Any] = [
            kSecClass as String:        kSecClassGenericPassword,
            kSecAttrService as String:  "com.pookoo.app",
            kSecAttrAccount as String:  key
        ]
        SecItemDelete(query as CFDictionary)
    }
}
```

Then in `GmailService.swift` (Pookoo example):
```swift
// BEFORE
UserDefaults.standard.set(token, forKey: "gmail_access_token")

// AFTER
try? KeychainStore.save(token, forKey: "gmail_access_token")
```

For a migration step (one-time on app launch), move existing
UserDefaults-stored tokens to Keychain and then delete the
UserDefaults entry.

## What NOT to flag

- Feature flags stored in `@AppStorage` or UserDefaults (theme, units,
  onboarding completion bool) — not sensitive
- Non-secret API base URLs in Info.plist (e.g. `https://api.example.com`)
- App configuration like `enableExperimentalFeature` — not secrets
- Generic constants named `key` that aren't credentials
  (`let mapBoxStyleURL = "..."`, `static let cacheKey = "feed_v1"`)
- Public keys (cert pinning), public-key crypto material — those are
  meant to be visible
