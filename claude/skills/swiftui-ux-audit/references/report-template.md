# Report Template

This template is the SwiftUI sibling of the web report template. The skeleton
is identical; iOS-specific sections replace web-specific ones.

For the parts that are unchanged — executive-summary writing voice, theme
grouping, impact/effort estimation guidance — read the web template at
`/Users/archerterminez/.claude/skills/ux-audit/references/report-template.md`
verbatim.

---

## Output files

Write all three to `<project-root>/swiftui-ux-audit/`:

1. `report.md` — full narrative
2. `scorecard.md` — quick-reference
3. `screenshots/<tab>_<device>_<timestamp>.png` — every captured screen

---

## `report.md` skeleton

```markdown
# SwiftUI UX Audit — <Project Name>

**Date:** <YYYY-MM-DD>
**Scheme:** <scheme>
**Bundle ID:** <bundle.id>
**Devices:** <iPhone 16, iPad Air, ...>
**Tabs audited:** <home, flights, tips, assistant, settings>
**Passes run:** <14 / 14 OR subset>
**DQS:** <0–100>
**DCS:** <0–100>

## Executive summary

<3–6 paragraphs in senior-iOS-designer voice. Root-cause patterns, themes,
prioritization by impact-to-effort, effort in sprint-friendly terms. iOS
vocabulary — Dynamic Type, HIG, SF Symbols, haptics, transitions — not
generic web language.>

## Themes

<One section per identified theme. Each theme groups multiple findings
with a unified fix.>

### Theme 1: <name>

- **Severity range:** <Low → High>
- **Affected tabs:** <list>
- **Affected files:** <count>
- **Unified fix:** <one paragraph>
- **Effort:** <S / M / L sprint-friendly>
- **Findings rolled up:**
  - <ID> — <one-line>
  - …

## Per-tab results

### Tab: Home (Entry: home)

**DQS:** <score>   **Findings:** <C/H/M/L counts>

**Screenshot:**
![Home — iPhone 16](screenshots/home_iPhone16_<ts>.png)

**Pass scores:**

| Pass | Score | Weight | Weighted |
|---|---|---|---|
| Visual hierarchy | 4 | 3× | 12 |
| Typography | 3 | 2× | 6 |
| … | … | … | … |

**Findings:**

#### F-001 — <title>
- **Severity:** <Critical/High/Medium/Low>
- **Pass:** <hierarchy / typography / a11y / tokens / …>
- **File:** `Pookoo/Views/Home/HomeView.swift:42`
- **Root cause:** <one sentence>
- **Recommended fix:**
  ```diff
  - .font(.system(size: 17, weight: .semibold))
  + .font(PukaTypography.headline)
  ```
- **Auto-fixable:** <yes / no, reason>

### Tab: Flights …

(repeat per tab)

## Cross-tab consistency (DCS)

**Score:** <0–100>

Drift detected on:

- **Typography**: 18 sites use raw `.font(.system(...))`. Dominant pattern on Home: `PukaTypography.body`. Unify by …
- **Cornering**: 83 sites use raw `.cornerRadius(N)`. …
- **Color**: …

## Accessibility audit (XCUI)

Results from `XCUIApplication.performAccessibilityAudit(for: .all)` per tab:

| Tab | Contrast | Hit region | Dynamic type | Sufficient desc | Text clipped | Trait | Total |
|---|---|---|---|---|---|---|---|
| Home | 0 | 2 | 1 | 5 | 0 | 1 | 9 |
| … | … | … | … | … | … | … | … |

## Design tokens (static)

Token file used: `<Pookoo/Utils/Theme.swift>`

| Violation | Count | Sample file:line |
|---|---|---|
| Raw `.font(.system(...))` outside Theme.swift | 230 | `Pookoo/Views/Assistant/AssistantView.swift:284` |
| Raw `.padding(N)` integer literal | 2 | `Pookoo/Views/Tips/TipsSubmitView.swift:75` |
| Raw `.cornerRadius(N)` integer literal | 83 | `Pookoo/Views/Settings/SettingsView.swift:275` |
| `Color(hex:)` outside Models/ + Theme | 0 | — |

## Performance perception

| Metric | Value | Threshold | Pass |
|---|---|---|---|
| Cold launch (median over 5) | 1.42s | < 2.0s | ✅ |
| Frame drops on Home scroll | 3 | < 5 | ✅ |
| … | … | … | … |

## Methodology

- Driver: Maestro <version> + XCUITest (for `performAccessibilityAudit`) + `xcrun simctl`
- Build: `xcodebuild -scheme <s> -configuration Debug -destination 'platform=iOS Simulator,id=<UDID>'`
- Devices: <list>
- Token file: <path>
- Skill: `swiftui-ux-audit` at `~/.claude/skills/swiftui-ux-audit/`

## Auto-fix log (only when --fix used)

Applied <N> fixes, escalated <M>:

| ID | File | Type | Status |
|---|---|---|---|
| F-001 | …Home/GreetingHeaderView.swift:18 | raw-font → token | applied |
| F-007 | …Settings/SettingsView.swift:275 | raw-radius → token | escalated (closure on same line) |
```

---

## `scorecard.md` skeleton

```markdown
# Scorecard — <Project Name>

```
┌─────────────────────────────────────────────────────────────────┐
│  DESIGN QUALITY OVERVIEW                                        │
├──────────────────────┬──────┬────────┬──────────────────────────┤
│  Tab                 │  DQS │ Rating │ Findings (C/H/M/L)      │
├──────────────────────┼──────┼────────┼──────────────────────────┤
│  Home                │ 82.5 │ Good   │ 0 / 1 / 3 / 2           │
│  Flights             │ 74.2 │ Needs  │ 0 / 2 / 5 / 3           │
│  Tips                │ 68.3 │ Needs  │ 1 / 1 / 4 / 1           │
│  Assistant           │ 71.0 │ Needs  │ 0 / 1 / 4 / 2           │
│  Settings            │ 78.4 │ Good   │ 0 / 0 / 3 / 1           │
├──────────────────────┼──────┼────────┼──────────────────────────┤
│  OVERALL             │ 74.9 │ Needs  │ 1 / 5 / 19 / 9          │
│  Consistency (DCS)   │ 76.0 │ Good   │                          │
└──────────────────────┴──────┴────────┴──────────────────────────┘
```

## Top 5 themes

1. **Typography token drift** — High — 230 sites, unify on `PukaTypography.*`
2. **Corner-radius literals** — Medium — 83 sites, introduce/use `PukaRadius`
3. **Missing accessibility labels** — High — 9 contrast + 18 description findings from XCUI
4. **Cold-launch time** — Low — 1.42s, within budget
5. **Tab-bar hit regions** — Medium — XCUI flagged 2

## Auto-fixable

<N> of <M> findings are safe to auto-apply with `/swiftui-ux-audit --fix`.
```

---

## Writing-voice rules (from the web template, restated)

- Speak as a senior iOS designer reviewing a colleague's work.
- Lead with strengths before deficiencies.
- Group findings by root-cause theme, not by pass.
- Quantify effort in sprint-friendly terms (S / M / L), not hours.
- Be specific: cite tab, file:line, screenshot reference.
- Don't repeat what the table already shows — narrate, don't enumerate.
- Use iOS vocabulary: Dynamic Type, SF Symbols, haptics, HIG, transitions, the
  System fonts, safe-area, large-title vs inline title, navigation stack,
  modal vs sheet presentation. Avoid "page", "viewport", "hover" — they're
  web concepts.
