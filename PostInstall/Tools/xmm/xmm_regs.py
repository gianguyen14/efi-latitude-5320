#!/usr/bin/env python3
"""xmm_regs.py [save <file> | diff <file>]: BAR0 (0x00-0xFF) and BAR2 (0x00-0x1FF) of the XMM 7360, read-only (probe revision 3)."""
import re, struct, subprocess, sys


def read():
    out = subprocess.run(["ioreg", "-l", "-w0"], capture_output=True, text=True).stdout
    m = re.search(r'"WEXXmmProbe" = <([0-9a-f]+)>', out)
    if not m:
        sys.exit("no WEXXmmProbe property")
    b = bytes.fromhex(m.group(1))
    if struct.unpack_from("<I", b, 0)[0] < 3:
        sys.exit("probe revision < 3")
    status = struct.unpack_from("<I", b, 8)[0]
    if status:
        sys.exit("probe status %d" % status)
    return list(struct.unpack_from("<64I", b, 296)), list(struct.unpack_from("<128I", b, 552))


def show(r0, r2):
    for name, r in (("BAR0", r0), ("BAR2", r2)):
        for i in range(0, len(r), 4):
            row = r[i:i + 4]
            if any(row):
                print("%s +0x%03x: %s" % (name, i * 4, " ".join("%08x" % x for x in row)))


def main():
    r0, r2 = read()
    if len(sys.argv) > 2 and sys.argv[1] == "save":
        open(sys.argv[2], "w").write(" ".join("%x" % x for x in r0 + r2))
        print("saved")
    elif len(sys.argv) > 2 and sys.argv[1] == "diff":
        old = [int(x, 16) for x in open(sys.argv[2]).read().split()]
        new = r0 + r2
        for i, (a, b) in enumerate(zip(old, new)):
            if a != b:
                bar, off = ("BAR0", i * 4) if i < 64 else ("BAR2", (i - 64) * 4)
                print("%s +0x%03x: %08x -> %08x" % (bar, off, a, b))
        print("diff done")
    else:
        show(r0, r2)


main()
