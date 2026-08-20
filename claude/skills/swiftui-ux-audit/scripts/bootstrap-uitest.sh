#!/usr/bin/env bash
# bootstrap-uitest.sh — add a UI-test target to the project's project.yml
# (XcodeGen) and copy the a11y-audit-runner.swift template into place.
#
# Only runs when --bootstrap is invoked. Shows the diff before applying.
#
# Usage:
#   bootstrap-uitest.sh <project-root> <app-scheme-name>

set -eu

ROOT="${1:?project root required}"
SCHEME="${2:?app scheme name required}"

cd "$ROOT"

if [ ! -f "project.yml" ]; then
    echo "bootstrap-uitest.sh requires XcodeGen (project.yml not found)." >&2
    echo "For non-XcodeGen projects, follow templates/project.yml-uitest-patch.md manually." >&2
    exit 2
fi

UITEST_TARGET="${SCHEME}UITests"
UITEST_DIR="${SCHEME}UITests"

# Backup
cp project.yml "project.yml.swiftui-ux-audit.bak.$(date +%s)"

# Idempotent: if the UI-test target already exists, do nothing.
if grep -q "bundle\.ui-testing" project.yml; then
    echo "UI-test target already present in project.yml; nothing to do."
    exit 0
fi

# Append the target block. XcodeGen is YAML; we append at the bottom of
# `targets:` mapping. We do NOT attempt to re-sort.
cat >> project.yml <<YAML

  ${UITEST_TARGET}:
    type: bundle.ui-testing
    platform: iOS
    sources:
      - path: ${UITEST_DIR}
    settings:
      TEST_TARGET_NAME: ${SCHEME}
YAML

mkdir -p "$UITEST_DIR"
# Copy the template if it's not already there.
if [ ! -f "$UITEST_DIR/A11yAuditTests.swift" ]; then
    cp "$(dirname "$0")/a11y-audit-runner.swift" "$UITEST_DIR/A11yAuditTests.swift"
fi

# Regenerate xcodeproj
if command -v xcodegen >/dev/null 2>&1; then
    xcodegen generate
    echo "Bootstrap complete. Run: xcodebuild test -scheme $SCHEME -only-testing:${UITEST_TARGET}/A11yAuditTests"
else
    echo "xcodegen not installed. Install with: brew install xcodegen"
    exit 2
fi
