#!/usr/bin/env python3
"""gpufreq_watch.py [seconds] [out_file]: log the WhateverXe GPU clock governor once per second (read-only).

Reads the TGLPowerSample property (WhateverXe, schema 285; it is not on the IGPU node, so the full registry is scanned) and prints, per second:
  hwMHz    actual clock from RPSTAT1 bits 19:11 * 50/3 (0 while the GT sleeps)
  busy%    share of the last interval the GT was NOT in RC6 (RC6 counter, 1280 ns ticks, wall clock = sample ns)
  reqMHz   what the host governor last asked for (lastReq = (units*3) << 23, units of 50 MHz)
  req/boost  Apple's own request inputs at controller+0xec8/+0xecc (the governor can only lower these: min(donor, target))
  calls    pmNotify callbacks so far (stops moving if the callback is no longer reached)
Use it to catch "the clock stays low after a GPU reset": busy% high while hwMHz/reqMHz stay at 400.
Each ioreg call is limited to 15 s so a stuck GPU driver cannot hang the logger; a timeout is logged as TIMEOUT.
"""
import re, struct, subprocess, sys, time

SECONDS = int(sys.argv[1]) if len(sys.argv) > 1 else 120
OUT = open(sys.argv[2], "a") if len(sys.argv) > 2 else None


def sample():
    try:
        out = subprocess.run(["ioreg", "-l", "-w0"], capture_output=True, text=True, timeout=15).stdout
    except subprocess.TimeoutExpired:
        return None
    m = re.search(r'"TGLPowerSample" = <([0-9a-f]+)>', out)
    if not m:
        return {}
    q = struct.unpack("<16Q", bytes.fromhex(m.group(1))[:128])
    return {"ns": q[2], "rpstat": q[3], "rc6": q[4], "req": q[7], "boost": q[8], "calls": q[12],
            "answered": q[13], "last": q[14], "cap": q[15]}


def line(prev, cur):
    mhz = ((cur["rpstat"] >> 11) & 0x1FF) * 50 / 3
    req = ((cur["last"] >> 23) // 3) * 50 if cur["last"] else 0
    busy = "-"
    if prev and cur["ns"] > prev["ns"]:
        slept = ((cur["rc6"] - prev["rc6"]) & 0xFFFFFFFF) * 1280
        busy = "%3.0f" % (100 - min(100, 100.0 * slept / (cur["ns"] - prev["ns"])))
    return "%s hwMHz=%4.0f busy%%=%s reqMHz=%4d req/boost=%d/%d calls=%d answered=%d" % (
        time.strftime("%H:%M:%S"), mhz, busy, req, cur["req"], cur["boost"], cur["calls"], cur["answered"])


prev = None
for _ in range(SECONDS):
    t0 = time.time()
    cur = sample()
    text = time.strftime("%H:%M:%S") + (" TIMEOUT (ioreg did not answer in 15 s: GPU driver stuck?)" if cur is None else
            " no TGLPowerSample" if not cur else "")
    if cur:
        text = line(prev, cur)
        prev = cur
    print(text, flush=True)
    if OUT:
        OUT.write(text + "\n"); OUT.flush()
    time.sleep(max(0, 1 - (time.time() - t0)))
