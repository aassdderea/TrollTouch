#!/bin/sh
PLIST="/var/mobile/Library/Preferences/com.trolltouch.command.plist"
/usr/bin/plutil -create xml1 "$PLIST" 2>/dev/null || true
/usr/bin/plutil -replace mode -string "auto" "$PLIST"
/usr/bin/notifyutil -p com.trolltouch.run
echo "Auto skip mode started"
