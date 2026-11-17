#!/bin/sh
# Records why the CPU clock drops: powermetrics (per-core frequency, package
# power, plimits, thermal) while cpuclock runs idle, 1-thread and 8-thread
# phases. Run with sudo; writes ~/cpulimit-<time>.txt for the login user.
# Usage: sudo sh cpulimit_probe.sh
set -e
cd "$(dirname "$0")"
user=${SUDO_USER:-$(stat -f %Su /dev/console)}
home=$(dscl . -read /Users/"$user" NFSHomeDirectory | awk '{print $2}')
out="$home/cpulimit-$(date +%Y%m%d-%H%M%S).txt"
work=$(mktemp -d)
clang -O1 cpuclock.c -o "$work/cpuclock"

{
	echo "# $(date)  $(sysctl -n machdep.cpu.brand_string)"
	pmset -g therm
	pmset -g batt
} > "$out"

powermetrics -s cpu_power,thermal,smc --show-plimits -i 1000 -n 75 >> "$out" 2>&1 &
pm=$!
sleep 2
# --show-plimits is only available on some platforms.
if ! kill -0 "$pm" 2>/dev/null; then
	powermetrics -s cpu_power,thermal,smc -i 1000 -n 73 >> "$out" 2>&1 &
	pm=$!
fi
sleep 8
echo "# phase idle done $(date +%T)" >> "$out.phases"
"$work/cpuclock" 1 20 >> "$out.phases" 2>&1
echo "# phase 1-thread done $(date +%T)" >> "$out.phases"
"$work/cpuclock" 8 40 >> "$out.phases" 2>&1
echo "# phase 8-thread done $(date +%T)" >> "$out.phases"
wait "$pm" || true
cat "$out.phases" >> "$out"
rm -rf "$work" "$out.phases"
chown "$user" "$out"
echo "Saved $out"
