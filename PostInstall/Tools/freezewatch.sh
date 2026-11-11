#!/bin/sh
# Records the memory and GPU state every 30 s and warns before memory runs out.
# Each boot gets ~/Library/Logs/freezewatch/<boot time>.log. Lines are synced to
# disk, so the last line after a forced power-off shows the state before a
# freeze. Metal command buffers leak through WindowServer (WhateverXe#47), and
# the kernel can hold only 16 M compressed pages (64 GiB uncompressed).
#
# Usage: sh freezewatch.sh [once]
#   once  take one sample and exit
# Fields: time, uptime_s, compressed % of the page limit, compressed GiB, swap
# MB, memorystatus level, load, GPU recoveries, CPU C, package W, front app,
# top apps by memory.
set -u
dir="$HOME/Library/Logs/freezewatch"
smc="$HOME/Library/Application Support/freezewatch/smcsensors"
interval=${FREEZEWATCH_INTERVAL:-30}
warn_pct=${FREEZEWATCH_WARN_PCT:-60}
critical_pct=${FREEZEWATCH_CRITICAL_PCT:-85}
warn_swap_mb=${FREEZEWATCH_WARN_SWAP_MB:-4096}
mkdir -p "$dir"
boot=$(sysctl -n kern.boottime | sed -E 's/^\{ sec = ([0-9]+).*/\1/')
log="$dir/$(date -r "$boot" +%Y%m%d-%H%M%S).log"
limit=$(sysctl -n vm.compressor_segment_pages_compressed_limit)
ls -t "$dir"/*.log 2>/dev/null | tail -n +31 | while read -r old; do rm -f "$old"; done
last_alert=0

append() {
  perl -MIO::Handle -e 'open(my $f, ">>", $ARGV[0]) or exit 1; print $f "$ARGV[1]\n"; $f->flush; $f->sync' "$log" "$1"
}

sample() {
  now=$(date +%s)
  pages=$(vm_stat | awk '/stored in compressor/ {gsub(/\./, "", $NF); print $NF}')
  pct=$((pages * 100 / limit))
  gib=$((pages / 262144))
  swap=$(sysctl -n vm.swapusage | sed -E 's/.*used = ([0-9]+)\..*/\1/')
  level=$(sysctl -n kern.memorystatus_level)
  load=$(sysctl -n vm.loadavg | awk '{print $2}')
  recoveries=$(ioreg -rc IntelAccelerator -d1 -w0 | grep -oE '"recoveryCount"=[0-9]+' | head -1 | cut -d= -f2)
  front=$(lsappinfo info -only name "$(lsappinfo front)" 2>/dev/null | sed -E 's/.*="(.*)"/\1/')
  apps=$(top -l 1 -o mem -n 4 -stats mem,command 2>/dev/null | awk '/^MEM/ {f=1; next} f {m=$1; $1=""; sub(/^ /, ""); printf "%s%s=%s", s, $0, m; s=","}')
  sensors=$([ -x "$smc" ] && "$smc")
  temp=$(printf '%s' "$sensors" | sed -nE 's/.*TC0P\(sp78\)=([0-9.]+).*/\1/p')
  watts=$(printf '%s' "$sensors" | sed -nE 's/.*PCTR\(sp96\)=([0-9.]+).*/\1/p')
  append "$(date +%T) up=$((now - boot)) comp=${pct}% ${gib}GiB swap=${swap}MB level=$level load=$load gpu_recov=${recoveries:-?} temp=${temp:-?} pkg=${watts:-?}W front=$front apps=$apps"
}

alert() {
  cooldown=900
  [ "$pct" -ge "$critical_pct" ] && cooldown=300
  [ "$pct" -ge "$warn_pct" ] || [ "$swap" -ge "$warn_swap_mb" ] || return 0
  [ $((now - last_alert)) -ge "$cooldown" ] || return 0
  last_alert=$now
  osascript -e "display notification \"Bộ nhớ nén ${pct}% giới hạn, swap ${swap} MB. Nên lưu việc rồi đăng xuất.\" with title \"RAM sắp đầy\" sound name \"Basso\"" >/dev/null 2>&1
}

while :; do
  sample
  alert
  [ "${1:-}" = once ] && exit 0
  sleep "$interval"
done
