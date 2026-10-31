#!/bin/sh
# Builds btpin and installs it as a LaunchDaemon. Run with sudo.
set -e
cd "$(dirname "$0")"
clang -O2 -Wall btpin.c -o /tmp/btpin
codesign -s - -f /tmp/btpin
mkdir -p /usr/local/libexec
install -m 755 -o root -g wheel /tmp/btpin /usr/local/libexec/btpin
rm -f /tmp/btpin
install -m 644 -o root -g wheel com.gianguyen14.btpin.plist /Library/LaunchDaemons/
launchctl bootout system/com.gianguyen14.btpin 2>/dev/null || true
launchctl bootstrap system /Library/LaunchDaemons/com.gianguyen14.btpin.plist
sleep 2
cat /var/log/btpin.log
