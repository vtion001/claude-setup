# Shared Scoring Rubric — iOS Audit Suite

The 6 iOS audit skills + the orchestrator all use this exact rubric.
Per-skill `references/scoring-rubric.md` files extend it with the pass list
and weight assignments specific to that audit's domain — they do NOT
redefine the formula, scale, or interpretation tables.

---

## Per-Pass 1–5 Scale

Every pass scores on a 1–5 integer scale. Half-points are never used.

| Score | Label | Criteria |
|---|---|---|
| **5** | Best-practice | Matches the Apple-published / industry standard. No findings of any severity. |
| **4** | Good | Minor stylistic deviation. At most 1–2 Low-severity findings. No actionable issue. |
| **3** | Acceptable | Functional but with measurable room for improvement. Mix of Low + 1–2 Medium findings. |
| **2** | Poor | Measurable impact on quality, security, or user experience. At least one High finding. |
| **1** | Critical | Actively broken or insecure. At least one Critical finding. |

---

## Weighted Score Formula

```
weighted_sum = Σ (pass_score × pass_weight)
max_weighted_sum = Σ (5 × pass_weight)
score_out_of_100 = (weighted_sum / max_weighted_sum) × 100
```

- Pass weights are integers 1, 2, or 3
- Weight rationales are documented in each skill's `scoring-rubric.md`
- **No single pass can exceed weight 3** — keeps the rubric stable

## Per-Skill Score Acronyms

| Skill | Acronym | Meaning |
|---|---|---|
| `/ios-ui-impl-audit` | **UIQ-iOS** | UI Implementation Quality |
| `/ios-backend-audit` | **BNH-iOS** | Backend / Networking Health |
| `/ios-integration-audit` | **INT-iOS** | Integration Health |
| `/ios-security-audit` | **SEC-iOS** | Security Posture (mirrors OWASP MASVS levels) |
| `/ios-qa-audit` | **QAH-iOS** | QA Health |
| `/ios-code-review` | **CRQ-iOS** | Code Review Quality |
| `/ios-audit-pipeline` | **iHS** | Combined iOS Health Score (weighted across the 6) |

## Combined iOS Health Score (orchestrator)

The pipeline computes `iHS` as a weighted average across the 6 audit scores.
Default weights below; user may override via flag.

| Audit | Weight | Rationale |
|---|---|---|
| security | 3× | Security regressions ship-block more than anything else |
| backend | 2× | Concurrency / persistence bugs are high-blast-radius |
| ui-impl | 2× | A11y and Dynamic Type failures affect every user |
| qa | 2× | Test gaps multiply other risks |
| integration | 1× | Per-feature; bounded impact |
| code-review | 1× | Style/dead-code; quality of life |

```
iHS = Σ (audit_score × audit_weight) / Σ (100 × audit_weight) × 100
```

---

## Score Range Interpretation

Both per-skill (UIQ, BNH, etc.) and the combined iHS use the same ranges.

| Range | Label | Meaning |
|---|---|---|
| **90–100** | Ship-ready | Production quality, monitor only. |
| **75–89** | Production-ready | Minor cleanup recommended. |
| **60–74** | Needs attention | Address before the next release. |
| **40–59** | Design debt | Material risk; plan a focused sprint. |
| **< 40** | Critical | Block-shipping. Address Critical/High findings before merging anything else. |

---

## Severity → Linear Priority Mapping

When `--linear` is passed, findings are filed at this priority:

| Severity | Linear Priority | When |
|---|---|---|
| **Critical** | Urgent (1) | Security risks, data corruption, app store rejection risks, accessibility violations affecting core flows |
| **High** | High (2) | Concurrency bugs, broken integrations, missing essential test coverage, ATS misconfigurations |
| **Medium** | Medium (3) | Style/consistency drift, suboptimal performance patterns, minor a11y issues |
| **Low** | Low (4) | Code organization, dead code, minor naming inconsistencies |

---

## Severity Calibration (when scoring is ambiguous)

When a finding could be 2 or 3, ask:

1. **Will it ship a bug to users?** → 2 or below
2. **Will it cause a security review failure?** → 1 (Critical)
3. **Will a junior dev be confused reading this in 6 months?** → 3 at minimum
4. **Is this the recommended pattern in current Apple docs?** → 4–5
5. **Does this match a WWDC-recommended pattern?** → 5

When in doubt, score down (be honest, not generous). The audit's value
is calibration; inflated scores destroy trust.

---

## Cross-finding Themes (orchestrator AI Layer 3)

The orchestrator's synthesis pass groups findings across audits when they
share a root cause. Example themes from a Pookoo baseline:

- **"Token storage"** — touched by security (UserDefaults plaintext),
  backend (no Keychain), code-review (no test coverage of token refresh)
- **"Main-thread contention"** — touched by backend (`@MainActor` I/O),
  ui-impl (jank during scan), qa (no XCTMetric coverage)
- **"Dark mode"** — touched by ui-impl (no ColorScheme), code-review
  (hardcoded `Color.white`), qa (no snapshot tests across schemes)

Themes get one Linear issue per theme, not per finding, when `--linear` runs.
