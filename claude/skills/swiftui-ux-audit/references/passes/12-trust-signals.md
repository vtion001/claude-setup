# Pass 12 — Trust Signals

**Weight:** 1×

## What this audits

Whether the app reads as legitimate, secure, and reliable. iOS-specific trust signals differ from web; this pass adapts for that.

## iOS-native trust signals

1. **Sign in with Apple** — present alongside other sign-in options. Apple requires it if you offer 3rd-party social logins.
2. **Permission prompts** — clear `NSUsageDescription` strings, not auto-generated "App would like to…"
3. **Privacy-nutrition-label alignment** — what the app actually does should match the App Store label (out of audit scope to verify the label, but flag if the in-app surfaces don't match common assumptions).
4. **Secure-store messaging** — when handling credentials, surface "stored on this device only" if true.
5. **Apple-recognized icons** — using SF Symbols for system-meaning icons (e.g. `lock.fill` for secure, `person.fill` for account, `envelope.fill` for email) — borrowing established meaning.
6. **HTTPS-only network** — the App Transport Security defaults should not be relaxed in `Info.plist`. Flag if `NSAllowsArbitraryLoads` is true.
7. **Crash-free perception** — Welcome screens, empty states, and errors that look polished signal stability.
8. **Connection state messaging** — offline / connecting / connected indicators where the user is waiting on network.
9. **Version/build visibility** — Settings → About showing version + build (developer trust signal).
10. **No "Beta" / "Coming soon" stub buttons** in a shipping app — those erode trust.

## Tier 1 (automated)

```bash
# Sign in with Apple usage
rg --no-heading -n 'SignInWithAppleButton|AuthorizationAppleIDButton|AppleID' <project>

# ATS bypasses in Info.plist
grep -A2 NSAllowsArbitraryLoads Pookoo/Info.plist 2>/dev/null

# Usage descriptions present
grep -E 'NSCameraUsageDescription|NSLocationWhenInUseUsageDescription|NSPhotoLibraryUsageDescription|NSContactsUsageDescription' Pookoo/Info.plist

# Stub buttons
rg --no-heading -n 'Coming soon|Beta|TODO|FIXME|stub' <project>
```

## Tier 2 (AI on screenshot)

1. Does the sign-in screen offer Apple's button alongside others (if any third-party login exists)?
2. Are permission rationales (the soft-ask before the system prompt) well-written and specific?
3. Do error/offline states feel polished or hastily designed?
4. Does the Settings → About screen exist and show version + privacy link + terms link?
5. Are there any stub or "coming soon" buttons visible?
6. Do icons in security/account contexts use canonical SF Symbols?

## Scoring (1–5)

| Score | Criteria |
|---|---|
| 5 | All native trust signals present; ATS strict; no stub buttons; polished error/offline states |
| 4 | All trust signals present; one minor polish item |
| 3 | One trust signal missing (e.g. no soft-ask for permissions) |
| 2 | Multiple missing signals OR ATS bypassed without justification |
| 1 | Stub buttons in shipping app; ATS bypassed broadly; permission strings generic |

## Common findings + severity

| Finding | Severity |
|---|---|
| `NSAllowsArbitraryLoads = true` without per-domain exceptions | High |
| Generic `NSCameraUsageDescription` ("Camera access") | Medium |
| Third-party social login without Sign in with Apple | Critical (Apple guideline 4.8 violation) |
| Settings missing About / version display | Low |
| Stub button visible in production scheme | High |
| Offline state is a blank screen | Medium |

## Recommended fixes

- Add Sign in with Apple via `AuthenticationServices.SignInWithAppleButton`.
- Replace generic usage descriptions with specific reasons.
- Remove or feature-flag stub buttons before ship.
- Add `Settings → About` with version (`Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString")`).

## What NOT to flag

- Apps that don't offer any third-party social logins (Sign in with Apple is required only when at least one is present)
- Internal/enterprise builds where stub buttons are intentional
