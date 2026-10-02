#!/usr/bin/env bash
# Verifies the app archives cleanly without code signing.
set -euo pipefail
cd "$(dirname "$0")/.."

xcodebuild archive \
    -project Atlas.xcodeproj \
    -scheme Atlas \
    -destination 'generic/platform=iOS' \
    -archivePath build/Atlas.xcarchive \
    CODE_SIGNING_ALLOWED=NO \
    | grep -E "error:|ARCHIVE" || true

APP="build/Atlas.xcarchive/Products/Applications/Atlas.app"
if [ ! -d "$APP" ]; then
    echo "archive-check: FAIL — $APP missing"
    exit 1
fi

VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Info.plist")
BUILD=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$APP/Info.plist")
echo "archive-check: OK — Atlas.app version $VERSION ($BUILD)"
