#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

APP="${1:-build/Notchy.app}"
IDENTITY="Notchy Local Signing"
CONFIGURATION="${NOTCHY_CONFIGURATION:-release}"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources/hooks"
cp ".build/$CONFIGURATION/Notchy" "$APP/Contents/MacOS/Notchy"
cp Resources/Info.plist "$APP/Contents/Info.plist"
iconutil -c icns Resources/AppIcon.iconset -o "$APP/Contents/Resources/AppIcon.icns"
cp hooks/*.py "$APP/Contents/Resources/hooks/"
for folder in Resources/*.lproj; do
    if [ -d "$folder" ]; then
        cp -R "$folder" "$APP/Contents/Resources/"
    fi
done
if [ -n "${NOTCHY_FINGERPRINT:-}" ]; then
    printf '%s' "$NOTCHY_FINGERPRINT" > "$APP/Contents/Resources/build.fingerprint"
fi

if security find-identity -v -p codesigning 2>/dev/null | grep -q "\"$IDENTITY\""; then
    codesign --force --sign "$IDENTITY" "$APP"
else
    codesign --force --sign - "$APP"
fi
