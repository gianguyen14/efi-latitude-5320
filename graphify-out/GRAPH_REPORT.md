# Graph Report - efi-latitude-5320  (2026-11-23)

## Corpus Check
- 42 files · ~35,437 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 347 nodes · 479 edges · 34 communities (16 shown, 18 thin omitted)
- Extraction: 91% EXTRACTED · 8% INFERRED · 1% AMBIGUOUS · INFERRED: 37 edges (avg confidence: 0.83)
- Token cost: 0 input · 0 output

## Community Hubs (Navigation)
- XMM Modem and Probe Decoders
- WhateverXe GPU and Boot-args
- IOKit, SMC and NVMe Tools
- AirDrop, AWDL and Wi-Fi/BT
- Swift Tools and WhateverXe Probes
- CPU Power Limit (PL1/ECDPTF)
- Deep Idle Sleep (S0ixStandby)
- BIOS and Platform Settings
- AirPlay Fix (ControlCenter)
- Graphics 0.4.4 and Metal Leak
- Bluetooth Patching (btpin)
- VA Driver Crash Tests
- freezewatch Monitor
- Audio (AppleALC)
- PL1 Throttle History
- Input Devices (I2C/PS2)
- AirDrop Troubleshooting
- WWAN Windows Flash
- btpin Installer
- AirDrop Doc
- docs/analysis INDEX
- BIOS Configuration Doc
- Intel SGX Disabled
- Thunderbolt settings
- VT-x Enabled
- Hardware and Patches Doc
- Sleep and Power Management Doc
- pmset diagnostic commands
- AppleALC Walkthrough Doc
- CPUFriend EPP 0x20
- Handoff Context
- efi_selftest
- Genshin on macOS Intel (no path)
- README

## God Nodes (most connected - your core abstractions)
1. `main()` - 10 edges
2. `WhateverXe.kext` - 9 edges
3. `my_create()` - 8 edges
4. `EFI folder structure` - 8 edges
5. `S0ixStandby.kext (labrouss 0.5.4)` - 7 edges
6. `Boot-args table` - 7 edges
7. `read()` - 6 edges
8. `expectedLuma()` - 6 edges
9. `main()` - 5 edges
10. `main()` - 5 edges

## Surprising Connections (you probably didn't know these)
- `ForbiddenItlwm 0.5.4-beta.2` --semantically_similar_to--> `AirDrop via ForbiddenItlwm AWDL`  [INFERRED] [semantically similar]
  docs/AIRDROP.md → HANDOFF_CONTEXT.md
- `CPUFriend + HWP` --semantically_similar_to--> `CPUFriend + CPUFriendDataProvider`  [INFERRED] [semantically similar]
  docs/HARDWARE_AND_PATCHES.md → README.md
- `PC711Probe.kext` --semantically_similar_to--> `PC711Probe.kext`  [INFERRED] [semantically similar]
  docs/HARDWARE_AND_PATCHES.md → HANDOFF_CONTEXT.md
- `Wi-Fi AirportItlwm` --semantically_similar_to--> `AirportItlwm.kext`  [INFERRED] [semantically similar]
  docs/HARDWARE_AND_PATCHES.md → README.md
- `Bluetooth stack` --semantically_similar_to--> `BlueToolFixup/IntelBTPatcher/IntelBluetoothFirmware`  [INFERRED] [semantically similar]
  docs/HARDWARE_AND_PATCHES.md → README.md

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **AirDrop AWDL stack** — docs_airdrop_forbiddenitlwm, docs_airdrop_btleadvfixup, docs_airdrop_wifip2pd, docs_airdrop_awdl0, docs_airdrop_itlawdl_flags [EXTRACTED 0.85]
- **Deep Idle sleep stack** — handoff_context_s0ixstandby, handoff_context_ssdt_pepd_sta, handoff_context_ssdt_deepidle, handoff_context_pepd, handoff_context_ssdt_s3 [EXTRACTED 0.85]
- **GPU reset storm fix set** — handoff_context_wexnoposh, handoff_context_wexleakfix, handoff_context_wexteardownfix, handoff_context_wexnoccs [EXTRACTED 0.85]
- **freezewatch install flow** — postinstall_tools_install_freezewatch, postinstall_tools_smcsensors, postinstall_tools_freezewatch [EXTRACTED 0.75]
- **airplayfix install flow** — postinstall_tools_airplayfix_install_airplayfix, postinstall_tools_airplayfix_vtbgra, postinstall_tools_airplayfix_airplayfix [EXTRACTED 0.75]
- **XMM 7360 modem probe/decode tools** — postinstall_tools_xmm_xmm_decode, postinstall_tools_xmm_xmm_psi, postinstall_tools_xmm_xmm_regs, postinstall_tools_xmm_xmm_reset [EXTRACTED 0.85]

## Communities (34 total, 18 thin omitted)

### Community 0 - "XMM Modem and Probe Decoders"
Cohesion: 0.14
Nodes (16): WEXXmmProbe property, WEXXmmPsi property, WEXXmmReset property, bits(), decode(), ec(), ecline(), main() (+8 more)

### Community 1 - "WhateverXe GPU and Boot-args"
Cohesion: 0.08
Nodes (30): amfi_get_out_of_my_way=0x1, AppleIntelTGLCompat, Boot-args table, Iris Xe Tiger Lake graphics patch, Graphics boot-args, WhateverXe v0.6.1 tailored, wrapTGLRecovery, amfi_get_out_of_my_way=0x1 (+22 more)

### Community 2 - "IOKit, SMC and NVMe Tools"
Cohesion: 0.10
Nodes (11): powermetrics, AppleSMC, now(), run(), cpulimit_probe.sh script, main(), now(), call() (+3 more)

### Community 3 - "AirDrop, AWDL and Wi-Fi/BT"
Cohesion: 0.07
Nodes (29): AirportItlwm.kext (fallback), awdl0 interface / AWDL, Intel AX201 Wi-Fi, BTLEAdvFixup 0.9.1, ForbiddenItlwm 0.5.4-beta.2, IntelBTPatcher.kext, -itlawdl* boot flags, com.apple.wifip2pd launchd service (+21 more)

### Community 4 - "Swift Tools and WhateverXe Probes"
Cohesion: 0.11
Nodes (14): CoreMedia, CoreVideo, WEXRaplProbe property, WhateverXe kext, Foundation, PostInstall/Tools, check(), check() (+6 more)

### Community 5 - "CPU Power Limit (PL1/ECDPTF)"
Cohesion: 0.09
Nodes (16): config.plist (ACPI/Add), config.plist, S0ixStandby, Dell EC DPTF client (ECDV.DPST), SSDT-ECDPTF.dsl, SSDT-PL1.dsl, PACKAGE_RAPL_LIMIT (MCHBAR+0x59A0), add() (+8 more)

### Community 6 - "Deep Idle Sleep (S0ixStandby)"
Cohesion: 0.12
Nodes (15): S0ixStandby PMC page, S0ixStandby kext, OpenCore config.plist, IOPMDeepIdleSupported (Deep Idle), SSDT-DEEPIDLE.dsl, ACPI Patch PEPD._STA to XSTA, SSDT-PEPD-STA.dsl, dw() (+7 more)

### Community 7 - "BIOS and Platform Settings"
Cohesion: 0.08
Nodes (26): BIOS defaults restore procedure, Fastboot = Thorough, SATA/NVMe Operation = AHCI/NVMe, Secure Boot Disabled, SpeedStep / Speed Shift Enabled, VT-d Enabled, SK hynix BC711 NVMe, Bluetooth stack (+18 more)

### Community 8 - "AirPlay Fix (ControlCenter)"
Cohesion: 0.12
Nodes (7): ControlCenter, airplayfix.sh script, install_airplayfix.sh script, uninstall_airplayfix.sh script, my_create(), my_cwo(), patched()

### Community 9 - "Graphics 0.4.4 and Metal Leak"
Cohesion: 0.11
Nodes (13): Darwin, boot-args -wexxferfix -wexvafix -wexleakfix, WhateverXe Graphics 0.4.4, WhateverXe issue 47 (Metal command buffer leak), WindowServer memory leak (Metal POSH buffer), Metal, check_pkg(), need_root() (+5 more)

### Community 10 - "Bluetooth Patching (btpin)"
Cohesion: 0.15
Nodes (8): BlueToolFixup/BTLEAdvFixup, bluetoothd, addChunk(), main(), matches(), parsePatterns(), scan(), x86Slice()

### Community 11 - "VA Driver Crash Tests"
Cohesion: 0.15
Nodes (8): AppleIntelTGLGraphicsVADriver crash with 420v scaling, -wexgvanoassert, VA driver crash +0x1336f3 (GVA pixel transfer), MachO, buffer(), fill(), mean(), vaLoaded()

### Community 12 - "freezewatch Monitor"
Cohesion: 0.43
Nodes (5): alert(), append(), sample(), freezewatch.sh script, install_freezewatch.sh script

### Community 13 - "Audio (AppleALC)"
Cohesion: 0.33
Nodes (6): AppleALC alcid=33, Realtek ALC295 layouts test plan, alcid=33, AppleALC 1.9.8, Audio evaluation criteria, ocvalidate OpenCore 1.0.8 check

### Community 14 - "PL1 Throttle History"
Cohesion: 0.40
Nodes (6): PerfLimitProbe (rolled back), CPU PL1 power throttle, SSDT-ECDPTF.aml (EC DPTF mode), SSDT-PL1.aml, SSDT-ECDPTF.aml, SSDT-PL1.aml

### Community 15 - "Input Devices (I2C/PS2)"
Cohesion: 0.67
Nodes (3): -vi2c-force-polling, VoodooI2C + VoodooI2CHID, VoodooPS2Controller

## Ambiguous Edges - Review These
- `psi_extract.py` → `xmm_psi.py`  [AMBIGUOUS]
  docs/analysis/psi_extract.py.md · relation: conceptually_related_to
- `Display Sleep workaround (pmset)` → `Deep Idle sleep (S0ixStandby)`  [AMBIGUOUS]
  docs/SLEEP_AND_POWER_MANAGEMENT.md · relation: conceptually_related_to
- `Deep Idle sleep (S0ixStandby)` → `pmset display-sleep workaround`  [AMBIGUOUS]
  README.md · relation: conceptually_related_to
- `PerfLimitProbe (rolled back)` → `CPU PL1 power throttle`  [AMBIGUOUS]
  HANDOFF_CONTEXT.md · relation: conceptually_related_to

## Knowledge Gaps
- **76 isolated node(s):** `PATH`, `Darwin`, `MachO`, `CPUFriend + HWP`, `Wi-Fi AirportItlwm` (+71 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 143 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **18 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `PostInstall/Tools` connect `Swift Tools and WhateverXe Probes` to `Graphics 0.4.4 and Metal Leak`, `VA Driver Crash Tests`?**
  _High betweenness centrality (0.487) - this node is a cross-community bridge._
- **What connects `PATH`, `Darwin`, `MachO` to the rest of the system?**
  _76 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `XMM Modem and Probe Decoders` be split into smaller, more focused modules?**
  _Cohesion score 0.13725490196078433 - nodes in this community are weakly interconnected._
- **Why does `WEXRaplProbe property` connect `Swift Tools and WhateverXe Probes` to `XMM Modem and Probe Decoders`?**
  _High betweenness centrality (0.325) - this node is a cross-community bridge._
- **Should `WhateverXe GPU and Boot-args` be split into smaller, more focused modules?**
  _Cohesion score 0.07586206896551724 - nodes in this community are weakly interconnected._

### Low-confidence Hints
_AMBIGUOUS edges — the extractor was unsure. Verify before acting on these._

- **What is the exact relationship between `psi_extract.py` and `xmm_psi.py`?**
  _Edge tagged AMBIGUOUS (relation: conceptually_related_to) - confidence is low._
- **What is the exact relationship between `Display Sleep workaround (pmset)` and `Deep Idle sleep (S0ixStandby)`?**
  _Edge tagged AMBIGUOUS (relation: conceptually_related_to) - confidence is low._