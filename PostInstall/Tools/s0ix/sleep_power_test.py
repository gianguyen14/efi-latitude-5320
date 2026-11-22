#!/usr/bin/env python3
"""Asleep power by battery capacity (the SMC instant amperage reads ~0 on this machine).

  python3 -I sleep_power_test.py begin   # on battery; records capacity, voltage and time
  pmset sleepnow                         # then wake it (2.4G USB mouse) after 10+ minutes
  python3 -I sleep_power_test.py end     # prints mAh drop, mean W and the S0ixStandby counters

Capacity is AppleRawCurrentCapacity (mAh) and the voltage is mV, so W = mAh * V / 1e6 / hours. A drop of
only a few mAh gives a coarse number: use 15+ minutes.
"""
import json, plistlib, subprocess, sys, time
from pathlib import Path

STATE = Path.home() / ".s0ix_power_test.json"


def battery():
    out = subprocess.check_output(["ioreg", "-r", "-c", "AppleSmartBattery", "-a"])
    d = plistlib.loads(out)[0]
    return {"mah": d["AppleRawCurrentCapacity"], "mv": d["Voltage"], "ac": bool(d["ExternalConnected"])}


def s0ix():
    out = subprocess.run(["ioreg", "-r", "-n", "S0ixStandby", "-a"], capture_output=True).stdout
    try:
        return plistlib.loads(out)[0]
    except Exception:
        return {}


def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else ""
    if cmd == "begin":
        b = battery()
        if b["ac"]:
            print("unplug the charger first (the capacity method needs battery power)")
            return 1
        STATE.write_text(json.dumps({"t": time.time(), **b}))
        print("recorded %d mAh at %d mV; now run: pmset sleepnow" % (b["mah"], b["mv"]))
        return 0
    if cmd == "end":
        s = json.loads(STATE.read_text())
        b = battery()
        hours = (time.time() - s["t"]) / 3600
        drop = s["mah"] - b["mah"]
        mv = (s["mv"] + b["mv"]) / 2
        print("elapsed %.1f min, %d -> %d mAh (drop %d), mean %.2f W (ac now: %s)"
              % (hours * 60, s["mah"], b["mah"], drop, drop * mv / 1e6 / hours if hours else 0, b["ac"]))
        info = s0ix()
        for k in sorted(info):
            if any(w in k.lower() for w in ("sleep", "wake", "residency", "blocker", "gpu", "d3", "last")):
                print("  %s = %s" % (k, info[k]))
        return 0
    print(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main())
