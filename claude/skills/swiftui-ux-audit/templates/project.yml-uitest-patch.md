# Manual UI-test target patch (for non-XcodeGen projects)

When `--bootstrap` is invoked on a project that uses XcodeGen (`project.yml`),
the skill runs `scripts/bootstrap-uitest.sh` automatically.

For non-XcodeGen projects, follow this procedure manually.

## In Xcode (GUI)

1. File → New → Target…
2. Pick **iOS → UI Testing Bundle**
3. Name it `<AppName>UITests` (replace `<AppName>` with the actual scheme/target name)
4. Set "Target to be Tested" to your app target
5. Finish

## Drop in the runner

Copy this skill's template into the new target's source folder:

```bash
cp ~/.claude/skills/swiftui-ux-audit/scripts/a11y-audit-runner.swift \
   <ProjectRoot>/<AppName>UITests/A11yAuditTests.swift
```

## Confirm deployment target

`XCUIApplication.performAccessibilityAudit(for:_:)` requires iOS 17+. If the
UI-test target's minimum is below iOS 17, raise it. The app target can stay
where it is — only the UI-test target needs iOS 17+.

## Run once to verify

```bash
xcodebuild test \
  -scheme <AppName> \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:<AppName>UITests/A11yAuditTests/testFullAuditAllTabs \
  AUDIT_TABS="home,flights,tips,assistant,settings" \
  AUDIT_OUTPUT_PATH="$PWD/swiftui-ux-audit/.xcui-a11y.json"
```

A JSON file should appear at the AUDIT_OUTPUT_PATH containing all detected
accessibility issues per tab. The skill consumes this file for Pass 09.

## XcodeGen reference (what `--bootstrap` does)

If you prefer to migrate to XcodeGen, the patch this skill applies to
`project.yml` looks like:

```yaml
targets:
  # ... existing app + unit-test targets unchanged ...

  <AppName>UITests:
    type: bundle.ui-testing
    platform: iOS
    sources:
      - path: <AppName>UITests
    settings:
      TEST_TARGET_NAME: <AppName>
```

Then `xcodegen generate` to rebuild the `.xcodeproj`.
