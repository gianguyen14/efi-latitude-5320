#!/usr/bin/env python3
"""Decode WXXmmProbe (WhateverXe -wexxmmprobe): read-only state of the Intel XMM 7360 modem (8086:7360).

BAR2[0] is the first word the Linux driver xmm7360-pci reads: 0x600df00d = firmware running ("modem is
ready"), 0xfeedb007 = boot ROM, still booting or no firmware, anything else unknown.
"""
import re, struct, subprocess, sys

STATUS = {0: "ok", 1: "no 8086:7360 device found", 2: "memory decoding is off (BAR not read)",
          3: "BAR2 is not a usable memory BAR", 4: "mapping BAR2 failed"}
MEANING = {0x600DF00D: "firmware running (modem is ready)",
           0xFEEDB007: "boot ROM: still booting / no firmware loaded",
           0xBADC0DED: "crashed (driver term)", 0xFFFFFFFF: "no response (all ones)"}


def main():
    out = subprocess.run(["ioreg", "-l", "-w0"], capture_output=True, text=True).stdout
    m = re.search(r'"WEXXmmProbe" = <([0-9a-f]+)>', out)
    if not m:
        print("no WEXXmmProbe property (boot with -wexxmmprobe)")
        return 1
    b = bytes.fromhex(m.group(1))
    rev, found, status, cmd = struct.unpack_from("<IIII", b, 0)
    if rev >= 2:
        cfg = struct.unpack_from("<64I", b, 16)
        bar2phys, s0, mode, tmp, _ = struct.unpack_from("<QIIII", b, 272)
    else:
        cfg = struct.unpack_from("<16I", b, 16) + (0,) * 48
        bar2phys, s0, mode = struct.unpack_from("<QII", b, 80)
        tmp = 0
    print("revision %d, device found: %d" % (rev, found))
    print("probe status: %d (%s)" % (status, STATUS.get(status, "?")))
    if found:
        print("vendor/device 0x%04x:0x%04x, command 0x%04x, class/rev 0x%08x" % (cfg[0] & 0xFFFF, cfg[0] >> 16, cmd, cfg[2]))
        print("BAR0 0x%08x 0x%08x   BAR2 0x%08x 0x%08x   subsystem 0x%08x" % (cfg[4], cfg[5], cfg[6], cfg[7], cfg[11]))
    if found and rev >= 2:
        pm = cfg[0x44 // 4]
        print("PMCSR 0x%08x -> D%d, memory decode enabled temporarily by the probe: %s" % (pm, pm & 3, "yes" if tmp else "no"))
    if status == 0:
        print("BAR2 phys 0x%x" % bar2phys)
        print("BAR2[0x00] = 0x%08x  -> %s" % (s0, MEANING.get(s0, "unknown value")))
        print("BAR2[0x60] = 0x%08x  (driver MODE word)" % mode)
    return 0


if __name__ == "__main__":
    sys.exit(main())
