# Safety Guardrails for iOS Audit `--fix` Mode (Swift)

These guardrails prevent any of the iOS audit skills' auto-fix mode from
modifying code that affects app behavior, data flow, navigation, persistence,
or security. `--fix` is restricted to **non-behavioral, mechanical Swift
transformations only** — and security-related findings are NEVER auto-fixable.

This file is the shared canonical sibling of the language-agnostic
`safety-guardrails.md` in `~/.claude/skills/ux-audit/references/`. Each
iOS audit skill's local `safety-guardrails-swift.md` may extend this with
domain-specific NEVER-MODIFY rules but must never relax these baselines.

---

## NEVER-MODIFY LIST (baseline for all iOS audits)

### 1. Property wrappers
`@State`, `@Binding`, `@StateObject`, `@ObservedObject`, `@EnvironmentObject`,
`@Environment`, `@AppStorage`, `@SceneStorage`, `@FocusState`, `@Published`,
`@MainActor`, `@Observable`, `@Bindable`, `@SectionedFetchRequest`,
`@FetchRequest`, `@Query` (SwiftData)

**Why:** Property wrappers drive view state, persistence, and observation.
Touching them risks data loss, broken bindings, or infinite re-render loops.

### 2. Concurrency
`actor`, `Task { ... }`, `Task.detached`, `await`, `async`, `@MainActor`,
`withCheckedContinuation`, `withTaskGroup`, `withThrowingTaskGroup`,
`AsyncStream`, `AsyncSequence`, `Sendable` conformances, `nonisolated`,
`@globalActor`, `isolated` parameters

**Why:** Concurrency primitives govern thread safety. Even cosmetic-looking
edits inside an `actor` can introduce data races.

### 3. Persistence + I/O
`UserDefaults.standard.set/object(forKey:)`, `JSONEncoder/JSONDecoder`,
`URLSession`, `URLRequest`, `URLSession.shared.data(for:)`, `FileManager`,
`PropertyListEncoder/Decoder`, `Codable` conformances on model types,
`SwiftData`/`@Model`, Core Data (`NSManagedObjectContext`), Keychain access
(`SecItemAdd/Copy/Update/Delete`), `kSecAttr*` constants, `CryptoKit` calls

**Why:** Persistence, network, and crypto code controls data integrity.
Auto-fix never has business to touch any of it.

### 4. Service singletons + business logic
Any `static let shared` declaration. Any call to a `.shared` singleton
(detected at Phase 0 from the project's `Services/` directory or equivalent).
Any class/struct conforming to `ObservableObject` or marked `@Observable`.

**Why:** Services contain business logic and cross-cutting state.

### 5. Navigation state
`@State private var <flag>` used as `isPresented:` binding for `.sheet(...)`,
`.fullScreenCover(...)`, `.popover(...)`. `appState.selectedTab` and other
`@EnvironmentObject` selection state. `NavigationStack`, `NavigationLink`,
`.navigationDestination`, `.onOpenURL`, deep-link parsing logic.

**Why:** Touching navigation can silently rewire deep links or break the back stack.

### 6. Event handlers + gestures
`action: { ... }` closures on `Button`, `.onTapGesture { }`,
`.onLongPressGesture`, `.onChange(of:)`, `.onAppear`, `.onDisappear`,
`.onReceive`, `.onSubmit`, `.gesture(...)`, `.simultaneousGesture(...)`,
`.highPriorityGesture`, `.refreshable`, any closure that mutates state or
calls a service.

**Why:** Event handlers carry user-flow logic. Style changes must never cross
into a closure body.

### 7. View model code + functions
Any non-`var body: some View` function on a `View`-conforming type.
Anything inside a `class` that conforms to `ObservableObject` or is marked
`@Observable`. `init(...)` of view types.

**Why:** Auto-fix only touches view-body modifiers. Functions and init contain logic.

### 8. Build configuration
`project.yml` (except via `--bootstrap`), `*.xcconfig`, `Info.plist`,
`*.entitlements`, `*.xcscheme`, `Package.swift`, build settings,
`Bundle.main` references, `Makefile`, `scripts/release/*`

**Why:** Project config changes can break the build or change
signing/capability flags.

### 9. Test code
Anything under `*Tests/`, `*UITests/`, `*.xctestplan`, snapshot reference
directories, Maestro flow YAML.

**Why:** Tests are the safety net for `--fix` itself. Never edit
automatically.

### 10. Third-party SDK calls + integrations
Firebase, Sentry, Mixpanel, Amplitude, GoogleSignIn, Stripe, RevenueCat,
PostHog, AppAuth, any external SDK method call. App Intents
(`AppIntent`/`@Parameter`), App Shortcuts, WidgetKit configurations.

**Why:** SDK calls handle billing, analytics, OAuth, and external comms.

### 11. Security-sensitive code (NEVER auto-fix, even for /ios-security-audit)
Token storage migrations, Keychain attribute changes, ATS exception edits,
certificate-pinning code, biometric auth flows, crypto algorithm changes,
jailbreak-detection logic, RASP hooks, code obfuscation directives.

**Why:** Security migrations need human review by definition. The audit's
job is to flag and recommend, not to apply.

### 12. App Intents, Widgets, Live Activities, App Clips
`AppIntent`, `AppShortcutsProvider`, `Widget`, `ActivityAttributes`,
`AppClip`, `Bundle.main` extensions.

**Why:** These touch system-level integrations Apple validates at App Review.

---

## SAFE-TO-MODIFY LIST (the only allowed transformations)

These are mechanical, presentational substitutions. Apply only when the
5-step pre-flight passes.

### A. Raw font literals → design-token fonts
```swift
// BEFORE
.font(.system(size: 16))
// AFTER (token name from detected Theme file)
.font(PukaTypography.body)
```
Match by nearest size + weight combination from the detected typography
scale. If no match within ±1pt, skip and escalate.

### B. Raw padding literals → spacing tokens
```swift
// BEFORE
.padding(16)
// AFTER
.padding(PukaSpacing.md)
```
Match by exact value. No fuzzy match.

### C. Raw corner-radius literals → radius tokens or card modifiers
```swift
// BEFORE
.cornerRadius(20)
// AFTER
.pukaCard()
```
Apply card-modifier substitution only when the same expression already has
the matching `.background(...)` + `.shadow(...)` pair the modifier provides.

### D. Legacy color-alias references → canonical color
Only when CLAUDE.md or the design-token file explicitly marks the alias
as deprecated.

### E. Standalone `.shadow(...)` literals → elevation modifier
Only when the literal exactly matches the modifier's signature.

### F. Add missing accessibility modifiers (warn-only by default)
`.accessibilityLabel(...)`, `.accessibilityHint(...)`,
`.accessibilityAddTraits(.isButton)` on elements that lack them.
**Always per-finding confirmation** — the audit's recommendation may not
match the developer's intent.

---

## PRE-FLIGHT VALIDATION CHECKLIST (5 steps)

Before applying ANY modification, all 5 must pass.

### Step 1: Scope check
- [ ] Read the target file completely (no offset reads)
- [ ] Confirm the change touches only items on the SAFE-TO-MODIFY list
- [ ] Confirm the change is inside a `var body: some View` (or a
      `@ViewBuilder` function), not inside an `action:` closure or
      `onChange/onTap/onAppear` body

### Step 2: Dependency trace
- [ ] `grep -r "<targetSymbol>"` to find all references
- [ ] If the symbol is referenced by name in tests or by string-key in
      any logic, abort
- [ ] For modifier substitutions, confirm the modifier is defined in
      the detected design-system file

### Step 3: Behavioral isolation
- [ ] The changed line contains no `@State`/`@Binding` declaration
- [ ] The changed line is not inside an `action:` closure parameter list
- [ ] No NEVER-MODIFY item appears on the same line OR within the same
      view-modifier chain expression
- [ ] The change does not alter the visible text of an interactive element

### Step 4: Reversibility
- [ ] The change can be undone with a single `git checkout` of the file
- [ ] The change does not require regenerating the Xcode project
- [ ] The change does not require updating snapshot test references

### Step 5: Dry-run validation
- [ ] Generate the exact diff before applying
- [ ] Log the diff to `<skill>/fix-diffs/<finding-id>.diff`
- [ ] Confirm the diff changes ≤ 5 lines per finding (more → escalate)
- [ ] Confirm the file still parses after the change

---

## ESCALATION TEMPLATE

```markdown
## ESCALATION: Manual Fix Required

**Finding ID:** [FINDING-ID]
**Severity:** [Critical/High/Medium/Low]
**File:** [path/to/File.swift:line]
**Pass:** [Which audit pass identified this]

### What Needs to Change
[Describe the issue]

### Why Auto-Fix Cannot Apply
[Specific reason from NEVER-MODIFY]

### Recommended Manual Fix
\`\`\`diff
- [current Swift]
+ [proposed Swift]
\`\`\`

### Risk Assessment
- **Behavioral impact:** [None expected / Possible side effect]
- **Files affected:** [List importing files]
- **Test coverage:** [Y/N + which tests]

### Verification Steps
1. Build for iPhone 17 simulator
2. Visual diff if applicable
3. Run targeted XCUITest if a UI-test target exists
```

---

## Summary rules

1. **When in doubt, escalate.** A missed fix is always better than a broken view.
2. **One finding, one fix.** Never batch into a single edit.
3. **Log everything.** Every applied fix and every skip is written to the audit report.
4. **Preserve formatting.** Match the file's indentation, quote style, trailing-comma style.
5. **Never add imports.** Auto-fix must not add `import` statements.
6. **Never add files.** Auto-fix touches only files that contain a flagged finding.
7. **Never run `xcodegen generate`.** That's only for `--bootstrap`, and only with explicit confirm.
8. **Security findings are NEVER auto-fixable** regardless of severity. The audit flags + recommends; the human migrates.
