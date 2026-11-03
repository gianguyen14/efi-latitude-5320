#!/bin/sh
# Collects what is needed to analyse a sleep/wake attempt or a display
# reconnection, into ~/Library/Logs/wex-capture/<time>-<label>/.
#
# Usage: sh wexcapture.sh <label> [minutes]
#   label    sleep, hdmi, usbc, ... (names the folder)
#   minutes  how far back to read logs (default 20; after a forced restart,
#            use the minutes since the attempt so the previous boot is included)
# Boot once with -wexdiag to include WhateverXe's TGL*/WEX* display records.
set -u
label=${1:-capture}
minutes=${2:-20}
out="$HOME/Library/Logs/wex-capture/$(date +%Y%m%d-%H%M%S)-$label"
mkdir -p "$out"
log=/usr/bin/log

uptime > "$out/uptime.txt"
nvram boot-args > "$out/boot-args.txt" 2>&1

# Power: sleep/wake history, current reasons and blockers.
pmset -g log | awk '$4=="Sleep"||$4=="Wake"||$4=="DarkWake"||$4=="Failure"||$4=="WakeRequests"||$4=="Start"||$4=="ShutdownCause"' \
  | tail -60 > "$out/pmset-events.txt"
pmset -g > "$out/pmset.txt"
pmset -g assertions > "$out/pmset-assertions.txt" 2>&1
ioreg -rn IOPMrootDomain -d1 -w0 | grep -E '"(Last Sleep Reason|Wake Reason|Wake Type|SleepWakeUUID|IOSleepSupported|System Capabilities)"' \
  > "$out/rootdomain.txt"

# Kernel: power transitions, framebuffer/AGDP, GPU and WhateverXe messages.
$log show --last "${minutes}m" --style compact --predicate 'process == "kernel" AND (
  eventMessage CONTAINS "PMRD" OR eventMessage CONTAINS[c] "wake" OR eventMessage CONTAINS[c] "sleep" OR
  eventMessage CONTAINS "AppleIntelFramebuffer" OR eventMessage CONTAINS "AGDP" OR eventMessage CONTAINS "IGPU" OR
  eventMessage CONTAINS "igfx" OR eventMessage CONTAINS "TGL" OR eventMessage CONTAINS "GPU hang" OR
  eventMessage CONTAINS "GPURestart" OR eventMessage CONTAINS[c] "hotplug" OR eventMessage CONTAINS "HPD")' \
  > "$out/kernel.txt" 2>&1
$log show --last "${minutes}m" --style compact --predicate '(process == "WindowServer" OR process == "powerd") AND
  (messageType == error OR messageType == fault OR eventMessage CONTAINS[c] "display" OR eventMessage CONTAINS[c] "wake")' \
  2>/dev/null | tail -400 > "$out/windowserver-powerd.txt"

# Reports written around the attempt.
find /Library/Logs/DiagnosticReports "$HOME/Library/Logs/DiagnosticReports" -maxdepth 1 -type f \
  -mmin "-$minutes" \( -name '*.gpuRestart' -o -name '*Sleep*' -o -name '*.panic' -o -name '*.ips' -o -name '*.hang' \) \
  -exec cp {} "$out/" \; 2>/dev/null

# Displays and framebuffers.
system_profiler SPDisplaysDataType > "$out/displays.txt" 2>&1
ioreg -rc AppleIntelFramebuffer -d1 -w0 | grep -E 'AppleIntelFramebuffer@|"(IOFBConfig|IOFBCurrentPixelCount|IOFBTransform|AAPL,DisplayPipe|IOFBDetailedTimings)"' \
  | cut -c1-300 > "$out/framebuffers.txt"
# WhateverXe records (registry root only with -wexdiag).
ioreg -l -w0 -d1 | grep -E '"(TGL|WEX|WhateverXe)[A-Za-z0-9]*" =' | cut -c1-600 > "$out/wex-records.txt"

echo "$out"
