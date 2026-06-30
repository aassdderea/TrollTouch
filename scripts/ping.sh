#!/bin/sh
RESULT="/var/mobile/Library/Preferences/com.trolltouch.result.plist"
/usr/bin/notifyutil -p com.trolltouch.ping
sleep 1
/usr/bin/plutil -p "$RESULT"
