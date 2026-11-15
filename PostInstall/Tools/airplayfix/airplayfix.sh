#!/bin/sh
# Runs at login: restarts ControlCenter with vtbgra.dylib so the AirPlay receiver decodes to BGRA.
LIB="$HOME/Library/Application Support/AirPlayFix/vtbgra.dylib"
[ -f "$LIB" ] || exit 0
launchctl setenv DYLD_INSERT_LIBRARIES "$LIB"
killall ControlCenter 2>/dev/null
sleep 5
launchctl unsetenv DYLD_INSERT_LIBRARIES
