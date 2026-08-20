# /ios-security-audit — Tech Stack

Curated tools, MCP servers, and authoritative references. Updated June 2026.

## Tools

### Required
| Tool | Install | What it covers |
|---|---|---|
| **mobsfscan** | `pip install --user mobsfscan` | Static security rules for mobile apps. Lightweight CLI wrapper around MobSF rules. ([repo](https://github.com/MobSF/mobsfscan)) |

### Optional but recommended
| Tool | Install | What it covers |
|---|---|---|
| **Proxyman** | `brew install --cask proxyman` | HTTPS proxy; runtime cert-pinning detection ([proxyman.com](https://proxyman.com)) |
| **Frida + Objection** | `brew install frida` + `pip install objection` | Runtime Keychain dump, pinning bypass tests (requires jailbroken device or Corellium) |
| **Ostorlab Community** | [docs](https://oxo.ostorlab.co/) | Free static + dynamic mobile scanner |
| **MobSF (full server)** | Docker image | Full UI for repeated audits; mobsfscan is enough for CLI use |

## MCP Servers
| MCP | Status | Use |
|---|---|---|
| **XcodeBuildMCP** | Published, working | `npx -y xcodebuildmcp@latest mcp` — runs builds, reads test results. Use for verification after manual security fixes. ([repo](https://github.com/getsentry/XcodeBuildMCP)) |
| **Apple Docs MCP** | Published | NL queries against developer.apple.com; useful for Platform Security guide lookups |
| **No MASTG/MASVS MCP** | Not shipped (June 2026) | Wrap MobSF REST API manually if needed |

## Standards benchmarked against

| Standard | URL | Status |
|---|---|---|
| **OWASP MASVS v2** | https://mas.owasp.org/MASVS/ | Current as of June 2025 refresh |
| **OWASP MASTG** | https://mas.owasp.org/MASTG/ | Aligned with MASWE + MAS profiles |
| **Apple Platform Security Guide** | https://support.apple.com/guide/security/welcome/web | Annual update; June 2026 edition current |
| **Apple App Sandbox** | https://developer.apple.com/documentation/security/app_sandbox | Foundation for all iOS apps |
| **Apple Cryptographic Services Guide** | https://developer.apple.com/documentation/cryptokit | CryptoKit canonical reference |
| **RFC 8252** | https://datatracker.ietf.org/doc/html/rfc8252 | OAuth 2.0 for Native Apps (PKCE mandate) |
| **RFC 7636** | https://datatracker.ietf.org/doc/html/rfc7636 | PKCE specification |

## Reference reading

- **OWASP MAS root**: https://mas.owasp.org/
- **NowSecure vs MobSF comparison**: https://appsecsanta.com/mobile-security-tools/nowsecure-vs-mobsf
- **Apple WWDC22 — Adopt App Transport Security**: https://developer.apple.com/videos/play/wwdc2022/110343/
- **Apple WWDC21 — Distribute Apps in Xcode with Cloud Signing**: https://developer.apple.com/videos/play/wwdc2021/10204/
- **Sign in with Apple Review Guidelines** (4.8.0.0): https://developer.apple.com/app-store/review/guidelines/#sign-in-with-apple
- **Preventing exploitation of deep links** (Redfox): https://www.redfoxsec.com/blog/preventing-exploitation-of-deep-links
- **iOS Application Security book** (David Thiel): https://nostarch.com/iossecurity

## Pookoo-specific tool baseline

Pookoo has zero external SDKs, so `09-third-party-libs` will score 5 by
default (nothing to CVE-check). The rest of the audit applies normally.
Known Pookoo gaps that this audit must flag as Critical/High on first run:

- `Pookoo/Services/GmailService.swift` — OAuth tokens persisted via
  UserDefaults → **01-secrets-storage Critical**
- No Keychain usage anywhere → **02-keychain-usage 1/5**
- No certificate pinning for `oauth2.googleapis.com` → **04-cert-pinning High**
- `NSAllowsLocalNetworking` for Ollama → **03-ats-config Medium** (justified
  but should be flagged as a known waiver)
- VisionKit/PDF/image input handled without size limits or sandboxing
  → **08-input-validation Medium**
