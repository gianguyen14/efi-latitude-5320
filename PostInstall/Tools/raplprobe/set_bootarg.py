#!/usr/bin/env python3
"""set_bootarg.py <config.plist> add|remove <flag>: edit OpenCore boot-args in place (flag as a whole word)."""
import plistlib, sys
p, op, flag = sys.argv[1:4]
d = plistlib.load(open(p, "rb"))
g = d["NVRAM"]["Add"]["7C436110-AB2A-4BBB-A880-FE41995C9F82"]
w = [x for x in g["boot-args"].split() if x != flag]
if op == "add": w.append(flag)
g["boot-args"] = " ".join(w)
plistlib.dump(d, open(p, "wb"), sort_keys=False)
print(g["boot-args"])
