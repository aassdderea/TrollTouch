#!/bin/sh
DOCS="/var/mobile/Containers/Data/Application"
APP=$(ls -t "$DOCS" | head -1)
PLIST="$DOCS/$APP/Documents/com.trolltouch.command.plist"

/usr/bin/plutil -create xml1 "$PLIST" 2>/dev/null || true
/usr/bin/plutil -replace mode -string "auto" "$PLIST"
/usr/bin/notifyutil -p com.trolltouch.run
echo "Auto skip mode started"
