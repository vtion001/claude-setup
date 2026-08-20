# /ios-security-audit — Scoring Rubric

Extends `~/.claude/skills/_ios-shared/scoring-rubric-shared.md`. Defines
the 10 passes' weights and the security-specific severity calibration.

## Acronym

**SEC-iOS** — iOS Security Posture Score, 0–100.
Maps loosely to OWASP MASVS levels: ≥90 ≈ L2, 75–89 ≈ L1+, 60–74 ≈ L1,
<60 = below MASVS L1 baseline.

## Pass Weights

Total weight: **27** (max raw 135, max score 100).

| Pass | Weight | Rationale |
|---|---|---|
| 01-secrets-storage | **3×** | Plaintext tokens in UserDefaults = immediate Critical — ship-blocker per MASVS-STORAGE |
| 02-keychain-usage | **3×** | Correct Keychain use is the foundation of every other storage guarantee |
| 03-ats-config | **3×** | One ATS exception can void all transport-level security |
| 04-cert-pinning | **2×** | High-impact for OAuth + payment flows; lower for read-only public APIs |
| 05-biometric-auth | **2×** | Sensitive ops need biometric gating; absence is High for finance/health apps |
| 06-cryptokit-usage | **2×** | Wrong crypto = silent confidentiality loss; weighted high but rare |
| 07-jailbreak-detection | **1×** | MASVS-RESILIENCE; opt-in for L2 only — Low for most consumer apps |
| 08-input-validation | **2×** | ML/PDF/image input is a real attack surface for VisionKit-heavy apps |
| 09-third-party-libs | **2×** | CVE check; weighted higher when SPM/CocoaPods is used |
| 10-code-obfuscation | **1×** | MASVS-RESILIENCE; opt-in for L2 only |

## Score Range Interpretation

Inherits the shared 90+ / 75-89 / 60-74 / 40-59 / <40 bands. Additionally:

| SEC-iOS | MASVS implied level | Action |
|---|---|---|
| 90-100 | L2 or higher | Maintain; quarterly audit |
| 75-89 | L1 + 1-2 L2 controls | Address remaining L2 gaps |
| 60-74 | L1 baseline | Plan a security sprint within the quarter |
| 40-59 | Below L1 | Block any release with PII/auth; address Critical findings |
| <40 | Insecure | Stop-ship. Mandatory remediation. |

## Severity calibration (security-specific)

| Question | Yes → severity |
|---|---|
| Could an attacker on the same device read tokens/PII? | **Critical** |
| Could an attacker MITM the OAuth/token-refresh flow? | **Critical** |
| Could an attacker bypass auth via a UI flaw or deeplink injection? | **Critical** |
| Could an attacker run code via a malicious PDF/image input? | **High** |
| Does the app lack a security control that MASVS L1 requires? | **High** |
| Does the app use deprecated crypto (MD5, SHA1 for security, CommonCrypto without justification)? | **High** |
| Does the app lack a security control that MASVS L2 requires (only relevant if L2)? | **Medium** |
| Is the issue purely defense-in-depth (jailbreak detection, obfuscation)? | **Low** unless L2 |

Be conservative — over-flag rather than under-flag. The audit can be
overridden by a security review; missed Critical findings cannot be.
