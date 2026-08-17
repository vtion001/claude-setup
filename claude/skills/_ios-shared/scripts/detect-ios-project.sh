#!/usr/bin/env bash
# detect-ios-project.sh — Phase 0 auto-detect for every iOS audit skill.
#
# Probes cwd for an iOS project and emits a JSON document describing
# what was found. Used by every audit skill so detection is consistent.
#
# Usage:
#   detect-ios-project.sh [project-root] > /tmp/ios-detect.json
#   (no arg = use $PWD)
#
# Exit 0 if an iOS project is detected, non-zero otherwise.

set -eu

ROOT="${1:-$PWD}"
cd "$ROOT"

# Detection order: project.yml (XcodeGen) → *.xcworkspace → *.xcodeproj → Package.swift
PROJECT_FORMAT=""
PROJECT_FILE=""
SCHEME=""
BUNDLE_ID=""
DEPLOYMENT_TARGET=""
DESIGN_TOKEN_FILE=""

if [ -f "project.yml" ]; then
    PROJECT_FORMAT="xcodegen"
    PROJECT_FILE="project.yml"
    SCHEME=$(grep -E "^    name:" project.yml 2>/dev/null | head -1 | awk '{print $2}' || echo "")
    [ -z "$SCHEME" ] && SCHEME=$(grep -E "^  [A-Z][a-zA-Z]+:$" project.yml 2>/dev/null | head -1 | sed 's/[: ]//g' || echo "")
    BUNDLE_ID=$(grep "PRODUCT_BUNDLE_IDENTIFIER" project.yml | head -1 | awk -F': ' '{print $2}' | tr -d ' "' || echo "")
    DEPLOYMENT_TARGET=$(grep "deploymentTarget" project.yml | head -1 | awk -F': ' '{print $2}' | tr -d ' "' || echo "")
elif ls *.xcworkspace > /dev/null 2>&1; then
    PROJECT_FORMAT="xcworkspace"
    PROJECT_FILE=$(ls -d *.xcworkspace | head -1)
elif ls *.xcodeproj > /dev/null 2>&1; then
    PROJECT_FORMAT="xcodeproj"
    PROJECT_FILE=$(ls -d *.xcodeproj | head -1)
elif [ -f "Package.swift" ]; then
    PROJECT_FORMAT="spm"
    PROJECT_FILE="Package.swift"
else
    echo '{"detected": false, "error": "No iOS project at '"$ROOT"'"}'
    exit 1
fi

# Fall back to xcodebuild -list if SCHEME wasn't extracted from yml
if [ -z "$SCHEME" ] && command -v xcodebuild > /dev/null 2>&1; then
    case "$PROJECT_FORMAT" in
        xcodeproj)
            SCHEME=$(xcodebuild -list -project "$PROJECT_FILE" -json 2>/dev/null \
                | python3 -c "import sys, json; d=json.load(sys.stdin); print(d['project']['schemes'][0])" 2>/dev/null || echo "")
            ;;
        xcworkspace)
            SCHEME=$(xcodebuild -list -workspace "$PROJECT_FILE" -json 2>/dev/null \
                | python3 -c "import sys, json; d=json.load(sys.stdin); print(d['workspace']['schemes'][0])" 2>/dev/null || echo "")
            ;;
    esac
fi

# Design-token file detection (Theme.swift / Tokens.swift / DesignSystem.swift variants)
for candidate in \
    "Utils/Theme.swift" "DesignSystem/Theme.swift" "Theme.swift" \
    "Tokens.swift" "DesignTokens.swift" \
    "*/Utils/Theme.swift" "*/DesignSystem/Theme.swift"; do
    found=$(find . -maxdepth 4 -path "$candidate" -type f 2>/dev/null | head -1)
    if [ -n "$found" ]; then
        DESIGN_TOKEN_FILE="$found"
        break
    fi
done

if [ -z "$DESIGN_TOKEN_FILE" ]; then
    DESIGN_TOKEN_FILE=$(find . -maxdepth 5 -type f -name "*.swift" 2>/dev/null \
        | xargs grep -l "static let.*Color(hex" 2>/dev/null | head -1 || echo "")
fi

# Services directory (Pookoo pattern: Pookoo/Services/)
SERVICES_DIR=$(find . -maxdepth 4 -type d -name "Services" 2>/dev/null | head -1 || echo "")
SERVICE_COUNT=0
if [ -n "$SERVICES_DIR" ]; then
    SERVICE_COUNT=$(find "$SERVICES_DIR" -maxdepth 1 -name "*.swift" 2>/dev/null | wc -l | tr -d ' ')
fi

# Test target presence
HAS_UNIT_TESTS="false"
HAS_UI_TESTS="false"
SNAPSHOT_TESTING="false"
[ -d "${SCHEME}Tests" ] || [ -d "*Tests" ] && HAS_UNIT_TESTS="true"
[ -d "${SCHEME}UITests" ] || [ -d "*UITests" ] && HAS_UI_TESTS="true"
if grep -rq "SnapshotTesting" --include="*.swift" --include="Package.swift" --include="project.yml" . 2>/dev/null; then
    SNAPSHOT_TESTING="true"
fi

# Maestro flows
MAESTRO_FLOWS_DIR=""
for candidate in "swiftui-ux-audit/flows" "maestro" ".maestro" "tests/maestro" "ios-audit/flows"; do
    if [ -d "$candidate" ]; then
        MAESTRO_FLOWS_DIR="$candidate"
        break
    fi
done

# Dependency model
DEPENDENCY_MODEL="none"
[ -f "Podfile" ] && DEPENDENCY_MODEL="cocoapods"
[ -f "Cartfile" ] && DEPENDENCY_MODEL="carthage"
if [ -f "Package.swift" ] || grep -q "packages:" project.yml 2>/dev/null; then
    DEPENDENCY_MODEL="spm"
fi

# Lint config
SWIFTLINT="false"
SWIFTFORMAT="false"
[ -f ".swiftlint.yml" ] && SWIFTLINT="true"
[ -f ".swiftformat" ] && SWIFTFORMAT="true"

# Emit JSON
cat <<EOF
{
  "detected": true,
  "root": "$ROOT",
  "project_format": "$PROJECT_FORMAT",
  "project_file": "$PROJECT_FILE",
  "scheme": "$SCHEME",
  "bundle_id": "$BUNDLE_ID",
  "deployment_target": "$DEPLOYMENT_TARGET",
  "design_token_file": "$DESIGN_TOKEN_FILE",
  "services_dir": "$SERVICES_DIR",
  "service_count": $SERVICE_COUNT,
  "has_unit_tests": $HAS_UNIT_TESTS,
  "has_ui_tests": $HAS_UI_TESTS,
  "snapshot_testing": $SNAPSHOT_TESTING,
  "maestro_flows_dir": "$MAESTRO_FLOWS_DIR",
  "dependency_model": "$DEPENDENCY_MODEL",
  "swiftlint": $SWIFTLINT,
  "swiftformat": $SWIFTFORMAT
}
EOF
