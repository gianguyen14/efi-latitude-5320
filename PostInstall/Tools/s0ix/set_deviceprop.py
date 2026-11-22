#!/usr/bin/env python3
"""set_deviceprop.py <config.plist> add|remove <PciRoot path> <key> [hex bytes]

Edit OpenCore DeviceProperties/Add in place, e.g.
  set_deviceprop.py config.plist add 'PciRoot(0x0)/Pci(0x1C,0x0)' pci-aspm-default 02000000
"""
import plistlib, sys

p, op, path, key = sys.argv[1:5]
d = plistlib.load(open(p, "rb"))
add = d.setdefault("DeviceProperties", {}).setdefault("Add", {})
if op == "add":
    add.setdefault(path, {})[key] = bytes.fromhex(sys.argv[5])
else:
    add.get(path, {}).pop(key, None)
    if path in add and not add[path]:
        del add[path]
plistlib.dump(d, open(p, "wb"), sort_keys=False)
for k, v in add.items():
    print(k, {a: (b.hex() if isinstance(b, bytes) and len(b) <= 8 else "...") for a, b in v.items()})
