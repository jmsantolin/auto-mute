#!/bin/bash
# Construit Auto-mute.app et, avec --install, le place dans /Applications.
set -euo pipefail

cd "$(dirname "$0")"
VERSION="1.0.0"
APP="build/Auto-mute.app"

rm -rf build && mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

swiftc -O -framework AppKit -framework ServiceManagement \
    Sources/main.swift -o "$APP/Contents/MacOS/Auto-mute"

cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleName</key>
	<string>Auto-mute</string>
	<key>CFBundleDisplayName</key>
	<string>Auto-mute</string>
	<key>CFBundleIdentifier</key>
	<string>com.jmsantolin.auto-mute</string>
	<key>CFBundleExecutable</key>
	<string>Auto-mute</string>
	<key>CFBundleIconFile</key>
	<string>AppIcon</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleShortVersionString</key>
	<string>$VERSION</string>
	<key>CFBundleVersion</key>
	<string>$VERSION</string>
	<key>LSMinimumSystemVersion</key>
	<string>13.0</string>
	<key>LSUIElement</key>
	<true/>
	<key>NSHumanReadableCopyright</key>
	<string>Jean-Marc Santolin</string>
</dict>
</plist>
PLIST

codesign --force --sign - "$APP" >/dev/null 2>&1 || true
echo "construit : $APP"

if [ "${1:-}" = "--install" ]; then
    osascript -e 'quit app "Auto-mute"' >/dev/null 2>&1 || true
    pkill -x Auto-mute 2>/dev/null || true
    sleep 1
    rm -rf /Applications/Auto-mute.app
    cp -R "$APP" /Applications/
    echo "installé : /Applications/Auto-mute.app"
    open /Applications/Auto-mute.app
fi
