#!/bin/sh
# Builds vtbgra.dylib and installs a login LaunchAgent for the current user. Run WITHOUT sudo.
set -e
cd "$(dirname "$0")"
D="$HOME/Library/Application Support/AirPlayFix"
mkdir -p "$D" "$HOME/Library/LaunchAgents"
clang -arch x86_64 -dynamiclib -O1 -framework VideoToolbox -framework CoreMedia -framework CoreVideo -framework CoreFoundation -o "$D/vtbgra.dylib" vtbgra.c
codesign -f -s - "$D/vtbgra.dylib"
install -m 755 airplayfix.sh "$D/airplayfix.sh"
sed "s#__SCRIPT__#$D/airplayfix.sh#" com.gianguyen14.airplayfix.plist > "$HOME/Library/LaunchAgents/com.gianguyen14.airplayfix.plist"
launchctl bootout "gui/$(id -u)/com.gianguyen14.airplayfix" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$HOME/Library/LaunchAgents/com.gianguyen14.airplayfix.plist"
echo "Installed. ControlCenter restarts now; turn AirPlay mirroring off and on again."
