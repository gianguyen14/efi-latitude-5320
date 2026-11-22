#!/usr/bin/env python3
"""Decode WEXXmmReset: the modem reset through the firmware's own WWAN _RST method (WhateverXe -wexxmmpsi).

The reset runs once per boot, only when /private/tmp/xmm_reset exists and is not empty, on the first read of the property.
"""
import re, struct, subprocess, sys

ST = {0: "OK: modem is back in the BOOT stage", 1: "no 8086:7360 device", 2: "no ACPI device for the modem", 3: "ACPI _RST call failed",
      4: "config space did not come back after the reset", 5: "exec stage is not BOOT after the wait", 10: "NOT triggered (create the marker /private/tmp/xmm_reset and read again)"}

out = subprocess.run(["ioreg", "-l", "-w0"], capture_output=True, text=True).stdout
m = re.search(r'"WEXXmmReset" = <([0-9a-f]+)>', out)
if not m:
    sys.exit("no WEXXmmReset property (boot with -wexxmmpsi)")
b = bytes.fromhex(m.group(1))
rev, st, rc1, rc2, ven, cmd, stage, ms, chip, b0, b2, _ = struct.unpack_from("<12I", b, 0)
print("status %d: %s" % (st, ST.get(st, "?")))
print("ACPI rc: WRST._RST -> 0x%08x ; full path -> 0x%08x" % (rc1, rc2))
print("vendor/device after: 0x%08x   command after: 0x%04x   waited %d ms" % (ven, cmd, ms))
print("exec stage after: 0x%08x   chip info word: 0x%08x   BAR0 0x%08x BAR2 0x%08x" % (stage, chip, b0, b2))
