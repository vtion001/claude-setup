# Safety Guardrails for `--fix` Mode (Swift)

These guardrails prevent the SwiftUI UX-audit auto-fix from modifying any code
that affects app behavior, data flow, navigation, or persistence. `--fix` is
restricted to **visual and presentational Swift changes only**.

This file is the Swift-language sibling of the web skill's `safety-guardrails.md`.
Same two-list shape, same 5-step pre-flight, same escalation template.

---

## NEVER-MODIFY LIST

The following Swift constructs must NEVER be altered by auto-fix, regardless of context.

### 1. Property wrappers
`@State`, `@Binding`, `@StateObject`, `@ObservedObject`, `@EnvironmentObject`,
`@Environment`, `@AppStorage`, `@SceneStorage`, `@FocusState`, `@Published`,
`@MainActor`, `@Observable`, `@Bindable`

**Why:** Property wrappers drive view state, persistence, and observation. Touching them risks data loss, broken bindings, or infinite re-render loops.

### 2. Concurrency
`actor`, `Task { ... }`, `Task.detached`, `await`, `async`, `@MainActor`,
`withCheckedContinuation`, `withTaskGroup`, `AsyncStream`, `AsyncSequence`,
`Sendable` conformances, `nonisolated`

**Why:** Concurrency primitives govern thread safety. Even cosmetic-looking edits inside an `actor` can introduce data races.

### 3. Persistence + I/O
`UserDefaults.standard.set/object(forKey:)`, `JSONEncoder/JSONDecoder`,
`URLSession`, `URLRequest`, `URLSession.shared.data(for:)`, `FileManager`,
`PropertyListEncoder/Decoder`, `Codable` conformances on model types,
`SwiftData`/`@Model`, `Core Data` (`NSManagedObjectContext`), `Keychain` access

**Why:** Persistence and network code controls data integrity. Auto-fix never has business to touch it.

### 4. Service singletons + business logic
`*.shared` references to known services (auto-detected from project), e.g.
`LocalAIService.shared`, `NotificationService.shared`, `LocationService.shared`,
`GmailService.shared`, `BoardingPassExtractor.shared`, `SocialTipStore.shared`,
any `static let shared` declaration.

**Why:** Services contain business logic and cross-cutting state.

### 5. Navigation state
`@State private var <flag>` used as `isPresented:` binding for `.sheet(...)`,
`appState.selectedTab` and other `@EnvironmentObject` selection state,
`NavigationStack`, `NavigationLink`, `.onOpenURL`, `.fullScreenCover`,
`.navigationDestination`

**Why:** Touching navigation can silently rewire deep links or break the back stack.

### 6. Event handlers + gestures
`action: { ... }` closures on `Button`, `.onTapGesture { }`, `.onLongPressGesture`,
`.onChange(of:)`, `.onAppear`, `.onDisappear`, `.onReceive`, `.onSubmit`,
`.gesture(...)`, `.simultaneousGesture(...)`, `.highPriorityGesture`,
any closure that mutates state or calls a service

**Why:** Event handlers carry user-flow logic. Style changes must never cross into a closure body.

### 7. View model code + functions
Any non-`var body: some View` function on a `View`-conforming type.
Anything inside a `class` that conforms to `ObservableObject` or is marked `@Observable`.
`init(...)` of view types.

**Why:** Auto-fix only touches view-body modifiers. Functions and init contain logic.

### 8. Build configuration
`project.yml` (except via `--bootstrap`), `*.xcconfig`, `Info.plist`,
`*.entitlements`, `*.xcscheme`, `Package.swift`, build settings,
`Bundle.main` references

**Why:** Project config changes can break the build or change signing/capability flags.

### 9. Test code
Anything under `*Tests/` or `*UITests/` directories.

**Why:** Tests are the safety net for the fix mode itself. Never edit them automatically.

### 10. Third-party SDK calls
Firebase, Sentry, Mixpanel, Amplitude, GoogleSignIn, Stripe, RevenueCat,
PostHog, any external SDK method call.

**Why:** SDK calls handle billing, analytics, and external comms.

---

## SAFE-TO-MODIFY LIST

These are the only transformations `--fix` may apply, and only when the 5-step pre-flight passes.

### A. Raw font literals → design-token fonts

```swift
// BEFORE
.font(.system(size: 16))
.font(.system(size: 17, weight: .semibold, design: .rounded))

// AFTER (token name from detected Theme file)
.font(PukaTypography.body)
.font(PukaTypography.headline)
```

Match by nearest size + weight combination from the detected typography scale. If no match within ±1pt, **skip and escalate**.

### B. Raw padding literals → spacing tokens

```swift
// BEFORE
.padding(16)
.padding(.horizontal, 24)

// AFTER
.padding(PukaSpacing.md)
.padding(.horizontal, PukaSpacing.lg)
```

Match by exact value. No fuzzy match. Skip if value is not in the spacing scale.

### C. Raw corner-radius literals → radius tokens or card modifiers

```swift
// BEFORE
.cornerRadius(20)

// AFTER (when a radius scale exists)
.cornerRadius(PukaRadius.card)

// OR — when a card modifier already exists in the design system
.pukaCard()
```

Apply card-modifier substitution only when the same expression already has the matching `.background(...)` + `.shadow(...)` pair the card modifier provides. Otherwise stick to the radius token.

### D. Legacy color-alias references → canonical color

```swift
// BEFORE (only when aliases are documented as deprecated in CLAUDE.md)
.foregroundColor(.pukaCoral)

// AFTER
.foregroundColor(.pukaGreen)
```

Only apply when project docs explicitly mark the alias as deprecated. Never auto-apply across all aliases blindly.

### E. Standalone `.shadow(...)` literals → elevation modifier

```swift
// BEFORE
.shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 4)

// AFTER (when an elevation modifier exists)
.pukaElevatedCard()
```

Only when the literal exactly matches the modifier's signature.

### F. Decorative text strings (warn-only)

Strings inside `Text("...")` that the AI flags as confusing or off-brand. Never apply without explicit user confirmation **per-string**, even within `--fix`.

---

## PRE-FLIGHT VALIDATION CHECKLIST (5 steps)

Before applying ANY modification, all 5 must pass.

### Step 1: Scope check
- [ ] Read the target file completely (no offset reads)
- [ ] Confirm the change touches only items on the SAFE-TO-MODIFY list above
- [ ] Confirm the change is inside a `var body: some View` (or a `@ViewBuilder` function), not inside an `action:` closure or `onChange/onTap/onAppear` body

### Step 2: Dependency trace
- [ ] `grep -r "<targetSymbol>"` to find all references
- [ ] If the symbol being replaced is referenced by name in tests or by string-key in any logic, abort
- [ ] For modifier-method substitutions (e.g. `.pukaCard()`), confirm the modifier is defined in the detected design-system file (don't introduce undefined modifiers)

### Step 3: Behavioral isolation
- [ ] The changed line contains no `@State`/`@Binding` declaration
- [ ] The changed line is not inside the parameter list of an `action:` closure
- [ ] No NEVER-MODIFY item appears on the same line OR within the same view-modifier chain expression
- [ ] The change does not alter the visible text of an interactive element

### Step 4: Reversibility
- [ ] The change can be undone with a single `git checkout` of the file
- [ ] The change does not require regenerating the Xcode project (`xcodegen generate`)
- [ ] The change does not require updating snapshot test references

### Step 5: Dry-run validation
- [ ] Generate the exact diff before applying
- [ ] Log the diff to `swiftui-ux-audit/fix-diffs/<finding-id>.diff`
- [ ] Confirm the diff changes ≤ 5 lines per finding (more → escalate)
- [ ] Confirm the file still parses after the change (run `swift -frontend -parse <file>` if available; otherwise rely on the diff being mechanical)

---

## ESCALATION TEMPLATE

```markdown
## ESCALATION: Manual Fix Required

**Finding ID:** [FINDING-ID]
**Severity:** [Critical/High/Medium/Low]
**File:** [Pookoo/Views/.../File.swift:line]
**Pass:** [Which audit pass identified this]

### What Needs to Change
[Describe the visual/UX issue]

### Why Auto-Fix Cannot Apply
[Specific reason from NEVER-MODIFY, e.g. "raw .font(.system(size: 17)) on the same line as a Button(action:) closure that mutates appState.selectedTab"]

### Recommended Manual Fix
```diff
- [current Swift]
+ [proposed Swift]
```

### Risk Assessment
- **Behavioral impact:** [None expected / Possible side effect]
- **Files affected:** [List importing files]
- **Test coverage:** [Y/N + which tests]

### Verification Steps
1. Build for iPhone 16 simulator
2. Visual diff the affected screen against the screenshot in the audit report
3. Run `xcodebuild test -only-testing:PookooUITests` if a UI-test target exists
```

---

## Summary rules

1. **When in doubt, escalate.** A missed fix is always better than a broken view.
2. **One finding, one fix.** Never batch into a single edit.
3. **Log everything.** Every applied fix and every skip is written to the audit report and to `fix-diffs/`.
4. **Preserve formatting.** Match the file's indentation, quote style, trailing-comma style.
5. **Never add imports.** Auto-fix must not add `import` statements. If a token isn't already accessible from the file's current imports, escalate.
6. **Never add files.** Auto-fix touches only files that contain a flagged finding.
7. **Never run `xcodegen generate`.** That's only for `--bootstrap`, and only with explicit confirm.
