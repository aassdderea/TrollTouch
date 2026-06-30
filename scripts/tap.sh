#!/bin/sh
# 用法: tap.sh <x> <y> [duration_seconds]
# 示例: tap.sh 200 400 0.05

if [ $# -lt 2 ]; then
    echo "Usage: $0 <x> <y> [duration]"
    exit 1
fi

X="$1"
Y="$2"
DURATION="${3:-0.05}"
PLIST="/var/mobile/Library/Preferences/com.trolltouch.command.plist"

/usr/bin/plutil -create xml1 "$PLIST" 2>/dev/null || true
/usr/bin/plutil -replace x -float "$X" "$PLIST"
/usr/bin/plutil -replace y -float "$Y" "$PLIST"
/usr/bin/plutil -replace duration -float "$DURATION" "$PLIST"

/usr/bin/notifyutil -p com.trolltouch.run

echo "Tap sent: ($X, $Y) duration=${DURATION}s"
