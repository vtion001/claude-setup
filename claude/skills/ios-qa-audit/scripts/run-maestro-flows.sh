#!/usr/bin/env bash
# run-maestro-flows.sh — Run all Maestro flows in a directory against a device.
set -eu
FLOWS="${1:-flows/}"
UDID="${2:-5F8D5C74-5D1C-43CA-9325-45DDA228B43B}"   # iPhone 17 default

if [ ! -d "$FLOWS" ]; then
    echo "[run-maestro-flows] No flow dir at $FLOWS — skipping"
    exit 0
fi

DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
JAVA_HOME=/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home \
~/.maestro/bin/maestro --udid "$UDID" test "$FLOWS" 2>&1 | tail -40
