# Pass 09 — Third-Party Library Hygiene

**Weight:** 2× (1× when no third-party deps)
**MASVS:** MASVS-CODE-1, MASVS-CODE-2
**MSTG:** MSTG-CODE-1 through MSTG-CODE-6

## What this audits

Every external dependency the app links — what it is, what version,
known CVEs, maintenance status, license compliance.

## Tier 0 — static

Read in this order:
- `Package.resolved` (SPM canonical lockfile)
- `Podfile.lock` (CocoaPods)
- `Cartfile.resolved` (Carthage)
- `project.yml` `packages:` block (XcodeGen SPM)

Emit one dependency per line:
```json
{
  "deps": [
    {"name": "AppAuth-iOS", "version": "1.7.5", "source": "https://github.com/openid/AppAuth-iOS"}
  ]
}
```

For each, run:
- **OSV check**: `curl -s https://api.osv.dev/v1/query -d '{"package":{"name":"AppAuth-iOS","ecosystem":"SwiftURL"},"version":"1.7.5"}'`
- **GitHub last-commit check** (maintained = commit in last 12 months)

## Scoring (1–5)

| Score | Criteria |
|---|---|
| 5 | All deps at latest minor. No known CVEs. All actively maintained (commit in last 6 months). Licenses compatible. |
| 4 | All deps secure. 1-2 deps with last commit 6-12 months ago. |
| 3 | All deps secure but some 1+ year stale OR 1-2 deps at one major version behind. |
| 2 | One dep with a known CVE that doesn't affect this app's usage. |
| 1 | One or more deps with an exploitable CVE affecting this app's usage, OR a dep that's been unmaintained for 2+ years and is on the critical path. |

## Common findings + severity

| Finding | Severity |
|---|---|
| Dependency with CRITICAL CVE affecting usage | **Critical** |
| Dependency with HIGH CVE affecting usage | **High** |
| Dependency with CVE but mitigated by usage pattern | **Medium** (document the mitigation) |
| Dependency unmaintained 2+ years, on critical path | **High** |
| Dependency unmaintained 1+ year, off critical path | **Low** |
| License conflict (GPL in commercial closed-source) | **High** |

## Pookoo-specific note

Pookoo has zero external dependencies. This pass scores **5/5** with a
note: "Dependency-free app. Future deps must be added to this audit's
allowlist."

## Recommended fixes

- Upgrade to latest minor version
- For CRITICAL CVEs: pin to a fork that backports the fix, or migrate to
  an alternative library
- For unmaintained deps: evaluate replacements; add to risk register

## What NOT to flag

- Apple-published libraries (CryptoKit, swift-async-algorithms, etc.) —
  managed by Apple
- Internal Swift packages that live in the same monorepo
- Build-only deps that don't ship in the binary (XcodeGen, Maestro)
