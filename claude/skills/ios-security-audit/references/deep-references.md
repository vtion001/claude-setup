# /ios-security-audit — Deep References

Hand-curated reading list for everything this audit benchmarks against.
Use these as primary sources when writing finding descriptions.

## OWASP MAS (Mobile Application Security)

The single most important benchmark. All findings cite a MAS control ID.

- **MASVS v2 (high-level requirements)**: https://mas.owasp.org/MASVS/
  - **MASVS-STORAGE** — secure local storage of sensitive data
  - **MASVS-CRYPTO** — secure cryptography
  - **MASVS-AUTH** — secure authentication & session management
  - **MASVS-NETWORK** — secure network communication
  - **MASVS-PLATFORM** — secure platform interaction
  - **MASVS-CODE** — code quality + build settings
  - **MASVS-RESILIENCE** — resilience against reverse engineering (L2 only)
  - **MASVS-PRIVACY** — privacy-related controls

- **MASTG (testing guide)**: https://mas.owasp.org/MASTG/
  Each MSTG-* test case maps to one or more MASVS controls. Example:
  - **MSTG-STORAGE-1** through 14 (data storage tests)
  - **MSTG-CRYPTO-1** through 6 (cryptography tests)
  - **MSTG-AUTH-1** through 12 (auth tests)
  - **MSTG-NETWORK-1** through 6 (network tests)
  - **MSTG-PLATFORM-1** through 11 (platform-specific tests)
  - **MSTG-CODE-1** through 9 (code quality tests)
  - **MSTG-RESILIENCE-1** through 13 (anti-reverse-engineering, L2 only)

- **MAS Checklist** (printable QA): https://mas.owasp.org/checklists/

## Apple official references

- **Platform Security Guide**: https://support.apple.com/guide/security/welcome/web
  Especially:
  - Hardware security overview (Secure Enclave, kernel integrity)
  - Encryption and data protection (Data Protection classes)
  - App security (App Sandbox, code signing, runtime hardening)
  - Network security (ATS, TLS, certificate validation)
  - User passwords (Local Authentication, Sign in with Apple)

- **Cryptographic Services Guide**: https://developer.apple.com/documentation/cryptokit
- **Security framework reference**: https://developer.apple.com/documentation/security
- **Keychain Services**: https://developer.apple.com/documentation/security/keychain_services
- **Local Authentication**: https://developer.apple.com/documentation/localauthentication
- **App Transport Security**: https://developer.apple.com/documentation/security/preventing_insecure_network_connections

## RFCs

- **RFC 8252 — OAuth 2.0 for Native Apps**: https://datatracker.ietf.org/doc/html/rfc8252
  - External user-agent required (ASWebAuthenticationSession on iOS)
  - No client secrets on native clients
- **RFC 7636 — PKCE**: https://datatracker.ietf.org/doc/html/rfc7636
- **RFC 9126 — Pushed Authorization Requests**
- **RFC 9449 — DPoP** (proof-of-possession for OAuth)
- **RFC 9700 — OAuth 2.0 Security Best Current Practice** (2024)

## WWDC sessions (essential)

- **WWDC25 — What's new in Sign in with Apple**: https://developer.apple.com/videos/play/wwdc2025/
- **WWDC23 — Discover passkeys in iOS 17**: https://developer.apple.com/videos/play/wwdc2023/10242/
- **WWDC22 — Adopt App Transport Security**: https://developer.apple.com/videos/play/wwdc2022/110343/
- **WWDC22 — Protect against third-party fraud**: https://developer.apple.com/videos/play/wwdc2022/
- **WWDC21 — Build trust through better privacy** (App Tracking Transparency)
- **WWDC20 — What's new in Authentication**: ASWebAuthenticationSession patterns

## Tools documentation

- **mobsfscan**: https://github.com/MobSF/mobsfscan
- **MobSF (full server)**: https://github.com/MobSF/Mobile-Security-Framework-MobSF
- **Frida**: https://frida.re/docs/ios/
- **Objection**: https://github.com/sensepost/objection
- **AppAuth-iOS**: https://github.com/openid/AppAuth-iOS — OAuth library that mandates ASWebAuthenticationSession + PKCE
- **TrustKit** (cert pinning): https://github.com/datatheorem/TrustKit
- **iOS Security Suite** (Securing.swift, jailbreak detection): https://github.com/securing/IOSSecuritySuite

## Industry blogs + write-ups

- **NowSecure** (commercial mobile security firm; their blog regularly
  publishes deep iOS analyses): https://www.nowsecure.com/blog/
- **Hacker News mobile security tag**: https://hn.algolia.com/?q=ios+security
- **iOS App Security Checklist** (community): https://github.com/krzyzanowskim/CryptoSwift
  (CryptoSwift README has good algorithm guidance)
- **Awesome iOS Security**: https://github.com/ashishb/osx-and-ios-security-awesome
- **Cocoanetics iOS App Security**: blog with reverse-engineering deep dives

## Books

- *iOS Application Security* (David Thiel, No Starch Press, 2nd ed)
- *iOS Hacker's Handbook* (Miller et al, Wiley)
- *Mobile Application Penetration Testing* (Velu, Packt)

## Calibration sources for severity decisions

When deciding whether a finding is Critical vs High vs Medium, cite:

1. The MASVS / MSTG ID — if the test case exists, it's at least Medium
2. The Apple Platform Security Guide section it violates
3. A published CVE or vulnerability with similar pattern (CWE-312, CWE-319,
   CWE-327, CWE-798 etc.)

Findings that lack any of the three usually downgrade to Low or get
reframed as a `/ios-code-review` style concern instead.
