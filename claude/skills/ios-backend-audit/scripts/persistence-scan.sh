#!/usr/bin/env bash
# persistence-scan.sh — Static scan for persistence mechanisms.
set -eu
ROOT="${1:-$PWD}"
cd "$ROOT"

USERDEFAULTS=$(grep -rn --include='*.swift' 'UserDefaults\.standard\.\(set\|object\|setValue\|stringArray\)' . 2>/dev/null | wc -l | tr -d ' ')
APPSTORAGE=$(grep -rn --include='*.swift' '@AppStorage' . 2>/dev/null | wc -l | tr -d ' ')
SWIFTDATA=$(grep -rln --include='*.swift' 'import SwiftData\|@Model' . 2>/dev/null | wc -l | tr -d ' ')
COREDATA=$(grep -rln --include='*.swift' 'NSManagedObjectContext\|import CoreData' . 2>/dev/null | wc -l | tr -d ' ')
GRDB=$(grep -rln --include='*.swift' 'import GRDB' . 2>/dev/null | wc -l | tr -d ' ')
REALM=$(grep -rln --include='*.swift' 'import RealmSwift' . 2>/dev/null | wc -l | tr -d ' ')
FILEMANAGER=$(grep -rn --include='*.swift' 'FileManager\.default\.\(write\|create\|copy\|remove\)' . 2>/dev/null | wc -l | tr -d ' ')

cat <<EOF
{
  "userdefaults_calls": $USERDEFAULTS,
  "appstorage_uses": $APPSTORAGE,
  "swiftdata_files": $SWIFTDATA,
  "coredata_files": $COREDATA,
  "grdb_files": $GRDB,
  "realm_files": $REALM,
  "filemanager_writes": $FILEMANAGER
}
EOF
