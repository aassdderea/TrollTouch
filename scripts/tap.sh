#!/bin/sh
DOCS="/var/mobile/Containers/Data/Application"
APP=$(ls -t "$DOCS" | head -1)
PLIST="$DOCS/$APP/Documents/com.trolltouch.command.plist"

if [ $# -lt 2 ]; then echo "Usage: tap.sh <x> <y>"; exit 1; fi

/usr/bin/plutil -create xml1 "$PLIST" 2>/dev/null || true
/usr/bin/plutil -replace mode  -string "tap" "$PLIST"
/usr/bin/plutil -replace x     -float "$1" "$PLIST"
/usr/bin/plutil -replace y     -float "$2" "$PLIST"
/usr/bin/notifyutil -p com.trolltouch.run
echo "Sent tap at ($1, $2)"
