#!/bin/bash
# Upgrade WhateverXe Graphics 0.4.0 -> 0.4.4 safely, with a backup and a rollback.
#
#   sh gfx044.sh check      no sudo: verify the downloaded package and show the current state
#   sh gfx044.sh backup     sudo: copy the current Graphics files and AuxKC to a backup folder
#   sh gfx044.sh install    sudo: run the 0.4.4 installer (it rebuilds AuxKC itself)
#   sh gfx044.sh rollback   sudo: restore the last backup (then restart)
#   sh gfx044.sh verify     no sudo: run after the restart, shows what is actually loaded
#
# The package was downloaded and expanded, not installed, on 2026-11-21.
# After installing, remove -wexxferfix -wexvafix -wexleakfix from boot-args in the ESP config.plist
# before the restart: the 0.4.4 VA driver page is pristine, so -wexxferfix would match it again and
# break hardware H.264 encode.
set -eu
PKG=/Users/nguyen/Developer/OpenCore-reference/Graphics-0.4.4-download/pkg/WhateverXe-Graphics-0.4.4.pkg
SHA=f4c2d680a7c52c33a3f038ce6945da0aa2cc044e62b935a52ea046c7c473cfec
TGLVA_NEW=18e32dd5fd02d192ab3e13961239f304e1d7e1bf9855c6b8bf1137aa51cb7a4e
BACKUP_ROOT=/Users/nguyen/gfx-backups
LATEST=$BACKUP_ROOT/latest
export PATH=/usr/bin:/bin:/usr/sbin:/sbin

need_root() { [ "$(id -u)" = 0 ] || { echo "Run this with sudo: sudo sh $0 $1"; exit 1; }; }

check_pkg() {
  [ -f "$PKG" ] || { echo "package missing: $PKG"; exit 1; }
  got=$(shasum -a 256 "$PKG" | awk '{print $1}')
  [ "$got" = "$SHA" ] && echo "package sha256 OK" || { echo "package sha256 MISMATCH ($got)"; exit 1; }
}

case "${1:-}" in
check)
  check_pkg
  echo "receipts:"; pkgutil --pkgs | grep -i whateverxe | while read p; do echo "  $p $(pkgutil --pkg-info "$p" | awk '/version/ {print $2}')"; done
  echo "free disk: $(df -h /Users/nguyen | tail -1 | awk '{print $4}')"
  echo "boot-args wex flags: $(nvram boot-args | tr ' ' '\n' | grep -E '^-wex' | tr '\n' ' ')"
  echo "mediaanalysisd/photoanalysisd: $(launchctl print-disabled gui/$(id -u) | grep -E 'mediaanalysisd|photoanalysisd' | tr -s ' \t' ' ' | tr '\n' ' ')"
  ;;
backup)
  need_root backup
  check_pkg
  B=$BACKUP_ROOT/$(date +%Y%m%d-%H%M%S)-graphics-0.4.0
  mkdir -p "$B/Extensions"
  rsync -a /Library/GPUBundles/ "$B/GPUBundles/"
  for k in /Library/Extensions/AppleIntelTGL*.kext; do rsync -a "$k/" "$B/Extensions/$(basename "$k")/"; done
  cp -p /Library/KernelCollections/AuxiliaryKernelExtensions.kc "$B/"
  [ -f /Library/Preferences/FeatureFlags/Domain/CoreMedia.plist ] && cp -p /Library/Preferences/FeatureFlags/Domain/CoreMedia.plist "$B/"
  pkgutil --pkgs | grep -i whateverxe | while read p; do pkgutil --pkg-info "$p"; done > "$B/receipts.txt"
  rm -f "$LATEST"; ln -s "$B" "$LATEST"
  echo "backup written to $B"; du -sh "$B" | cut -f1
  ;;
install)
  need_root install
  check_pkg
  [ -L "$LATEST" ] || { echo "no backup found: run backup first"; exit 1; }
  installer -pkg "$PKG" -target / -verboseR
  echo "installed. Now edit boot-args in the ESP config.plist, then restart."
  ;;
rollback)
  need_root rollback
  [ -L "$LATEST" ] || { echo "no backup to restore"; exit 1; }
  B=$(readlink "$LATEST")
  rsync -a --delete "$B/GPUBundles/" /Library/GPUBundles/
  for k in "$B"/Extensions/*.kext; do rsync -a --delete "$k/" "/Library/Extensions/$(basename "$k")/"; done
  cp -p "$B/AuxiliaryKernelExtensions.kc" /Library/KernelCollections/AuxiliaryKernelExtensions.kc
  [ -f "$B/CoreMedia.plist" ] && cp -p "$B/CoreMedia.plist" /Library/Preferences/FeatureFlags/Domain/CoreMedia.plist
  echo "restored from $B. Put the old boot-args back (-wexxferfix -wexvafix -wexleakfix) and restart."
  ;;
verify)
  echo "receipts:"; pkgutil --pkgs | grep -i whateverxe | while read p; do echo "  $p $(pkgutil --pkg-info "$p" | awk '/version/ {print $2}')"; done
  t=$(shasum -a 256 /Library/GPUBundles/AppleIntelTGLGraphicsVADriver.bundle/Contents/MacOS/TGLVA | awk '{print $1}')
  [ "$t" = "$TGLVA_NEW" ] && echo "TGLVA is the 0.4.4 build" || echo "TGLVA is NOT 0.4.4 ($t)"
  echo "kexts: $(kextstat 2>/dev/null | grep -i -E 'WhateverXe|TGLCompat' | awk '{print $6,$7}' | tr '\n' ' ')"
  echo "boot-args wex flags: $(nvram boot-args | tr ' ' '\n' | grep -E '^-wex' | tr '\n' ' ')"
  echo "page fix admission/live (needs the IGPU node; may be absent when no page fix is enabled):"
  ioreg -rn IGPU -w0 | grep -E 'TGLPageFixAdmission|TGLPageFixLive' | cut -c1-100
  echo "Metal: $(system_profiler SPDisplaysDataType 2>/dev/null | grep -E 'Metal' | head -1)"
  ;;
*)
  sed -n 2,13p "$0"
  ;;
esac
