#!/usr/bin/env python3
"""Decode the WEXRaplProbe property of WhateverXe (boot-arg -wexraplprobe) once per second.

Usage: python3 raplprobe.py [seconds] [clkwin_binary]

With a clkwin binary (8 busy threads, prints "t=<s> ghz=<x>" per second; see the scratch tool in the
session notes, or PostInstall/Tools/cpuclock.c) the table also shows the per-thread clock so the moment
the CPU falls to ~0.3 GHz can be matched with the MSR values. Read-only: nothing is written.
"""
import re, struct, subprocess, sys, time

SECONDS = int(sys.argv[1]) if len(sys.argv) > 1 else 120
CLK = sys.argv[2] if len(sys.argv) > 2 else None
NODE_CANDIDATES = ["IGPU", "AppleIntelTGLGraphics"]


def read_blob():
    for node in NODE_CANDIDATES:
        out = subprocess.run(["ioreg", "-rn", node, "-w0"], capture_output=True, text=True).stdout
        m = re.search(r'"WEXRaplProbe" = <([0-9a-f]+)>', out)
        if m:
            return bytes.fromhex(m.group(1))
    out = subprocess.run(["ioreg", "-l", "-w0"], capture_output=True, text=True).stdout
    m = re.search(r'"WEXRaplProbe" = <([0-9a-f]+)>', out)
    return bytes.fromhex(m.group(1)) if m else None


EC = {}
MM = {}
MM_FIRST = 0x920
MM_PREV = []


def decode(b):
    rev, n, t = struct.unpack_from("<IIQ", b, 0)
    regs = {}
    for i in range(n):
        msr, st, lo, hi = struct.unpack_from("<IIII", b, 16 + 16 * i)
        regs[msr] = (st, lo | (hi << 32))
    EC.clear()
    off = 16 + 16 * n
    if rev >= 2 and len(b) >= off + 8:
        cnt, _pad = struct.unpack_from("<II", b, off)
        for i in range(cnt):
            ident, st, val = struct.unpack_from("<IIQ", b, off + 8 + 16 * i)
            EC[ident] = val if st == 0 else None
    MM.clear()
    eoff = off + 8 + 16 * cnt if rev >= 2 and len(b) >= off + 8 else off
    if rev >= 3 and len(b) >= eoff + 16:
        mst, blo, bhi, mc = struct.unpack_from("<IIII", b, eoff)
        MM["status"] = (mst, blo, bhi)
        MM["dw"] = list(struct.unpack_from("<%dI" % mc, b, eoff + 16)) if mst == 0 else []
    return t, regs


def ec(method, sensor=0):
    return EC.get((method << 8) | sensor)


def ecline():
    f = lambda x: "-" if x is None else str(x)
    t = [f(ec(2, i)) for i in range(4)]
    lo = [f(ec(3, i)) for i in range(4)]
    hi = [f(ec(4, i)) for i in range(4)]
    hy = [f(ec(5, i)) for i in range(4)]
    return "EC32=%s EC38=%s T(cpu/skin/mem/m2)=%s lo=%s hi=%s hy=%s" % (f(ec(1)), f(ec(6)), "/".join(t), "/".join(lo), "/".join(hi), "/".join(hy))


def val(regs, m):
    st, v = regs.get(m, (1, 0))
    return v if st == 0 else None


LIMIT_BITS = {0: "PROCHOT", 1: "THERMAL", 4: "RES1", 5: "AVG_THERMAL", 6: "VR_THERMAL", 8: "VR_TDC", 10: "PL1",
              11: "PL2", 12: "PL3", 13: "PL4", 14: "MAX_TURBO", 15: "TURBO_ATTEN", 16: "INEFFICIENT"}


def bits(v, mask=0xFFFF):
    if v is None:
        return "-"
    return "/".join(LIMIT_BITS.get(i, "b%d" % i) for i in range(32) if v & (1 << i) and (mask >> i) & 1) or "none"


def row(regs, prev, tprev, t, unit):
    pl = val(regs, 0x610)
    pu, eu, tu = unit
    w = lambda x: (x & 0x7FFF) / (1 << pu)
    pl1 = w(pl) if pl is not None else None
    pl2 = w(pl >> 32) if pl is not None else None
    en = val(regs, 0x611)
    pw = None
    if en is not None and prev is not None and t > tprev:
        d = (en - prev) & 0xFFFFFFFF
        # mach_absolute_time is ns here (timebase 1/1 on x86)
        pw = d / (1 << eu) / ((t - tprev) / 1e9)
    perf = val(regs, 0x198)
    ratio = (perf >> 8) & 0xFF if perf is not None else None
    lim = val(regs, 0x64F)
    pkg = val(regs, 0x1B1)
    return pl1, pl2, pw, ratio, lim, (en if en is not None else prev), pl


def main():
    clk = None
    if CLK:
        clk = subprocess.Popen([CLK, "8", str(SECONDS)], stdout=subprocess.PIPE, text=True, bufsize=1)
    ghz = {}
    start = time.time()
    prev_en = prev_t = None
    unit = (3, 14, 10)
    print("sec  PL1W  PL2W  pkgW  ratio  PL-reasons(0x64F)          clkGHz  raw610            RAW 64F        774            777  1B1 19C 6B0 6B1 1FC")
    for s in range(1, SECONDS + 1):
        b = read_blob()
        if not b:
            print("no WEXRaplProbe property (boot with -wexraplprobe)")
            return 1
        t, regs = decode(b)
        u = val(regs, 0x606)
        if u is not None:
            unit = (u & 0xF, (u >> 8) & 0x1F, (u >> 16) & 0xF)
        pl1, pl2, pw, ratio, lim, en, pl = row(regs, prev_en, prev_t, t, unit)
        prev_en, prev_t = en, t
        g = ""
        if clk:
            while clk.stdout.readable():
                import select
                r, _, _ = select.select([clk.stdout], [], [], 0)
                if not r:
                    break
                line = clk.stdout.readline()
                m = re.search(r"ghz=([0-9.]+)", line)
                if m:
                    ghz[len(ghz) + 1] = m.group(1)
        g = ghz.get(s, "")
        f = lambda x, p=1: ("%.*f" % (p, x)) if x is not None else "-"
        rawcols = " ".join(("%x" % (val(regs, m) if val(regs, m) is not None else 0)) for m in (0x64F, 0x774, 0x777, 0x1B1, 0x19C, 0x6B0, 0x6B1, 0x1FC))
        print("%3d %5s %5s %5s %5s  %-26s %6s  %s  %s" % (s, f(pl1), f(pl2), f(pw), ratio if ratio is not None else "-",
              bits(lim), g, ("%016x" % pl) if pl is not None else "-", rawcols) + "  " + ecline())
        dw = MM.get("dw") or []
        if dw:
            i = (0x9A0 - MM_FIRST) // 4
            ch = ["%03x:%08x->%08x" % (MM_FIRST + 4 * k, MM_PREV[k], dw[k]) for k in range(len(dw)) if MM_PREV and MM_PREV[k] != dw[k]]
            print("      MMIO PL1=%08x PL2=%08x unit=%08x" % (dw[i], dw[i + 1], dw[(0x938 - MM_FIRST) // 4]) + ("  changed: " + " ".join(ch) if ch else ""))
            MM_PREV[:] = dw
        sys.stdout.flush()
        time.sleep(max(0, start + s - time.time()))
    # one full dump at the end
    print("\nfinal snapshot (status 0 = read):")
    for m, (st, v) in sorted(regs.items()):
        print("  MSR 0x%03X status=%d value=0x%016x" % (m, st, v))
    if MM.get("dw"):
        print("MMIO status/base:", MM["status"], "dump MCHBAR+0x5000+off:")
        for k in range(0, len(MM["dw"]), 4):
            print("  %03x: %s" % (MM_FIRST + 4 * k, " ".join("%08x" % x for x in MM["dw"][k:k + 4])))
    elif MM:
        print("MMIO unavailable, status/base:", MM.get("status"))
    return 0


if __name__ == "__main__":
    sys.exit(main())
