#!/usr/bin/env python3
"""psi_extract.py <Secureboot.fls> <out_dir>: pull the PSI image out of an Intel FLS container (read-only on the input).

Container = a 0x28-byte header followed by records [type u32][len u32 including these 8 bytes][...]. Records of type
0xc hold component data: [type][len][idx u32][sub u32][8 bytes] then a payload that starts with a 16-byte prefix
[checksum u32][size u32 = payload - 16][0][x] followed by the image. Component 0 is psi_flash_signed.fls (64 KiB).
Writes psi.bin (the image without the 16-byte prefix) and prints its sha256. Never commit the output: it is the vendor's firmware.
"""
import hashlib, struct, sys, pathlib

f = pathlib.Path(sys.argv[1]).read_bytes()
out = pathlib.Path(sys.argv[2]); out.mkdir(parents=True, exist_ok=True)
pos = 0x28
comps = {}
while pos + 8 <= len(f):
    t, l = struct.unpack_from("<II", f, pos)
    if l < 8 or pos + l > len(f):
        sys.exit("bad record at 0x%x" % pos)
    if t == 0xC:
        idx, sub = struct.unpack_from("<II", f, pos + 8)
        comps[(idx, sub)] = f[pos + 24:pos + l]
    pos += l
if pos != len(f) - 0xC and pos != len(f):
    print("note: stream ended at 0x%x of 0x%x" % (pos, len(f)))
body = comps[(0, 0)]
size = struct.unpack_from("<I", body, 4)[0]
assert size == len(body) - 16, "prefix size field %d != payload-16 %d" % (size, len(body) - 16)
img = body[16:]
(out / "psi.bin").write_bytes(img)
print("psi.bin", len(img), "bytes, sha256", hashlib.sha256(img).hexdigest())
print("first words:", img[:16].hex(" ", 4))
