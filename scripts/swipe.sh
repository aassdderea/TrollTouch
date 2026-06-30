#!/bin/sh
# 用法: swipe.sh <x1> <y1> <x2> <y2> [steps] [delay_ms]
# 示例: swipe.sh 200 700 200 300 20 16

if [ $# -lt 4 ]; then
    echo "Usage: $0 <x1> <y1> <x2> <y2> [steps] [delay_ms]"
    exit 1
fi

X1="$1"; Y1="$2"; X2="$3"; Y2="$4"
STEPS="${5:-20}"
DELAY_MS="${6:-16}"
PLIST="/var/mobile/Library/Preferences/com.trolltouch.command.plist"

i=0
while [ $i -le $STEPS ]; do
    X=$(awk "BEGIN {printf \"%.1f\", $X1 + ($X2 - $X1) * $i / $STEPS}")
    Y=$(awk "BEGIN {printf \"%.1f\", $Y1 + ($Y2 - $Y1) * $i / $STEPS}")

    /usr/bin/plutil -create xml1 "$PLIST" 2>/dev/null || true
    /usr/bin/plutil -replace x -float "$X" "$PLIST"
    /usr/bin/plutil -replace y -float "$Y" "$PLIST"
    /usr/bin/plutil -replace duration -float "0.02" "$PLIST"
    /usr/bin/notifyutil -p com.trolltouch.run

    sleep "0.0$(printf '%02d' "$DELAY_MS")"
    i=$((i + 1))
done

echo "Swipe done: ($X1,$Y1) -> ($X2,$Y2) steps=$STEPS"
