#!/bin/sh
# Installs freezewatch as a per-user LaunchAgent. Run without sudo.
# Remove with: launchctl bootout gui/$(id -u)/com.gianguyen14.freezewatch
# and delete ~/Library/LaunchAgents/com.gianguyen14.freezewatch.plist.
set -e
cd "$(dirname "$0")"
support="$HOME/Library/Application Support/freezewatch"
plist="$HOME/Library/LaunchAgents/com.gianguyen14.freezewatch.plist"
mkdir -p "$support" "$HOME/Library/LaunchAgents"
clang -O1 smcsensors.c -o "$support/smcsensors" -framework IOKit
codesign -s - -f "$support/smcsensors"
install -m 755 freezewatch.sh "$support/freezewatch.sh"
# No ProcessType Background: throttling would stall the log under memory pressure.
cat > "$plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>Label</key>
	<string>com.gianguyen14.freezewatch</string>
	<key>ProgramArguments</key>
	<array>
		<string>/bin/sh</string>
		<string>$support/freezewatch.sh</string>
	</array>
	<key>RunAtLoad</key>
	<true/>
	<key>KeepAlive</key>
	<true/>
	<key>LimitLoadToSessionType</key>
	<string>Aqua</string>
</dict>
</plist>
EOF
launchctl bootout "gui/$(id -u)/com.gianguyen14.freezewatch" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$plist"
sleep 3
tail -2 "$HOME/Library/Logs/freezewatch/"*.log
