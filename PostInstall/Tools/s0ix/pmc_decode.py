#!/usr/bin/env python3
"""Decode the PMC page that S0ixStandby publishes with -s0ixpmcdump (read-only).

  python3 -I pmc_decode.py            # after one Deep Idle sleep

The page starts at PWRM+0x1000 (counter at PWRM+0x193C sits at byte 0x93C of it). Offsets and layouts are
those of the Linux intel_pmc_core driver for Tiger Lake (core.h / tgl.c): LTR registers 0x1B50-0x1BF8
(value bits 9:0, scale bits 12:10 = 1 << (5*scale) ns, snoop in the low 16 bits with bit 15 = requirement,
non-snoop in the high 16 with bit 31), LTR_IGNORE 0x1B0C, LPM status latched 0x1C3C and live 0x1C5C
(6 dwords each), LPM_EN 0x1C78, PPFEAR gating 0x1D90 (set bit = gated).
"""
import plistlib, struct, subprocess, sys

LTR = {0x1B50: "CUR_PLT", 0x1B54: "CUR_ASLT", 0x1B60: "SPA", 0x1B64: "SPB", 0x1B68: "SATA", 0x1B6C: "GBE",
       0x1B70: "XHCI", 0x1B78: "ME", 0x1B7C: "EVA", 0x1B80: "SPC", 0x1B84: "AZ", 0x1B8C: "LPSS", 0x1B90: "CAM",
       0x1B94: "SPD", 0x1B98: "SPE", 0x1B9C: "ESPI", 0x1BA0: "SCC", 0x1BA4: "ISH", 0x1BF0: "CNV", 0x1BF4: "EMMC",
       0x1BF8: "UFSX2"}


def ltr_text(half):
    if not half & 0x8000:
        return "-"
    val, scale = half & 0x3FF, (half >> 10) & 7
    if scale > 5:
        return "invalid"
    ns = val << (5 * scale)
    return "%d ns (%.1f us)" % (ns, ns / 1000.0)


def page(node, key):
    v = node.get(key)
    return v if isinstance(v, (bytes, bytearray)) and len(v) >= 0x1000 else None


def dw(p, off):
    o = off - 0x1000
    return struct.unpack_from("<I", p, o)[0] if 0 <= o <= len(p) - 4 else None


def show(name, p):
    print("== %s ==" % name)
    ign = dw(p, 0x1B0C)
    print("LTR_IGNORE 0x1B0C = %s" % ("0x%08x" % ign if ign is not None else "-"))
    rows = []
    for off, n in sorted(LTR.items()):
        v = dw(p, off)
        if v is None:
            continue
        snoop, non = v & 0xFFFF, v >> 16
        rows.append((n, off, v, ltr_text(snoop), ltr_text(non)))
    for n, off, v, s, ns in rows:
        print("  LTR %-8s 0x%04X = 0x%08x   snoop %-22s non-snoop %s" % (n, off, v, s, ns))
    for label, base in (("LPM status (latched)", 0x1C3C), ("LPM status (live)", 0x1C5C)):
        vals = [dw(p, base + 4 * i) for i in range(6)]
        print("  %s 0x%04X: %s" % (label, base, " ".join("%08x" % x if x is not None else "-" for x in vals)))
    print("  LPM_EN 0x1C78 = %s" % ("0x%08x" % dw(p, 0x1C78) if dw(p, 0x1C78) is not None else "-"))
    gate = [dw(p, 0x1D90 + 4 * i) for i in range(3)]
    print("  PPFEAR 0x1D90: %s" % " ".join("%08x" % x if x is not None else "-" for x in gate))
    sl = dw(p, 0x193C)
    print("  SLP_S0 counter 0x193C = %s" % (sl if sl is not None else "-"))


def main():
    out = subprocess.run(["ioreg", "-r", "-n", "S0ixStandby", "-a"], capture_output=True).stdout
    try:
        node = plistlib.loads(out)[0]
    except Exception:
        print("S0ixStandby not found")
        return 1
    found = False
    for key in ("PMC page at boot", "PMC page at halt", "PMC page after halt"):
        p = page(node, key)
        if p is not None:
            found = True
            show(key, p)
    if not found:
        print("no PMC page properties (boot with -s0ixpmcdump and sleep once)")
        print("keys with PMC:", [k for k in node if "PMC" in k])
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
