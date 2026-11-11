#!/usr/bin/env python3
"""Keeps CapCut starting on the WhateverXe Metal driver.

CapCut 9.7 aborts at launch with "+[MTLLoader sliceIDForDevice:...]: failed
assertion `Target device architecture is nil'" once its remote settings turn on
dynamic Metal libraries for x86. The TGL Metal driver reports no device
architecture. This renames those keys in CapCut's cached settings (same length,
so CapCut falls back to its defaults) and rewrites the MMKV CRC. CapCut may
download the settings again; run this again if it stops opening.

Usage: quit CapCut, then python3 capcut_metalfix.py
"""
import os
import shutil
import struct
import subprocess
import sys
import time
import zlib

KEYS = ["veabtest_enableDynamicMetalLib", "effectab_enable_metal_arch_x86"]
path = os.path.expanduser("~/Movies/CapCut/User Data/MMKV/settings_json")

if subprocess.run(["pgrep", "-x", "CapCut"], capture_output=True).returncode == 0:
    sys.exit("Quit CapCut first.")
data = bytearray(open(path, "rb").read())
crc = bytearray(open(path + ".crc", "rb").read())
size = struct.unpack("<I", data[:4])[0]
old = struct.unpack("<I", crc[:4])[0]
if zlib.crc32(bytes(data[4:4 + size])) & 0xffffffff != old:
    sys.exit("Settings CRC does not match; not editing.")

renamed = 0
for key in KEYS:
    enabled, disabled = f'"{key}"'.encode(), f'"{key[:-1]}X"'.encode()
    at = data.find(enabled)
    while at != -1 and at < 4 + size:
        data[at:at + len(enabled)] = disabled
        renamed += 1
        at = data.find(enabled, at + 1)
if not renamed:
    sys.exit("Nothing to change; the keys are already disabled.")

backup = f"{path}.{time.strftime('%Y%m%d-%H%M%S')}.bak"
shutil.copy2(path, backup)
shutil.copy2(path + ".crc", backup + ".crc")
new = zlib.crc32(bytes(data[4:4 + size])) & 0xffffffff
# The meta file keeps the CRC twice (current and last confirmed).
for offset in range(0, len(crc) - 3, 4):
    if struct.unpack("<I", crc[offset:offset + 4])[0] == old:
        crc[offset:offset + 4] = struct.pack("<I", new)
open(path, "wb").write(data)
open(path + ".crc", "wb").write(crc)
print(f"Disabled {renamed} entries; backup at {backup}")
