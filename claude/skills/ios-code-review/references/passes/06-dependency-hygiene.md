# Pass 06 — Dependency Hygiene

**Weight:** 3×

## What this audits
SPM/CocoaPods/Carthage: pinned versions, lockfile committed, no abandoned
deps, sensible coupling.

## Tier 0
- `Package.resolved` present in git?
- `Podfile.lock` present in git?
- For each dep: pinned to exact version or range?
- Last commit date of each dep (>12 months = stale)
- Total dep count (raw number is a heuristic; high coupling is risk)

## Scoring
| Score | Criteria |
|---|---|
| 5 | All deps exact-pinned, lockfile committed, all actively maintained, justified |
| 4 | Mostly pinned, one open range (e.g. "from: 1.0.0") |
| 3 | Mix; some loose ranges, one stale dep |
| 2 | Lockfile missing OR several stale deps |
| 1 | No lockfile committed; deps drift on every machine |

## Common findings
| Finding | Severity |
|---|---|
| `Package.resolved` not in git | **High** |
| Open ranges (`from: "1.0.0"`) on Critical deps | **Medium** |
| Dep unmaintained 2+ years on critical path | **High** |
| Duplicate functionality across deps (e.g. two HTTP clients) | **Medium** |
| Heavy dep used for one tiny utility function | **Low** |

## Pookoo-specific
Pookoo has zero external deps. Score 5/5 with a note: "Dependency-free.
If/when deps are added, this pass must run before merging." Already
covered by `/ios-security-audit` pass 09 from the CVE angle.

## What NOT to flag
- Build-time only deps (XcodeGen, Maestro)
- Apple-published SPM packages (auto-maintained)
