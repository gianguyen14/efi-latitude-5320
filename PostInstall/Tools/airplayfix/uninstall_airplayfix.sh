#!/bin/sh
# Removes the AirPlay fix. Run WITHOUT sudo.
launchctl bootout "gui/$(id -u)/com.gianguyen14.airplayfix" 2>/dev/null || true
launchctl unsetenv DYLD_INSERT_LIBRARIES
rm -f "$HOME/Library/LaunchAgents/com.gianguyen14.airplayfix.plist"
rm -rf "$HOME/Library/Application Support/AirPlayFix"
killall ControlCenter 2>/dev/null || true
echo "Removed."
