#!/usr/bin/env python3
"""add_to_config.py <config.plist>: add SSDT-ECDPTF.aml to ACPI/Add (once), enabled, last in the list."""
import plistlib, sys
p = sys.argv[1]
d = plistlib.load(open(p, "rb"))
add = d["ACPI"]["Add"]
if not any(e.get("Path") == "SSDT-ECDPTF.aml" for e in add):
    add.append({"Comment": "Tell the EC a DPTF client is present (SSDT-ECDPTF)", "Enabled": True, "Path": "SSDT-ECDPTF.aml"})
    plistlib.dump(d, open(p, "wb"), sort_keys=False)
print([e["Path"] for e in add])
