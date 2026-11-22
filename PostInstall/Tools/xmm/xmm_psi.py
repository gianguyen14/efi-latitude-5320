#!/usr/bin/env python3
"""Run/decode the XMM 7360 PSI download (WhateverXe -wexxmmpsi arms both).

  xmm_psi.py dry   first read of IGPU property WEXXmmPsi: dry run (DMA setup only, writes nothing to the device)
  xmm_psi.py go    real run: only happens when /private/tmp/xmm_go exists and is not empty (once per boot; later reads return the stored result)
"""
import re, struct, subprocess, sys

STATUS = {0: "OK: modem accepted the PSI and is now in the PSI stage", 1: "no 8086:7360 device", 2: "BARs unavailable (modem in D3 or no BAR)",
          3: "no PSI data compiled in", 4: "modem is not in the boot ROM stage", 5: "DMA setup failed", 6: "boot ROM rejected the image",
          7: "timeout waiting for the ROM exit code", 8: "stage did not become PSI after the ROM accepted the image", 9: "dry run completed", 10: "real run NOT triggered: create the marker (touch /private/tmp/xmm_go with content) and read again"}
STAGE = {0xFEEDB007: "BOOT (ROM)", 0xFEEDBEEF: "PSI", 0xFEEDCAFE: "EBL", 0x600DF00D: "RUN", 0x8BADF00D: "CRASH", 0xBADC0DED: "CD_READY"}


def main():
    key = {"dry": "WEXXmmPsi", "go": "WEXXmmPsiGo"}.get(sys.argv[1] if len(sys.argv) > 1 else "")
    if not key:
        print(__doc__)
        return 2
    out = subprocess.run(["ioreg", "-l", "-w0"], capture_output=True, text=True).stdout
    m = re.search(r'"%s" = <([0-9a-f]+)>' % key, out)
    if not m:
        print("no %s property (boot with -wexxmmpsi together with -wexxmmprobe)" % key)
        return 1
    b = bytes.fromhex(m.group(1))
    rev, mode, status, cb, ca, sb, rb, sa, ra, polls, dma, size = struct.unpack_from("<12I", b, 0)
    iova, = struct.unpack_from("<Q", b, 48)
    print("mode %s, status %d: %s" % ({1: "dry run", 2: "real run"}.get(mode, mode), status, STATUS.get(status, "?")))
    print("PCI command: before 0x%04x after 0x%04x" % (cb, ca))
    print("exec stage: before 0x%08x (%s)  after 0x%08x (%s)" % (sb, STAGE.get(sb, "?"), sa, STAGE.get(sa, "?")))
    print("ROM exit code: before 0x%x after 0x%x (0x01/0x10 = accepted, 0xff = failed), polls %d" % (rb, ra, polls))
    print("DMA: status %d, device address 0x%x, size %d" % (dma, iova, size))
    return 0


if __name__ == "__main__":
    sys.exit(main())
