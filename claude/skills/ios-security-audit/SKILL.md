---
name: ios-security-audit
description: >
  iOS / SwiftUI security audit benchmarked against OWASP MASVS v2
  (June 2025 refresh) and Apple Platform Security. Covers secrets handling,
  Keychain usage, ATS configuration, certificate pinning, biometric auth,
  CryptoKit usage, jailbreak/RASP, ML-input attack surface, third-party
  SDK risk, and code obfuscation.

  Triggers: "audit security", "check for secrets", "OWASP mobile",
  "Keychain check", "certificate pinning", "/ios-security-audit",
  "MASVS check".

  Flags:
    --quick           # Tier 0 (static grep + mobsfscan) only; skip Tier 2 AI
    --pass <names>    # Cherry-pick passes (kebab-case, comma-separated)
    --pages <tabs>    # Limit runtime checks to specific tabs (when Maestro flows exist)
    --static          # Skip all runtime checks; static + AI reasoning only
    --linear          # File findings as Linear issues
    --skip-mobsf      # Skip the MobSF scan (useful if mobsfscan install was rejected)

  Sibling skills:
    - /ios-code-review     defers to here for any secrets / Keychain finding
    - /ios-backend-audit   defers to here for ATS / cert-pinning / token storage
    - /ios-integration-audit defers to here for OAuth token persistence
---

# iOS Security Audit

Static + runtime audit for SwiftUI iOS apps benchmarked against
**OWASP MASVS v2** (`https://mas.owasp.org/MASVS/`, June 2025 refresh)
and Apple's **Platform Security Guide**. This skill never auto-fixes
security findings — it flags, recommends, and tracks. Migration is always
a human decision.

## Prerequisites

- macOS with Xcode 26.5 + `DEVELOPER_DIR` exported (see
  `~/.claude/skills/_ios-shared/ios-tech-baseline.md`)
- An iOS project at `cwd` (detected via
  `_ios-shared/scripts/detect-ios-project.sh`)
- **Optional but recommended**: `mobsfscan` for static security rules
  (`pip install --user mobsfscan`) — Phase 0 prompts to install if missing.
  Skip with `--skip-mobsf`.

## Invocation

```
/ios-security-audit                          # Full audit, all 10 passes
/ios-security-audit --quick                  # Tier 0 only; ~30 sec
/ios-security-audit --pass secrets-storage,keychain-usage
/ios-security-audit --static                 # Skip runtime, keep AI Tier 2
/ios-security-audit --linear                 # File theme-grouped issues
```

No `--fix` flag. Security migrations require human review by policy.

## Pass Names (for `--pass`)

`secrets-storage`, `keychain-usage`, `ats-config`, `cert-pinning`,
`biometric-auth`, `cryptokit-usage`, `jailbreak-detection`,
`input-validation`, `third-party-libs`, `code-obfuscation`

## Workflow

### Phase 0: Auto-detect

Run `~/.claude/skills/_ios-shared/scripts/detect-ios-project.sh` to confirm
this is an iOS project. Read its JSON output. Then:

1. Confirm Xcode + DEVELOPER_DIR
2. Probe for `mobsfscan` via `_ios-shared/scripts/install-tool.sh mobsfscan`
   — prompt to install if missing, unless `--skip-mobsf`
3. Read `Info.plist` for ATS exceptions
4. Read `*.entitlements` files for entitlements that affect security
   (keychain-access-groups, application-identifier, com.apple.developer.*)
5. Print a 5-line detection summary

If the project isn't detected as iOS, fail loudly:
*"Not an iOS project. For web security use a separate web-security skill."*

### Phase 1: Tier 0 — static grep + mobsfscan

For each pass, run its Tier 0 static scan (defined in
`references/passes/NN-*.md`). Collate results to
`<project-root>/ios-audit/ios-security-audit/tier0.json`.

If `mobsfscan` is installed, run:
```bash
mobsfscan --json -o <project-root>/ios-audit/ios-security-audit/mobsf.json <project-root>
```
Merge MobSF findings into per-pass results.

### Phase 2: Tier 1 — runtime probes (skipped under --static)

Currently limited to:
- ATS verification: build the app with `--allow-arbitrary-loads YES`
  override and confirm production target rejects (smoke test that ATS
  is honored)
- Keychain: launch app, attempt to read a stored token via `osascript`
  asking for security context

If Maestro flows exist (e.g. an OAuth flow), record HTTP traffic via
Proxyman if installed; analyze for cert-pinning behavior. Skip if Proxyman
isn't installed.

### Phase 3: Tier 2 — AI reasoning

Read the per-pass Tier 0 + Tier 1 outputs, apply each pass's AI heuristic
from `references/passes/NN-*.md`. Score 1–5 per pass per the shared rubric.

### Phase 4: Source cross-reference

For every finding, read the relevant source file, identify exact
`file:line`, determine root cause, propose a fix (Swift code diff),
classify severity per `_ios-shared/scoring-rubric-shared.md`. All security
findings are marked `auto_fixable: false`.

### Phase 5: Report

Write three artifacts to `<project-root>/ios-audit/ios-security-audit/`:

- `report.md` — full narrative per `_ios-shared/report-template-shared.md`
- `scorecard.md` — quick-reference
- `findings.json` — machine-readable for the orchestrator

**AI Layer 4 (narrative)**: write the executive summary as a security
engineer would. Lead with the highest severity finding. Reference the
OWASP MASVS control IDs (MSTG-STORAGE-1, MSTG-NETWORK-3, etc.). Cite
Apple Platform Security Guide sections.

### Phase 6 (only if `--linear`): file issues

Group findings by theme (e.g. "token-storage" rolls up multiple secrets/
Keychain findings into one Linear issue). One issue per theme. Label
`["security", "iOS"]`. Priority per shared rubric severity→priority map.

## Rules

- **Never auto-fix.** Security migrations need human review by policy.
- **Always cite the standard.** Every finding references a MASVS control
  ID, an Apple security guide section, or an RFC. No taste-based
  recommendations.
- **Cross-reference with `/ios-code-review`**. If a Keychain wrapper
  exists but is misused, defer naming to the code-review skill.
- **Cross-reference with `/ios-backend-audit`**. If a network call
  bypasses ATS, both audits flag it; the security audit owns the
  *security* aspect, backend owns the *correctness* aspect.
- **Read the entire `Info.plist` and every `.entitlements` file.** Never
  rely on grep alone for security-sensitive config.
- **Flag the absence of security controls, not just the presence of
  flaws.** Missing biometric auth, missing cert pinning, missing
  Keychain usage — all count.
- **MASVS L1 minimum.** Apps without an explicit threat model are
  assumed to need L1. If the project explicitly opts in to L2 (handles
  financial data, health data, government), upgrade the scoring rubric.

## Reference files

- `references/passes/01-secrets-storage.md` — UserDefaults / source / env-var leak detection
- `references/passes/02-keychain-usage.md` — Correct Keychain API use, biometric-protected items
- `references/passes/03-ats-config.md` — `NSAppTransportSecurity` review
- `references/passes/04-cert-pinning.md` — URLSession delegate cert pinning, AppAuth/Alamofire patterns
- `references/passes/05-biometric-auth.md` — `LocalAuthentication`, `LAPolicy`, Face ID / Touch ID
- `references/passes/06-cryptokit-usage.md` — CryptoKit vs CommonCrypto, key derivation, nonce handling
- `references/passes/07-jailbreak-detection.md` — Optional RASP / jailbreak detection (MASVS-RESILIENCE)
- `references/passes/08-input-validation.md` — VisionKit/ML/PDF input attack surface
- `references/passes/09-third-party-libs.md` — SPM/CocoaPods CVE check
- `references/passes/10-code-obfuscation.md` — String encryption, symbol stripping (MASVS-RESILIENCE)
- `references/scoring-rubric.md` — Extends shared rubric with the 10 security pass weights
- `references/report-template.md` — Extends shared report template
- `references/tech-stack.md` — Curated tools matrix with current URLs
- `references/deep-references.md` — OWASP MAS, Apple Platform Security, RFCs, WWDC sessions
- `scripts/install-tools.sh` — Installs mobsfscan, Proxyman if requested
- `scripts/mobsf-scan.sh` — Runs mobsfscan with JSON output
- `scripts/keychain-static-scan.sh` — Greps for Keychain API patterns
- `scripts/ats-extract.sh` — Reads `Info.plist` ATS config to JSON
