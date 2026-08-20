# Pass 06 — CryptoKit Usage

**Weight:** 2×
**MASVS:** MASVS-CRYPTO-1, MASVS-CRYPTO-2, MASVS-CRYPTO-3
**MSTG:** MSTG-CRYPTO-1 through MSTG-CRYPTO-6

## What this audits

When the app does its own cryptography (vs delegating to TLS / Keychain),
is it using **CryptoKit** correctly, and avoiding deprecated/weak primitives?

## Tier 0 — static

```bash
# CryptoKit usage
grep -rn --include='*.swift' \
  -E 'import CryptoKit|SymmetricKey|AES\.GCM|ChaChaPoly|Curve25519|P256|HKDF|HMAC|Insecure\.' \
  <project-root>

# Deprecated CommonCrypto (allowed only with documented justification)
grep -rn --include='*.swift' \
  -E 'import CommonCrypto|CC_SHA|CCCrypt|CCKeyDerivationPBKDF' \
  <project-root>

# Banned algorithms
grep -rn --include='*.swift' \
  -E '\.md5|\.sha1|MD5|SHA1|DES|RC4|kCCAlgorithmDES|kCCAlgorithmRC4' \
  <project-root>

# Misuse: static nonces, ECB mode
grep -rn --include='*.swift' \
  -E 'AES\.GCM\.SealedBox.*nonce: AES\.GCM\.Nonce\([^()]*\)|kCCOptionECBMode' \
  <project-root>
```

## Scoring (1–5)

| Score | Criteria |
|---|---|
| 5 | CryptoKit only. Authenticated encryption (AES-GCM / ChaChaPoly). Random nonces. HKDF for key derivation. No `Insecure.*`. |
| 4 | Mostly CryptoKit. One legacy CommonCrypto call with documented rationale. |
| 3 | Mix of CryptoKit + CommonCrypto. No banned algorithms but some patterns unclear. |
| 2 | CommonCrypto used where CryptoKit would work. Static nonces detected. |
| 1 | MD5/SHA1 for security purposes, DES/RC4, ECB mode, hardcoded keys/IVs. |

## Common findings + severity

| Finding | Severity |
|---|---|
| MD5 or SHA1 used for password/secret hashing | **Critical** |
| AES-ECB mode used | **Critical** |
| Static / hardcoded nonce or IV | **Critical** |
| Hardcoded encryption key in source | **Critical** |
| `Insecure.MD5` / `Insecure.SHA1` for non-checksum use | **High** |
| Unauthenticated AES (CBC without HMAC) | **High** |
| `CC_SHA256` instead of `SHA256` (CryptoKit) without justification | **Low** |
| Custom PBKDF2 implementation (vs `HKDF` / Argon2) | **Medium** |

## Recommended fixes

Replace CommonCrypto with CryptoKit equivalents:

```swift
// BEFORE (CommonCrypto AES-CBC)
let data = ... // CCCrypt(kCCEncrypt, kCCAlgorithmAES, kCCOptionPKCS7Padding, ...)

// AFTER (CryptoKit AES-GCM, authenticated)
import CryptoKit

let key = SymmetricKey(size: .bits256)
let nonce = AES.GCM.Nonce() // random by default
let sealed = try AES.GCM.seal(plaintext, using: key, nonce: nonce)
let ciphertext = sealed.ciphertext
let tag = sealed.tag
let nonceData = nonce.withUnsafeBytes { Data($0) }
```

For password hashing, always use a dedicated KDF — never plain SHA:

```swift
// Argon2 isn't in Foundation; use CryptoKit HKDF for key derivation
let derived = HKDF<SHA256>.deriveKey(
    inputKeyMaterial: SymmetricKey(data: password.data(using: .utf8)!),
    salt: salt,
    info: Data("app-purpose".utf8),
    outputByteCount: 32
)
```

## What NOT to flag

- `MD5` / `SHA1` used as non-security checksums (e.g. cache key derivation
  from file contents where collision resistance isn't required)
- `Insecure.SHA1` explicitly documented as compatibility with a legacy
  protocol (e.g. ETag parsing)
- `CommonCrypto` for performance-critical loops where CryptoKit's
  abstraction overhead matters and the algorithm is sound
