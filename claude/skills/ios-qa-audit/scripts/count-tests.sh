#!/usr/bin/env bash
# count-tests.sh — Tally XCTest + Swift Testing test methods across the project.
set -eu
ROOT="${1:-$PWD}"
cd "$ROOT"

XCTEST_FILES=$(grep -rln --include='*.swift' 'class.*: XCTestCase' . 2>/dev/null | wc -l | tr -d ' ')
XCTEST_METHODS=$(grep -rn --include='*.swift' -E '^\s*func test[A-Z]' . 2>/dev/null | wc -l | tr -d ' ')
SWIFT_TESTING_FILES=$(grep -rln --include='*.swift' '@Test\|@Suite\|import Testing' . 2>/dev/null | wc -l | tr -d ' ')
SWIFT_TESTING_METHODS=$(grep -rn --include='*.swift' '@Test' . 2>/dev/null | wc -l | tr -d ' ')
SNAPSHOT_TESTS=$(grep -rln --include='*.swift' 'assertSnapshot\|SnapshotTesting' . 2>/dev/null | wc -l | tr -d ' ')
PERF_TESTS=$(grep -rln --include='*.swift' 'measure(metrics:\|XCTMetric' . 2>/dev/null | wc -l | tr -d ' ')

cat <<EOF
{
  "xctest_files": $XCTEST_FILES,
  "xctest_methods": $XCTEST_METHODS,
  "swift_testing_files": $SWIFT_TESTING_FILES,
  "swift_testing_methods": $SWIFT_TESTING_METHODS,
  "snapshot_test_files": $SNAPSHOT_TESTS,
  "perf_test_files": $PERF_TESTS
}
EOF
