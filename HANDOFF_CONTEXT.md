# Handoff: Dell Latitude 5320 Hackintosh (OpenCore + WhateverXe)

Snapshot: 2026-11-02. Language with the user: Vietnamese. The user runs every sudo command and every reboot. Push only when the user says "Push ngay".

## Machine

- Dell Latitude 5320, i5-1145G7, Iris Xe `8086:9a49`. GPU fuses: 5 DSS, 80 EU, **6 L3 banks**.
- AX201 Wi-Fi/Bluetooth, ALC236, SK hynix BC711 SSD, 8 GB RAM.
- macOS Sequoia 15.8.1 (24H32), OpenCore 1.0.8, SMBIOS MacBookPro16,2.
- **The serial, MLB and UUID are placeholders** (`C02XXXXXXXXX`). iServices are not set up.
- **Hard rule:** `XHCI-unsupported.kext` must always stay `Enabled = True`.
- Current boot-args: `-btlfxbeta -amfi_get_out_of_my_way -allow3d -disablegfxfirmware watchdog=0 keepsyms=1 debug=0x100 msgbuf=1048576 -pc711pdbg -vi2c-force-polling itlwm_he=1 -wexnohwdecode`

## Repos

### EFI: `/Users/nguyen/efi-latitude-5320`

- Branch `main`. Push with `git push git@github.com:gianguyen14/efi-latitude-5320.git main`.
- Pushed up to `a66c9bd` (btpin).
- Unpushed commits:
  - `a9cae51`: engine reset
  - `fc370af`: `-wexnohwdecode` added to boot-args
  - `9b2ab58`: WEX 0.7.0
  - `a7742d1`: GT2 fallback
  - `0b4c11a`: preserve hardware video encode under `-wexnohwdecode` (WhateverXe `be1f6bc`). Verified on the machine: did NOT work; H.264 encode fails with -12903.
  - `73dac04`: WhateverXe `22c685b`, decoder refused by process (see below). Not yet deployed or verified.
  - `be15c5f`: `PostInstall/Tools/wexcapture.sh <label> [minutes]`. Collects sleep/wake and display data into `~/Library/Logs/wex-capture/`.
- Deploy to the ESP (the user runs these):
  1. `sudo diskutil mount disk0s1`
  2. `sudo rsync -a --delete /Users/nguyen/efi-latitude-5320/EFI/OC/ /Volumes/EFI/EFI/OC/`
- Tools live in `PostInstall/Tools/`:
  - `gpubench.swift`, `cpuclock.c`, `smcsensors.c`
  - `vtencode_check.swift`: shows whether hardware H.264/HEVC encode is used
  - `vtdecode_check.swift`: shows whether the hardware or software decoder is selected
  - `btpin.c`, `install_btpin.sh`, `com.gianguyen14.btpin.plist`
- The scratchpad is wiped on reboot, so keep tools in the repo.

### WhateverXe fork: `~/.gemini/antigravity/scratch/WhateverXe`

- Branch `dell-latitude-5320-sequoia`. Remote `fork` = `git@github.com:gianguyen14/WhateverXe.git`. Remote `origin` = b00t0x (upstream).
- Build with `python3 tools/build.py`; the output is `build/WhateverXe.kext`. Do not use `build/RELEASE`, which is stale.
- Test with `python3 tools/test.py`. The last full run passed 209/209.
- Commits on top of 0.6.1-sequoia.1, all unpushed after `4b347d6`:
  - `facb1c3`: GPU governor driven by RC6 residency. Disable with `-wexrpsmax`.
  - `8cd333d`: bounded engine reset. Hooks `IGHardwareRingBuffer::resetGraphicsEngine` (donor offset `0x43576`). Sequence: RING_RESET_CTL handshake, then GDRST with a 50 ms bound. Logs `TGL engine reset`. Disable with `-wexnoreset`. Header `kern_tgl_reset.hpp`, test `tests/tgl_reset.cpp`.
  - `7f0881f`: `-wexnohwdecode`.
  - `307a125`: merge of upstream 0.7.0.
    - All diagnostics go through `wexDiagRoot()`. `tests/diag_root.py` forbids `getRegistryRoot` outside `kern_diag.*`.
    - The new test mocks define `#define wexDiagRoot() IORegistryEntry::getRegistryRoot()`.
  - `4ea5fa4`: unlisted TGL GT2 fuse shapes fall back to the 0.6.1 donor URB layout instead of blocking the accelerator. Before this, 0.7.0 blocked the accelerator on this chip (no Metal, black desktop). The device shows `TGLGT2DonorLayout=Yes`.
  - `be1f6bc`: preserve hardware video encode under `-wexnohwdecode` by keeping `IOGVACodec` and withholding `IOVARendererID` rewrite (keeps 0x1080040 to fail AppleGVA decode check while keeping encoder keys). Passed 208/208 tests. Copied to EFI (`0b4c11a`). **Failed on the machine:** AppleGVA loads one accelerator list for decode AND encode (`LoadAllGPUAccelerators` -> `PluginConnect`, which allows renderer IDs 0x1080000-0x1080020 and 0x1080080), so 0x1080040 refuses the H.264 encoder too (-12903).
  - `22c685b`: `-wexnohwdecode` now refuses `IGAccelVideoContext::attach` (donor offset `0x770FE`) when `proc_selfname` starts with `VTDecoderXPCServ`. This runs before start, so the unstarted client is released. `IOVARendererID` is aligned again, `IOGVACodec` is kept, and the HEVC decode keys are still removed. Header `kern_tgl_decode.hpp`, test `tests/tgl_decode.cpp`. 209/209 tests pass. Expected: `vtdecode_check` reports software and `vtencode_check` reports H.264 hw=yes. Check that the kernel logs `TGL video context refused for VTDecoderXPCService` once.

## What is running on the machine now

- WhateverXe 0.7.0, commit `4ea5fa4` (`a7742d1` in EFI), with WhateverXe-Graphics 0.4.0.
- Metal 2 works.
- `vtdecode_check`: H.264 and HEVC both decode in **software**.
- `vtencode_check`: hardware encode **is gone** (`-12908`). Cause: the current `-wexnohwdecode` removes `IOGVACodec`, which the encoder also needs.

## Sleep/wake and display reconnection (in progress)

- pmset history since October has no Sleep/Wake event at all; the machine has never slept in macOS. Settings: `sleep 0`, `hibernatemode 0`, `standby 0`, `powernap 0`, `tcpkeepalive 0`.
- `IOPMrootDomain` reports `IOSleepSupported = Yes`, so `_S3` is declared. However, the Qubes HCL lists the Latitude 5320 as `[s2idle]` only, so the firmware may not implement S3 resume.
- macOS 15 no longer exposes ACPI tables in the registry, and release OpenCore cannot dump them, so the DSDT is not available from here.
- Upstream README states that DisplayPort reconnection can black-screen or freeze, that Tiger Lake USB-C reconnection is unreliable, and that full sleep/wake is unverified (Roadmap).
- Without test data no code change is justified. Next: the user runs the test protocol (below) and `wexcapture.sh`, then analyse the capture folders.
- Test protocol:
  - Display: boot with `-wexdiag` added for one test boot. It puts records on the registry root, which earlier made PerfPowerServices loop. Plug, unplug and replug HDMI 3 times, then the same on USB-C. Run `sh PostInstall/Tools/wexcapture.sh hdmi` (or `usbc`) after each round.
  - Sleep: save work, run `pmset sleepnow`, wait 30 s, then press power. If it does not wake within about 1 minute, hold power. After the restart, run `sh PostInstall/Tools/wexcapture.sh sleep <minutes since attempt>`.

- Sleep test result, 2026-11-02: `pmset sleepnow` produced a black screen with the fans still running. The kernel log shows `ACPI: sleep states S4 S5` on every boot: the firmware is Modern Standby only and has no S3. macOS enters the dark sleep path and hangs waiting for S3. Turning off Block Sleep in BIOS does not change this. Closing the lid triggers the same hang.
- S4 (hibernation) trial: config already has `HibernateMode=Auto`, `HibernateSkipsPicker=true` and `DisableRtcChecksum=true`, and FileVault is off. User steps: `sudo pmset -a hibernatemode 25` and `sudo pmset -a autopoweroff 0`, then `pmset sleepnow`. Expect the image to be written and the machine to power off; the power button should resume through OpenCore. If it boots fresh instead of resuming, the hibernation key was not kept (RTC); next try HibernationFixup (needs download approval). Fallback: `sudo pmset -a hibernatemode 0` and `sudo pmset -a disablesleep 1`.

- S4 result: resume failed on all 5 attempts, 2026-11-06 to 11-07 (`pmset -g log`: "EFI/Bootrom Failure after last point of entry to sleep"), the last one after e560034. No sleep since. As of 2026-11-11 `hibernatemode 25` is still set and lid close still sleeps (`SleepDisabled = No`); fallback proposed to the user: `sudo pmset -a disablesleep 1` and `sudo pmset -a hibernatemode 0`.
- 2026-11-11 audit: `-amfi_get_out_of_my_way` is read by no kext and, with the dash, not by XNU either (AMFI is active). `Misc/Debug/Target` is 67 (file log on the ESP). Use `/usr/bin/log`; bare `log` is a zsh builtin and returns nothing.

### VA driver crash at +0x1336f3: fixed in WhateverXe by the XFER page fix (2026-11-13)

- Fix: clear the output counts (0x824, 0xc54) of the 0x200 and 0x800 contexts in the VA page 0x787000 (sha256 12377872...), applied with -wexvafix. In an interposed driver copy all 12 `vtransfer_check` cases pass (GVA then uses its software path) and hardware H.264 encode still works with NV12 and BGRA input. Kext UUID 15A8ACED; TGLPageFixLive schema 2 adds xfer seen/patched. Not yet booted on the machine.

(Earlier finding, kept for the mechanism:)

- Reproducer: `PostInstall/Tools/vtransfer_check.swift`. `VTPixelTransferSessionTransferImage` 420v 1080p -> 420v 720p segfaults at VADriver +0x1336f3 (NULL+8) with `-wexvafix` applied (TGLPageFixLive VA seen/patched went up in that process). Same stack as the WindowServer, Photo Booth and mediaanalysisd reports: AppleGVA `AVFPixelProcess_PrepareToTransferImages` -> VA +0x15eac -> +0x2341fc -> +0x23459b -> +0x135410 -> +0x133690.
- Cause: the function at 0x133690 (renderer object, -O0 code) stores `this+0x2cb0` into `[this+0x920]->+8` and `[this+0x910]->+8`. Slot 0x920 (composite) is created at 0x1b1bc0; slots 0x910/0x918 are only ever zeroed (0x132de9), so the second store always faults.
- With the driver absent (patched copy failed to dlopen) VideoToolbox falls back to software: status 0, about 6 ms per 1080p -> 720p frame.
- Forcing 0x135410 to return 5 (NOP the jne at 0x135430) is not enough: GVA still calls `AVFPixelProcess_TransferImageSync` and the driver faults at +0x126561 (NULL+0x48).
- Not tried: NOP only the store at 0x1336f3 (lets VPHAL composite run on the GPU; may stall RCS as in #81, so ask the user first). Open question: which driver entry or capability makes GVA skip the driver for pixel transfer.
- Test method: copy the driver and `TGLVA` into one folder, patch, `codesign -f -s -`, run the check with `DYLD_INSERT_LIBRARIES` of a dlopen interposer that redirects the VADriver path (`VA_PATCHED`). Reading the installed file shows the patched page (count 0 at 0x786fc4) because reads come from the same page cache.
- PC711Probe.kext is the SSD's interrupt compatibility driver (stationk9), not a debug probe. Do not remove it.
- At load < 2.5 the package still averages 7.2 W and 61 C (freezewatch, 383 samples). Needs `sudo powermetrics` from the user to see what keeps it awake.

- 2026-11-13: Chrome hardware acceleration enabled (chrome://gpu: Canvas/Compositing/WebGL/WebGPU hardware, GPU crash count 0); no crash or GPU event in the first 15 minutes. Claude.app: `Contents/MacOS/Claude` was a 27 KB launcher that exec'd Claude.real with `--disable-gpu --disable-software-rasterizer`; replaced by a copy of Claude.real, re-signed ad hoc. Undo: `cp ~/claude-wrapper-backup/Claude /Applications/Claude.app/Contents/MacOS/Claude && codesign -f -s - /Applications/Claude.app`. Fallback if the window is blank: `/Applications/Claude.app/Contents/MacOS/Claude.real --disable-gpu`.

### Camera / video call GPU reset storm (2026-11-14, still open)

- Boot at 15:40 with `-wexteardownfix` (kext 13C39D03, no nullguard). At 15:46:05, after opening Chrome and using the camera or a video call, 15 `gpuRestart` reports followed within about 4.5 minutes (one every ~10 s, all `WindowServer`, hardware context 6). The last was at 15:50:39; the user then rebooted, so the storm was not shown to end by itself or by closing the camera app.
- First hang: RCS "busy, in a batch buffer", IPEHR 0x7a000204 (PIPE_CONTROL, the same post-sync write family as b00t0x/WhateverXe#62). After that every report is RCS waiting on `MI_SEMAPHORE_WAIT` (IPEHR 0x0e009002) and/or BCS with RING_CTL 0x7000 (not enabled) and HEAD != TAIL: the blitter has queued work but is never restarted, so the semaphores never signal and each reset hangs again.
- `TGLTeardownDrainLive` at 15:48 was [62, 10 frees, 0 waits, 0, 8 task frees, 4 waits, 4 drained]: the drain ran and finished every wait inside 50 ms, so `-wexteardownfix` is not enough on its own.
- Root cause (found 2026-11-14): `-wexleakfix` is the 2-byte patch `75 0d -> 90 90` at Metal +0x7ed87, which frees the command buffer's POSH buffer even while a POSH batch is in flight. The first hang's ring dump shows `MI_BATCH_BUFFER_START` 0x18900101 (bit 20 = POSH) and the hung batch is that one. b00t0x/WhateverXe#47 comments (Aqpcet, TGL-H35 9A49) report exactly this: a GPU restart loop within seconds of opening several photos or HLS video, gone when the patch is reverted. SaqibAlMalik therefore installs the same patch only together with `-wex-tgl-no-posh`.
- Fix in the fork (a95b8f1): `-wexnoposh` (port of `-wex-tgl-no-posh`, seven exact donor sites checked against the installed kext) and the Metal page fix is held back until it is active (`TGLPageFixLive` schema 4, last word = pages held back). Not yet booted on the machine: EFI kext 0CBB7756 and `-wexnoposh` in boot-args are uncommitted in the working tree.
- First attempt failed (2026-11-14 16:09): kext 0CBB7756 panicked in `validatePage` +0xd3 (WindowServer, page fault on a wild pointer) and the machine stuck at the Apple logo; booted again from the USB backup EFI. Cause: `tglNoPOSHEnabled` is defined in an unnamed namespace of kern_xe.cpp but kern_host.cpp declared it `extern`, so the kext imported an undefined symbol (`nm -u` showed `_tglNoPOSHEnabled`) and kxld loaded it anyway. Fixed in the fork (`wexNoPOSHReady`, a global in kern_host.cpp); the corrected build is UUID 65B78A38 in the fork's build/. Always run `python3 tools/check_undefined.py` after `tools/build.py`. EFI/ in the repo is back at the last booted kext (13C39D03) and the config without `-wexnoposh`; the internal ESP held the bad build and must be rsynced from the repo.
- Second attempt (2026-11-14 16:32, kext 65B78A38, EFI commit e6ddd46) booted. `TGLNoPOSHLive` enabled, 35 restore calls, 12 POSH flags cleared, no layout mismatch; `TGLPageFixLive` schema 4 with the Metal page patched and 0 held back; `mtlleak_check` 2000 render / 3000 empty buffers: 0 KB each; WindowServer 53-65 MB. A Meet call in Chrome with hardware acceleration on, 16:48-16:53 (webcam on from about 16:51, UVCAssistant 5.7%): no gpuRestart, recoveryCount 0. Short test (about 2.5 min with the webcam); the storm before started about 2 min after Chrome opened, so a longer real-use check is still open. freezewatch (`~/Library/Logs/freezewatch`) logs `gpu_recov` every 30 s.
- To check after boot: `TGLNoPOSHLive` on the IGPU = [1, enabled, Calls, FlagCleared, RestoreFalse, InitSanitized, ResetSanitized, LRCAZeroed, ControlCleared, LayoutMismatch]; `TGLPageFixLive` last word must be 0 and MTL patched 1.
- `-wex-tgl-gpurec` from SaqibAlMalik/WhateverXe (tgl-stability-0.8.2) skips BCS (`domain & 2`), so it would not restart the blitter either; it restores the RCS/CCS pair after a render-domain reset. Not ported.
- Our `TGL engine reset` SYSLOG lines are not in the unified log, so the per-reset result (result, replay) was not visible. Boot with `-wexdiag` and read `TGLRecoveryLive` to see it.
- Workaround for now: no camera or video calls with Chrome hardware acceleration on (turn off "Use graphics acceleration when available" for calls).

### S0ixStandby trial (prepared 2026-11-14, not booted)

- Idea: macOS never asks for S3; it sleeps in Deep Idle (S0) and the kext calls the firmware's Modern Standby `_DSM`. Project: labrouss/S0ixStandby 0.5.4 (commit 28069d3), already used on an HP EliteBook 840 G8 (Tiger Lake, WhateverXe): about 0.5-1 W asleep, power button wakes, known freeze on AC after dark wakes (`-s0ixacnortc`), lid wake not working on that HP.
- From the ACPI dump (`~/Desktop/ACPI .zip`, decoded with `~/CPUFriendFriend/Scripts/iasl-stable`): firmware has `SS3 = 0`, `SS4 = 1` (no S3, S4 on); our `SSDT-S3.aml` creates a fake `\_S3` ({5,5,0,0}) that makes macOS send a real S3 request; `\_SB.PEPD` (`INT33A1`, `_CID PNP0D80`) holds the Modern Standby `_DSM` (functions 3 display off, 4 display on, 5 entry, 6 exit, all gated by `S0ID == 1`, GNVS at 0x63D2C000); `PEPD._STA` needs OSYS >= 0x07DF so macOS (which does not answer "Windows 2015") does not see it; `LID0` has `_PRW`.
- Trial tree: `~/s0ix-trial` (README.md there). `EFI/OC` = booted EFI + SSDT-S3 disabled, SSDT-DEEPIDLE, SSDT-PEPD-STA (+ OpenCore patch renaming `PEPD._STA` to `XSTA`, unique 14-byte AML match), S0ixStandby.kext, boot-args `-s0ixdbg -s0ixacnortc`. CPUID stays Coffee Lake (`0906EA`); `config-icelake-variant.plist` is step 2. Repo `EFI/` untouched.
- Checked offline: kext imports 338 symbols, none unresolved against kernel + kernel collection (`nm -gU` of both); SSDTs compile clean; DSDT with the rename decodes with `XSTA` inside `Device (PEPD)`; kext source read (no network, no files, no panic; MSR reads only; PCI D3 only for driverless endpoints and only with `-s0ixd3`; GPU full reset at wake like i915).
- Unknown until run: `S0ID` value, whether macOS picks Deep Idle, clean wake, lid wake.
- First boot of the trial (17:55): `IOPMDeepIdleSupported = Yes`, PEPD visible (`INT33A1`, `compatible PNP0D80`), kext started on it (Intel `_DSM` mask 0x7f, LPIT counter at 0xfe00193c, PKG_CST limit C10). `pmset sleepnow` first failed with 0xe00002e2 because `SleepDisabled = 1` (`sudo pmset -a disablesleep 0` fixed it).
- Three Deep Idle sleeps (18:02 AC, 18:07 battery, 19:04 AC): type 7, `_DSM` fn 3/5/6/4 all return 0, GPU "retained, reset done", clean wake each time, `recoveryCount` 0 after each. Package only reached PC3 (CPUID is spoofed as Coffee Lake; the project says Ice Lake is needed for C10), SLP_S0 0 %, blockers SPB and CNVI (plus SPI/eSPI at times). Two dark wakes (XDCI/XHCI) shortly after entering sleep, then the user's input.
- Wake sources: only the USB mouse wakes it (`Wake from Deep Idle due to XDCI/HID Activity`); keyboard and power button do not, because macOS disables the EC GPE 0x6e for sleep (`EC GPE at last halt = disabled by macOS`). Trial config now adds `-s0ixecwake` (arms that GPE just before the halt); not yet booted.
- `-s0ixecwake` (arms the EC GPE 0x6e just before the halt): the power button then woke the machine, but the keyboard could not type after the wake (lock screen, power off by hand at 19:18). Dropped. Wake is by the 2.4G USB mouse receiver only (`XDCI/HID Activity`); keyboard, power button and lid do not wake it.
- Power (config with Ice Lake CPUID `E5060700`, `-s0ixdbg -s0ixacnortc`, on battery, `sleep-power-test.sh`): 11.6 min asleep, 64 mAh, 4.14 W; then with Wi-Fi and Bluetooth off, 13.0 min, 61 mAh, 3.49 W. Boot core reaches CC7 (CC6 with the Coffee Lake CPUID) but the package stays at PC3 99 %, SLP_S0 0 %, blockers SPI/eSPI, SPB, CNVI, gating status `d8ff7d4f7c4070dcfd` unchanged by turning the radios off. No intermediate dark wakes in either run. Linux/HP reference is 0.76 W with PC10. SSD is an SK hynix BC711 (PC711Probe loaded, no NVMeFix), display DC5/DC6 are off (WhateverXe); neither tested as the limiter.
- Awake reference for the gain: freezewatch package power is 5-14 W awake with display on; no like-for-like awake display-off baseline measured (the SMC instant amperage reads 0 mA here, so only the capacity method works).
- One GPU reset at 19:06:03, 71 s after the 19:04:49 wake (first since 17:55): RCS hung "busy in the ring" on PIPE_CONTROL `0x7a000204` (dw1 0x50107021, address 0x40000000), the same instruction as the first hang of the 15:46 storm. The ring's `MI_BATCH_BUFFER_START` is `0x18800101` (POSH bit clear), so `-wexnoposh` works. Single event, recovered (`GPURestartEnd`), the user felt lag. Whether Deep Idle (the kext's GDRST at wake) contributes is unknown; compare hang rate after wakes with `-s0ixnogpureset` if it repeats.

## Next steps

1. In WhateverXe, run `python3 tools/test.py` and confirm 208/208. Then commit.
2. Copy `build/WhateverXe.kext` into `EFI/OC/Kexts/WhateverXe.kext` with `rsync -a --delete`, and commit the EFI repo.
3. The user deploys the ESP and reboots.
4. Build and run `vtdecode_check` and `vtencode_check`:
   - **Goal:** decode reports software, and encode is hardware (no -12908).
   - If decode still reports hardware, look for another gate. Do not reintroduce removing `IOGVACodec`.
5. Only after that, let the user open the App Store. Previously, App Store preview videos hung the GPU.

## Root causes found

### App Store GPU hang

- `VTDecoderXPCService` hardware-decodes video (Apple's TGL VA driver plus the TGLVA shim).
- The decoder submits a fixed batch at `0x402db000`. RCS hangs at `+0xC0` on a `PIPE_CONTROL`, waiting on an EU kernel that never finishes.
- Under host scheduling (no GuC), the donor's reset waits on GDRST with no time limit, so the machine freezes. `8cd333d` bounds that wait.
- Upstream README confirms the issue: "App Store video can freeze the GPU on Sequoia". This is a known upstream issue.

### Bluetooth

- BlueToolFixup patches `/usr/sbin/bluetoothd` in the page cache. The file is APFS-compressed in 16 KiB chunks.
- When part of a patched chunk is evicted and paged back in, APFS reports a hash mismatch and bluetoothd dies with SIGBUS.
- **Fixed** with the `btpin` LaunchDaemon, which mlocks the 4 patched chunks. It is installed and verified working.

### Other findings

- The App Store hang during startup comes from CPU load right after boot. It is not a bug.
- GPU performance is limited by firmware PL1 (about 12 W). Remaining lever: BIOS Thermal Mode → Ultra Performance.
- AirDrop and iPhone Mirroring are not possible on this hardware (the AX201 has no AWDL, and there is no T2).
- PerfLimitProbe (MSR reads) panicked at boot and was rolled back. Do not reintroduce it.

## Performance findings (2026-11-06, uptime ~1 h, on AC)

- **WindowServer memory leak.** Footprint was 10 GB at 14:24, 14 GB at 14:37 and 15 GB at 14:42, almost all of it compressed (top CMPRS). The machine has 8 GB of RAM, so this means about 1.5 GB of compressor, 0.6–1.5 GB of swap and 2.75 GB wired.
  - Other GPU clients also hold large compressed footprints: the Spotify GPU process 1.3 GB, FindMy 0.7 GB, NotificationCenter 0.3 GB.
  - IOAccelerator `inUseSysMemoryBytes` is only about 185 MB, and the GPU user-client counts are normal.
  - **Root cause found** (b00t0x/WhateverXe#47). `sudo footprint WindowServer` showed 17 GB of MALLOC_LARGE in 234,444 regions of 76 KB each, growing at about 60 per second. The growth continued with VLC closed and with no input, so it follows composited frames.
  - The leak is in `/Library/GPUBundles/AppleIntelTGLGraphicsMTLDriver.bundle` (16.0.32, from the Graphics 0.4.0 pkg), not in the kext. `-[MTLIGAccelCommandBuffer dealloc]` skips `operator delete` on its private 0x12010-byte POSH buffer when `m_isOnlyActiveCommandBuffer` is set. The queue's `m_pPoshUsedAsTarget` is only ever NULL-initialised (`-[MTLIGAccelCommandQueue initWithDevice:maxCommandBufferCount:]`), so the buffer is never shared.
  - `PostInstall/Tools/mtlleak_check.swift` measured 76.2 KB of malloc growth per command buffer.
  - **Do not patch the file on disk.** The ad-hoc re-signed bundle black-screened the machine on 2026-11-06: WindowServer is a platform binary and refused it with "mapping process is a platform binary, but mapped file is not". It aborted in `CoreDisplay_CreateDisplayForCGXDisplayDevice` on every relaunch. The user restored the original (OCLP Hackintosh Mod signed; accepted through AMFIPass Mod). `mtlposhfix.sh` was removed, and the backup remains at `/Users/Shared/wex-mtlfix/`.
  - The patch logic itself was verified on this machine. Using a test-only `DYLD_INSERT_LIBRARIES` dlopen redirect to load a patched copy into mtlleak_check, leak per command buffer went from 76 KB to 0 (2000 render and 3000 empty buffers), with no crash.
  - Remaining delivery options:
    - (a) In-memory patch through a Lilu `BinaryModInfo` in WEX. The file stays signed. However, Lilu reads target files once while registering user patches early in boot, and `/Library` (Data volume) may not be mounted yet; in that case the patch silently does nothing.
    - (b) A maintainer-signed Graphics release (issue #47).
    - (c) Our own `cs_validate_range` hook. Rejected: routing the same function Lilu already routes is unsafe.
  - Option (a) is implemented: WhateverXe `a249855` (`kern_tgl_posh.hpp`, registered in `XeHost::init`, `-wexnoposhfix`, test `tests/tgl_posh.cpp`; 210/210 tests pass), copied into the EFI as `6c66380`. It is not yet deployed or verified.
  - After the reboot, check for:
    - `TGL POSH leak fix registered` in the kernel log;
    - Lilu `failed to find /Library/GPUBundles/...` (means the Data volume was not mounted yet, so the patch was inert);
    - `mtlleak_check 1000 render` reporting about 0 KB if applied, 76 KB if not;
    - WindowServer staying flat.
- **CPU.** 1 thread runs at 3.83 GHz. Under an 8-thread load the package bursts to about 20 W (99 °C) for about 20 s, then holds about 12.5 W (PCTR), leaving the cores about 7–8 W at 71–78 °C. After a GPU load, the cores were held at about 1.2 W for about 20 s at 52 °C. macOS logged no thermal limit (CPU_Speed_Limit stayed 100), so the limit comes from the firmware or EC.
- **GPU.** gpubench gives 1297 GFLOPS over 8 s and 1173 GFLOPS over 40 s. GPU power is 9–10 W during the burst and 6–7 W once the package is back at about 12.5 W.
- **Reference.** Notebookcheck measured the same chassis (i5-1135G7) on Windows in Ultra Performance mode at 18 W sustained and 65 °C.
- **Already tuned.** CPUFriend EPP is 0x20 with perf-bias 7 (`ca264e7`). The internal panel runs at native 1080p without HiDPI.
- **Other.** SSD 512 GB with 410 GB free; the ESP is 210 MB and EFI is 55 MB. The charger reports 60 W.
- **Genshin.**
  - No path on macOS Intel: there is no native build, PlayCover is Apple Silicon only, D3DMetal is Apple Silicon only, DXMT targets Metal 3.1, and WEX exposes Metal 2.
  - Options are a Windows dual-boot or cloud gaming (GeForce NOW; the official Genshin Cloud does not list Vietnam).
  - If Windows is booted through OpenCore, `SSDT-S3.aml` needs an `_OSI("Darwin")` guard, because Windows would otherwise see `_S3` on a Modern Standby firmware.

## Rollback

- `~/WhateverXe.kext.backup` holds an older kext.
- The Graphics 0.3.2 package is at `~/.gemini/antigravity/scratch/WhateverXe-Graphics-0.3.2.pkg`.
- `-wexnoreset` turns off the engine-reset hook.
- `-wexnohwdecode` can be removed from boot-args to bring hardware decode back.
