# Pass 02 — Keychain Usage

**Weight:** 3×
**MASVS:** MASVS-STORAGE-1, MASVS-PLATFORM-2
**MSTG:** MSTG-STORAGE-1, MSTG-STORAGE-2, MSTG-AUTH-7

## What this audits

When the app DOES use Keychain, is it used correctly?

1. **`kSecAttrAccessible` value** — picked correctly for the data
   sensitivity + UX requirement
2. **`kSecAttrAccessControl` / ACL** — biometric-protected items for
   high-value data
3. **`kSecAttrSynchronizable`** — Off by default; only on for items the
   user expects to sync via iCloud Keychain
4. **`kSecAttrService` and `kSecAttrAccount`** — unique per item, no
   collisions
5. **Error handling** — `OSStatus` returns checked, not silently
   discarded
6. **`SecItemDelete` before `SecItemAdd`** — prevents `errSecDuplicateItem`
7. **Keychain access groups** — entitlements match the configured group
8. **Migration after iOS version bumps** — `kSecAttrAccessibleAlways` is
   deprecated; check for removal

## Tier 0 — static grep

```bash
# Find all Keychain usage
grep -rn --include='*.swift' \
  -E 'SecItem(Add|Update|Copy|Delete|CopyMatching)|kSecClass|kSecAttr|kSecValueData' \
  <project-root>

# Check for deprecated accessibility values
grep -rn --include='*.swift' \
  -E 'kSecAttrAccessibleAlways|kSecAttrAccessibleAlwaysThisDeviceOnly' \
  <project-root>

# Check for silenced errors (a common bug)
grep -rn --include='*.swift' -B 2 -A 2 \
  -E 'SecItemAdd|SecItemCopyMatching' \
  <project-root> | grep -E 'try\?|_ ='
```

Output JSON:
```json
{
  "keychain_call_sites": [{"file": "...", "line": N, "api": "SecItemAdd"}],
  "deprecated_accessibility": [...],
  "silenced_errors": [...],
  "uses_access_control": false,
  "uses_access_groups": false
}
```

## Tier 2 — AI reasoning

For each Keychain call site:

1. **Accessibility class** — is it the most restrictive that still
   provides the needed UX?
   - `WhenUnlockedThisDeviceOnly` for active session tokens (preferred)
   - `AfterFirstUnlockThisDeviceOnly` for refresh tokens (long-lived)
   - Never `Always*` (deprecated)
2. **ACL** — for biometric-gated data (banking, secrets, payment),
   `SecAccessControlCreateWithFlags(.biometryCurrentSet)` is required
3. **Concurrency** — Keychain calls are synchronous; if called from a
   `@MainActor` context they should be on a background task

## Scoring (1–5)

| Score | Criteria |
|---|---|
| 5 | Keychain wrapper used consistently. Correct accessibility class per data type. Biometric ACL for high-value data. All errors handled. |
| 4 | Wrapper used. Accessibility correct. Minor issue: error logging missing in 1-2 spots. |
| 3 | Wrapper exists but used inconsistently OR no biometric ACL where it should be present. |
| 2 | Raw Security calls scattered through business logic. Errors silently dropped (`try?`). |
| 1 | No Keychain usage at all when sensitive data exists, OR uses deprecated `Always` accessibility, OR Keychain items leak to iCloud unintentionally. |

## Common findings + severity

| Finding | Severity |
|---|---|
| No Keychain usage when tokens are stored | **Critical** (defers to pass 01) |
| `kSecAttrAccessibleAlways` used | **Critical** (deprecated, allows pre-unlock access) |
| Synchronizable = true on non-iCloud-intended item | **High** |
| Errors discarded via `try?` on `SecItemAdd` | **Medium** |
| Missing biometric ACL on payment / banking tokens | **High** |
| Keychain calls from `@MainActor` blocking UI | **Low** |

## Recommended fixes

See `01-secrets-storage.md` for the full `KeychainStore` wrapper. Add
these refinements for L2 / sensitive data:

```swift
// Biometric-gated read
extension KeychainStore {
    static func saveBiometric(_ value: String, forKey key: String) throws {
        var error: Unmanaged<CFError>?
        guard let access = SecAccessControlCreateWithFlags(
            kCFAllocatorDefault,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            .biometryCurrentSet,
            &error
        ) else {
            throw KeychainError.unhandled(status: errSecParam)
        }
        let attrs: [String: Any] = [
            kSecClass as String:           kSecClassGenericPassword,
            kSecAttrService as String:     "com.pookoo.app",
            kSecAttrAccount as String:     key,
            kSecAttrAccessControl as String: access,
            kSecValueData as String:       Data(value.utf8)
        ]
        SecItemDelete(attrs as CFDictionary)
        let status = SecItemAdd(attrs as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeychainError.unhandled(status: status) }
    }
}
```

## What NOT to flag

- Apps with no sensitive data at all (rare; usually the audit is wrong
  about what's sensitive)
- Hardcoded constant `kSecClass`-style references in test files
- Use of `SecKeyCreateRandomKey` for crypto purposes (that's pass 06)
