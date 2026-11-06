#!/bin/sh
# Fixes the WhateverXe Graphics 0.4.0 Metal driver leak (b00t0x/WhateverXe#47).
# -[MTLIGAccelCommandBuffer dealloc] skips deleting the command buffer's
# 0x12010-byte POSH buffer when it was the only active buffer on its queue,
# assuming the queue owns it. The queue's m_pPoshUsedAsTarget is only ever set
# to NULL, so each such buffer leaks 76 KB; WindowServer loses about 4.5 MB/s.
# The patch drops that jne (0x7ed87: 75 0d -> 90 90) and re-signs the bundle
# ad hoc. Reinstalling the Graphics package reverts it; run this again then.
#
# Usage: sudo sh mtlposhfix.sh           patch (keeps a backup), then reboot
#        sudo sh mtlposhfix.sh restore   put the backup back, then reboot
# Check: mtlleak_check reports about 0 KB per command buffer once patched.
set -eu
bundle=/Library/GPUBundles/AppleIntelTGLGraphicsMTLDriver.bundle
binary=Contents/MacOS/AppleIntelTGLGraphicsMTLDriver
backup=/Users/Shared/wex-mtlfix/AppleIntelTGLGraphicsMTLDriver.bundle
# 19 bytes from 0x7ed7b: mov rax, [ivar]; cmp byte [r14+rax], 0; jne; call delete
window=$((0x7ed7b))
original=488b0526b1410041803c0600750de87afa0100
patched=488b0526b1410041803c06009090e87afa0100

[ "$(id -u)" = 0 ] || { echo "Run with sudo." >&2; exit 1; }
tmp=$(mktemp -d /private/tmp/wex-mtlfix.XXXXXX)
trap 'rm -rf "$tmp"' EXIT

if [ "${1:-}" = restore ]; then
  [ -d "$backup" ] || { echo "No backup at $backup." >&2; exit 1; }
  ditto "$backup" "$tmp/new.bundle"
else
  version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$bundle/Contents/Info.plist")
  case $(xxd -s "$window" -l 19 -p "$bundle/$binary") in
    "$patched") echo "Already patched."; exit 0 ;;
    "$original") ;;
    *) echo "Driver $version does not match the expected code at 0x7ed87; not patching." >&2; exit 1 ;;
  esac
  [ -d "$backup" ] || { mkdir -p "$(dirname "$backup")"; ditto "$bundle" "$backup"; }
  ditto "$bundle" "$tmp/new.bundle"
  printf '\220\220' | dd of="$tmp/new.bundle/$binary" bs=1 seek=$((0x7ed87)) conv=notrunc 2>/dev/null
  [ "$(xxd -s "$window" -l 19 -p "$tmp/new.bundle/$binary")" = "$patched" ] || { echo "Patch did not apply." >&2; exit 1; }
  codesign -f -s - "$tmp/new.bundle"
fi
codesign -v "$tmp/new.bundle"
chown -R root:wheel "$tmp/new.bundle"
# Rename rather than overwrite: running processes keep the old file mapped.
mv "$bundle" "$tmp/old.bundle"
mv "$tmp/new.bundle" "$bundle"
echo "Done. Reboot so WindowServer and running apps load the new driver."
