#!/usr/bin/env python3
"""EFI self-test for the Dell Latitude 5320 hackintosh. Never reboots anything.

  python3 -I PostInstall/Tools/selftest/efi_selftest.py            # quick, no sudo
  python3 -I PostInstall/Tools/selftest/efi_selftest.py --load     # + 45 s clamp sampler
  python3 -I PostInstall/Tools/selftest/efi_selftest.py --sudo     # + powermetrics, ESP == repo
  python3 -I PostInstall/Tools/selftest/efi_selftest.py --sudo --load   # + load test for PL1
  python3 -I PostInstall/Tools/selftest/efi_selftest.py --sleep    # puts the Mac to sleep once, checks the wake

Compares what the machine is running now against EFI/OC/config.plist in this repo,
checks every subsystem the EFI is responsible for, and lints the repo EFI statically.
Statuses: PASS / WARN (look at it) / FAIL (broken) / INFO / SKIP.
"""
import os, re, sys, json, plistlib, subprocess, tempfile, shutil, time, glob, platform

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
OC = os.path.join(REPO, "EFI", "OC")
ARGS = set(sys.argv[1:])
RES = []          # (group, id, status, text)
TTY = sys.stdout.isatty()
COL = {"PASS": "32", "WARN": "33", "FAIL": "31", "INFO": "36", "SKIP": "90"}


def sh(cmd, timeout=60, inp=None):
    try:
        r = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=timeout, input=inp)
        return r.stdout
    except Exception as e:  # noqa
        return ""


def ioreg_plist(args):
    out = subprocess.run("ioreg -a " + args, shell=True, capture_output=True, timeout=60).stdout
    if not out.strip():
        return []
    try:
        d = plistlib.loads(out)
    except Exception:
        return []
    return d if isinstance(d, list) else [d]


def walk(node):
    yield node
    for c in node.get("IORegistryEntryChildren", []) or []:
        yield from walk(c)


def add(group, cid, status, text):
    RES.append((group, cid, status, text))


def check(group, cid):
    def deco(fn):
        try:
            fn()
        except Exception as e:  # noqa
            add(group, cid, "WARN", "đầu dò lỗi: %s: %s" % (type(e).__name__, e))
        return fn
    return deco


CFG = plistlib.load(open(os.path.join(OC, "config.plist"), "rb"))
KADD = CFG["Kernel"]["Add"]


def kinfo(k):
    p = os.path.join(OC, "Kexts", k["BundlePath"], k.get("PlistPath", "Contents/Info.plist"))
    return plistlib.load(open(p, "rb")) if os.path.exists(p) else {}


# ---------------------------------------------------------------- A. boot chain
G = "A. Khởi động / NVRAM"


@check(G, "A1")
def _():
    want = CFG["NVRAM"]["Add"]["7C436110-AB2A-4BBB-A880-FE41995C9F82"]["boot-args"].split()
    got = sh("nvram boot-args").split("\t", 1)[-1].split()
    miss, extra = sorted(set(want) - set(got)), sorted(set(got) - set(want))
    if not miss and not extra:
        add(G, "A1", "PASS", "boot-args đang chạy khớp config.plist (%d cờ)" % len(want))
    else:
        add(G, "A1", "WARN", "boot-args lệch config: thiếu %s, thừa %s" % (miss or "-", extra or "-"))


@check(G, "A2")
def _():
    raw = sh("nvram csr-active-config").split("\t", 1)[-1].strip()
    got = bytes(int(x, 16) for x in re.findall(r"%([0-9a-fA-F]{2})", raw))
    want = CFG["NVRAM"]["Add"]["7C436110-AB2A-4BBB-A880-FE41995C9F82"]["csr-active-config"]
    add(G, "A2", "PASS" if got == want else "WARN", "csr-active-config 0x%s %s config (0x%s)" % (
        got[::-1].hex().lstrip("0") or "0", "khớp" if got == want else "LỆCH", want[::-1].hex().lstrip("0")))


@check(G, "A3")
def _():
    want = CFG["PlatformInfo"]["Generic"]["SystemProductName"]
    got = sh("sysctl -n hw.model").strip()
    add(G, "A3", "PASS" if got == want else "FAIL", "SMBIOS model %s (config %s)" % (got, want))


@check(G, "A4")
def _():
    d = CFG["Kernel"]["Emulate"]["Cpuid1Data"]
    if not any(d):
        add(G, "A4", "SKIP", "không giả CPUID")
        return
    eax = int.from_bytes(d[:4], "little")
    fam = (eax >> 8) & 0xF
    mod = ((eax >> 4) & 0xF) | ((eax >> 12) & 0xF0)
    step = eax & 0xF
    gf, gm, gs = [int(sh("sysctl -n machdep.cpu." + k).strip() or -1) for k in ("family", "model", "stepping")]
    ok = (gf, gm, gs) == (fam, mod, step)
    add(G, "A4", "PASS" if ok else "FAIL", "CPUID emulate -> family %d model %d stepping %d (config %d/%d/%d)" % (gf, gm, gs, fam, mod, step))


@check(G, "A5")
def _():
    v = sh("nvram 4D1FDA02-38C7-4A6A-9CC6-4BCCA8B30102:opencore-version").split("\t", 1)[-1].strip()
    add(G, "A5", "INFO", "OpenCore %s" % (v or "không đọc được"))


# ---------------------------------------------------------------- B. ACPI
G = "B. ACPI"
ACPI_TXT = sh("ioreg -p IOACPIPlane -w0 -l") + "\n" + sh("ioreg -w0 -c IOACPIPlatformDevice")
# macOS 26 does not expose IOACPIPlane, so the devices are looked up as IOACPIPlatformDevice nodes in the
# IOService plane; USBX only leaves its properties behind.
ALT_MARK = {"USBX": r"kUSBSleepPortCurrentLimit|kUSBWakePortCurrentLimit"}
ALL_TXT = None
ACPI_ENABLED = {a["Path"]: a["Enabled"] for a in CFG["ACPI"]["Add"]}
MARK = {"SSDT-PL1.aml": "PL1T", "SSDT-ALS0.aml": "ALS0", "SSDT-PNLF.aml": "PNLF", "SSDT-EC-USBX-LAPTOP.aml": "USBX"}


@check(G, "B1")
def _():
    for f, dev in MARK.items():
        if not ACPI_ENABLED.get(f):
            continue
        ok = re.search(r"\+-o %s[ @]" % dev, ACPI_TXT) is not None
        if not ok and dev in ALT_MARK:
            global ALL_TXT
            if ALL_TXT is None:
                ALL_TXT = sh("ioreg -l -w0", timeout=120)
            ok = re.search(ALT_MARK[dev], ALL_TXT) is not None
        add(G, "B1", "PASS" if ok else "FAIL", "%s bật -> thiết bị %s %s trong registry" % (f, dev, "có" if ok else "THIẾU"))


@check(G, "B2")
def _():
    if ACPI_ENABLED.get("SSDT-PEPD-STA.aml"):
        ok = "INT33A1" in ACPI_TXT or re.search(r"\+-o PEPD[ @]", ACPI_TXT) is not None
        add(G, "B2", "PASS" if ok else "FAIL", "SSDT-PEPD-STA + vá XSTA -> PEPD (INT33A1) %s với macOS" % ("hiện" if ok else "KHÔNG hiện"))
    if ACPI_ENABLED.get("SSDT-DEEPIDLE.aml"):
        v = sh("ioreg -rn IOPMrootDomain -w0")
        ok = re.search(r'"IOPMDeepIdleSupported" = Yes', v) is not None
        add(G, "B2", "PASS" if ok else "FAIL", "SSDT-DEEPIDLE -> IOPMDeepIdleSupported %s" % ("Yes" if ok else "KHÔNG"))
    if not ACPI_ENABLED.get("SSDT-S3.aml"):
        add(G, "B2", "INFO", "SSDT-S3 tắt (đúng cho cấu hình S0ix)")


@check(G, "B3")
def _():
    iasl = shutil.which("iasl") or os.path.expanduser("~/CPUFriendFriend/Scripts/iasl-stable")
    if not os.path.exists(iasl):
        add(G, "B3", "SKIP", "không có iasl để biên dịch lại")
        return
    srcs = glob.glob(os.path.join(REPO, "PostInstall", "Tools", "*", "SSDT-*.dsl"))
    for dsl in sorted(srcs):
        name = os.path.basename(dsl)[:-4] + ".aml"
        deployed = os.path.join(OC, "ACPI", name)
        if not os.path.exists(deployed):
            add(G, "B3", "INFO", "%s: có mã nguồn nhưng không nằm trong EFI/OC/ACPI" % name)
            continue
        with tempfile.TemporaryDirectory() as t:
            shutil.copy(dsl, t)
            sh("cd %s && %s %s >/dev/null 2>&1" % (t, iasl, os.path.basename(dsl)))
            out = os.path.join(t, name)
            same = os.path.exists(out) and open(out, "rb").read() == open(deployed, "rb").read()
        add(G, "B3", "PASS" if same else "WARN", "%s: AML trong EFI %s mã nguồn .dsl" % (name, "khớp" if same else "KHÁC"))


# ---------------------------------------------------------------- C. kexts
G = "C. Kext"
KS = {}
for l in sh("kextstat -l").splitlines():
    m = re.match(r"\s*\d+\s+\d+\s+\S+\s+\S+\s+\S+\s+(\S+)\s+\(([^)]*)\)", l)
    if m:
        KS[m.group(1)] = m.group(2)


@check(G, "C1")
def _():
    bad, dataonly, ok, verdiff, gated = [], [], 0, [], []
    ids = set()
    for k in KADD:
        if not k["Enabled"]:
            continue
        info = kinfo(k)
        ident = info.get("CFBundleIdentifier")
        ids.add(ident)
        if not k.get("ExecutablePath"):
            dataonly.append(os.path.basename(k["BundlePath"]))
            continue
        if ident in KS:
            ok += 1
            if info.get("CFBundleVersion") and KS[ident] != info["CFBundleVersion"]:
                verdiff.append("%s: chạy %s, repo %s" % (os.path.basename(k["BundlePath"]), KS[ident], info["CFBundleVersion"]))
        else:
            name = os.path.basename(k["BundlePath"])
            mx = k.get("MaxKernel") or ""
            dv = os.uname().release
            if mx and tuple(int(x) for x in dv.split(".")[:2]) > tuple(int(x) for x in (mx.split(".") + ["0", "0"])[:2]):
                gated.append("%s (MaxKernel %s < Darwin %s)" % (name, mx, dv))
                continue
            bad.append(name)
    add(G, "C1", "PASS" if not bad else "FAIL", "%d/%d kext có file thực thi đã nạp%s" % (ok, ok + len(bad), "" if not bad else "; CHƯA nạp: " + ", ".join(bad)))
    if gated:
        add(G, "C1", "INFO", "kext cố ý không nạp vì MaxKernel thấp hơn macOS đang chạy (không phải lỗi): " + ", ".join(gated))
    add(G, "C1", "INFO", "kext chỉ chứa dữ liệu (không có trong kextstat là bình thường): " + ", ".join(dataonly))
    add(G, "C1", "PASS" if not verdiff else "WARN", "phiên bản kext đang chạy %s repo" % ("khớp" if not verdiff else "LỆCH " + "; ".join(verdiff)))
    vend = {".".join(i.split(".")[:2]) for i in ids if i}
    extra = sorted(n for n in KS if not n.startswith("com.apple.") and n not in ids and ".".join(n.split(".")[:2]) not in vend)
    comp = sorted(n for n in KS if not n.startswith("com.apple.") and n not in ids and ".".join(n.split(".")[:2]) in vend)
    add(G, "C1", "PASS" if not extra else "WARN", "kext ngoài Apple không có trong config: %s" % (extra or "không có"))
    if comp:
        add(G, "C1", "INFO", "kext đồng hành do kext khác tự đăng ký (cùng nhà phát triển): %s" % ", ".join(comp))


@check(G, "C2")
def _():
    v = ""
    for n in ioreg_plist("-r -c WhateverXe"):
        v = n.get("VersionInfo", "")
    kind = "DEBUG" if v.startswith("DBG") else "RELEASE" if v else "?"
    add(G, "C2", "INFO", "WhateverXe %s (bản %s)" % (v or "không đọc được", kind))


# ---------------------------------------------------------------- D. CPU / power
G = "D. CPU / nguồn"
FREQ_C = r'''
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <mach/mach_time.h>
static double now(void){static mach_timebase_info_data_t tb; if(!tb.denom)mach_timebase_info(&tb); return mach_absolute_time()*(double)tb.numer/tb.denom/1e9;}
/* One thread, dependent adds: the rate in Gadd/s is the core clock in GHz (same method as cpuclock.c).
   The earlier version timed CLOCK_PROCESS_CPUTIME_ID, which on this machine gave about 1470 MHz
   while cpuclock (wall clock) gave 4.07 GHz for the same idle core, so it was dropped. */
int main(int argc,char**argv){
  double dur=argc>1?atof(argv[1]):0; unsigned long x=0; int n=0,dips=0; double sum=0,mn=1e9,mx=0;
  double t0=now();
  do{
    double a=now(), w=a; unsigned long k=0;
    while(w-a<0.3){for(int i=0;i<10000000;i++){__asm__ volatile("add $1,%0":"+r"(x));} k+=10000000; w=now();}
    double f=k/(w-a)/1e6;
    n++; sum+=f; if(f<mn)mn=f; if(f>mx)mx=f; if(f<1500)dips++;
  }while(now()-t0<dur);
  printf("%d %.0f %.0f %.0f %d\n",n,sum/n,mn,mx,dips);
  return (int)(x&1);
}
'''
FREQ_BIN = None


def freq_bin():
    global FREQ_BIN
    if FREQ_BIN:
        return FREQ_BIN
    d = tempfile.mkdtemp(prefix="efi_selftest_")
    src = os.path.join(d, "f.c")
    open(src, "w").write(FREQ_C)
    subprocess.run("clang -O1 -o %s/f %s" % (d, src), shell=True, capture_output=True)
    FREQ_BIN = os.path.join(d, "f")
    return FREQ_BIN


def run_freq(sec):
    out = sh("%s %s" % (freq_bin(), sec), timeout=int(sec) + 30).split()
    return [float(x) for x in out] if len(out) == 5 else None


@check(G, "D1")
def _():
    g = lambda k: sh("sysctl -n machdep.xcpm." + k).strip()
    mode, mx = g("mode"), g("hard_plimit_max_100mhz_ratio")
    ok = mode == "1" and mx.isdigit() and int(mx) >= 40
    add(G, "D1", "PASS" if ok else "WARN", "XCPM mode=%s, trần P-state %s00 MHz, cpu_thermal_level=%s" % (mode, mx, g("cpu_thermal_level")))


@check(G, "D2")
def _():
    r = run_freq(0)
    if not r:
        add(G, "D2", "SKIP", "không biên dịch được đầu đo xung (cần clang)")
        return
    f = r[1]
    st = "PASS" if f >= 2500 else "WARN"
    add(G, "D2", st, "xung hiệu dụng 1 luồng ngay lúc này: %.0f MHz%s" % (f, "" if st == "PASS" else " (đợt kẹp PL1 tạm thời sau tải nặng hoặc vừa khởi động; đo lại sau 1-2 phút nghỉ)"))


@check(G, "D3")
def _():
    if "--load" not in ARGS:
        add(G, "D3", "SKIP", "bỏ qua (thêm --load để lấy mẫu 45 giây tìm đợt kẹp)")
        return
    r = run_freq(45)
    n, avg, mn, mx, dips = r
    pct = 100.0 * dips / n
    st = "PASS" if pct < 5 else "WARN" if pct < 20 else "FAIL"
    add(G, "D3", st, "45 s liên tục: trung bình %.0f MHz, thấp nhất %.0f, cao nhất %.0f, %.0f%% cửa sổ dưới 1.5 GHz" % (avg, mn, mx, pct))


@check(G, "D4")
def _():
    p = {k: v for k, v in re.findall(r"^\s+(hibernatemode|standby|powernap|autopoweroff)\s+(\d+)", sh("pmset -g"), re.M)}
    ok = p.get("hibernatemode") == "0"
    if not ok and "com.labrouss.S0ixStandby" in KS:
        add(G, "D4", "INFO", "pmset: %s (chủ ý: ngủ do kext S0ixStandby xử lý, không dùng S3/S4)" % p)
        return
    add(G, "D4", "PASS" if ok else "WARN", "pmset: %s (hibernatemode phải = 0 vì S4 không resume được)" % p)


# ---------------------------------------------------------------- E. sleep / S0ix
G = "E. Sleep (S0ixStandby)"


@check(G, "E1")
def _():
    props = {}
    for n in ioreg_plist("-r -c S0ixStandby"):
        props = n
    if not props:
        add(G, "E1", "SKIP", "S0ixStandby không chạy")
        return
    g = lambda k: props.get(k)
    add(G, "E1", "PASS" if g("DSM enabled") in (True, "Yes") else "FAIL", "gọi _DSM Modern Standby: %s" % g("DSM enabled"))
    ec = str(g("EC GPE now"))
    add(G, "E1", "PASS" if ec.startswith("enabled") else "FAIL", "EC GPE khi đang thức: %s" % ec)
    bf = str(g("Battery full state"))
    add(G, "E1", "WARN" if bf.startswith("stuck") else "PASS", "trạng thái pin đầy: %s" % bf)
    add(G, "E1", "PASS" if g("LPIT status") == "ok" else "WARN", "bộ đếm residency LPIT: %s" % g("LPIT status"))
    add(G, "E1", "INFO", "Sleep count=%s, wake gần nhất=%s" % (g("Sleep count"), g("Last wake source")))
    bl = g("Live SLP_S0 blockers")
    if bl:
        add(G, "E1", "INFO", "thiết bị đang chặn SLP_S0 (cản ngủ sâu): %s" % ", ".join(bl))


@check(G, "E2")
def _():
    log = sh("pmset -g log", timeout=90)
    ev = re.findall(r"^(\d{4}-\d\d-\d\d \d\d:\d\d:\d\d) \+\d+ (Sleep|Wake|DarkWake)\s", log, re.M)
    boot = sh("sysctl -n kern.boottime")
    m = re.search(r"sec = (\d+)", boot)
    bt = time.strftime("%Y-%m-%d %H:%M:%S", time.localtime(int(m.group(1)))) if m else ""
    since = [e for e in ev if e[0] >= bt and e[1] == "Wake"]
    fails = len(re.findall(r"Failure|failure", log))
    add(G, "E2", "INFO", "pmset log: %d sự kiện Sleep/Wake tổng, %d lần Wake từ lúc boot, %d dòng 'failure'" % (len(ev), len(since), fails))
    if since:
        r = run_freq(0)
        if r:
            add(G, "E2", "PASS" if r[1] >= 2500 else "WARN", "sau khi wake xung hiệu dụng %.0f MHz (nghi vấn F2: GUAM kẹt chế độ vắng mặt)" % r[1])
    else:
        add(G, "E2", "SKIP", "chưa ngủ/wake từ lúc boot nên chưa kiểm tra được nghi vấn F2 (chạy lại với --sleep)")


# ---------------------------------------------------------------- F. USB
G = "F. USB"


@check(G, "F1")
def _():
    reg = {}
    for n in ioreg_plist("-r -c AppleUSBHostPort"):
        for x in walk(n):
            if "UsbConnector" in x and "port" in x and isinstance(x["port"], bytes):
                reg[(x.get("IORegistryEntryName"), x["port"].hex())] = x["UsbConnector"]
    mp = os.path.join(OC, "Kexts", "USBMap.kext", "Contents", "Info.plist")
    if os.path.exists(mp):
        pl = plistlib.load(open(mp, "rb"))
        for name, pers in pl.get("IOKitPersonalities", {}).items():
            pr = pers.get("IOProviderMergeProperties", {}).get("ports", {})
            miss = [k for k, v in pr.items() if "port" in v and (k, v["port"].hex()) not in reg]
            wrong = [k for k, v in pr.items() if "port" in v and (k, v["port"].hex()) in reg and reg[(k, v["port"].hex())] != v.get("UsbConnector")]
            inert = sorted(k for k, v in pr.items() if "port" not in v)
            mapped = len([1 for v in pr.values() if "port" in v])
            add(G, "F1", "PASS" if not miss and not wrong else "FAIL",
                "USBMap: %d/%d cổng có số port đều xuất hiện đúng trong registry%s" % (mapped - len(miss), mapped, "" if not miss and not wrong else " (THIẾU %s, SAI connector %s)" % (miss, wrong)))
            if inert:
                add(G, "F1", "INFO", "USBMap có %d mục không có khóa port (%s): không có tác dụng, vô hại nếu cổng đó không tồn tại" % (len(inert), ", ".join(inert)))
    ss = sorted(k[0] for k in reg if str(k[0]).startswith("SS"))
    add(G, "F1", "INFO", "cổng SuperSpeed thấy trong registry: %s (từ personality gốc của Apple, không phải USBMap)" % (ss or "không có"))
    spd = re.findall(r"Speed: (Up to [^\n]+)", sh("system_profiler SPUSBDataType 2>/dev/null"))
    fast = [x for x in set(spd) if "Gb/s" in x]
    add(G, "F1", "PASS" if fast else "INFO", "tốc độ USB đang thấy: %s%s" % (sorted(set(spd)) or "không có thiết bị", "" if fast else " -> cắm một ổ USB 3 để xác minh cổng SuperSpeed (F7)"))


# ---------------------------------------------------------------- G. graphics
G = "G. Đồ họa / AirPlay"


@check(G, "G1")
def _():
    d = sh("system_profiler SPDisplaysDataType 2>/dev/null")
    chip = re.search(r"Chipset Model: (.+)", d)
    metal = re.search(r"Metal Support: (.+)", d)
    res = re.search(r"Resolution: (.+)", d)
    ok = chip and "Iris Xe" in chip.group(1) and metal
    add(G, "G1", "PASS" if ok else "FAIL", "GPU %s, %s, %s" % (chip and chip.group(1), metal and metal.group(1), res and res.group(1)))


@check(G, "G2")
def _():
    gva = sh("defaults read -g enableGVATransfer 2>&1").strip()
    agent = "com.gianguyen14.airplayfix" in sh("launchctl list")
    add(G, "G2", "PASS" if gva == "0" else "WARN", "enableGVATransfer=%s (cần 0 để AirPlay không treo GPU)" % gva)
    add(G, "G2", "PASS" if agent else "WARN", "LaunchAgent airplayfix %s" % ("đã nạp" if agent else "CHƯA nạp"))
    wd = sh('/usr/bin/log show --last 2h --predicate \'(eventMessage CONTAINS "GPU Reset" OR eventMessage CONTAINS "GPU reset") AND process != "log"\' --style compact 2>/dev/null | grep -c -i "reset"', timeout=90).strip()
    add(G, "G2", "INFO", "số dòng log 'GPU reset' trong 2 giờ qua: %s" % wd)


# ---------------------------------------------------------------- H. network / BT / audio / input / storage
G = "H. Thiết bị"


@check(G, "H1")
def _():
    st = sh("ifconfig en0 | grep status").strip()
    aw = sh("ifconfig awdl0 2>&1 | head -1")
    add(G, "H1", "PASS" if "active" in st else "WARN", "Wi-Fi en0: %s" % (st or "không có"))
    add(G, "H1", "PASS" if "UP" in aw else "WARN", "awdl0 (AirDrop): %s" % ("UP" if "UP" in aw else "không UP"))
    gw = re.search(r"gateway: (\S+)", sh("route -n get default 2>/dev/null"))
    if gw:
        p = sh("ping -c 3 -t 5 %s" % gw.group(1), timeout=15)
        m = re.search(r"(\d+(?:\.\d+)?)% packet loss", p)
        rt = re.search(r"= [\d.]+/([\d.]+)/", p)
        loss = float(m.group(1)) if m else 100
        add(G, "H1", "PASS" if loss == 0 else "WARN", "ping gateway: mất gói %.0f%%, trung bình %s ms" % (loss, rt.group(1) if rt else "?"))


@check(G, "H2")
def _():
    b = sh("system_profiler SPBluetoothDataType 2>/dev/null")
    add(G, "H2", "PASS" if re.search(r"State: On", b) else "WARN", "Bluetooth: %s" % ("bật" if re.search(r"State: On", b) else "không bật/không thấy"))
    a = sh("system_profiler SPAudioDataType 2>/dev/null")
    add(G, "H2", "PASS" if "Default Output Device: Yes" in a else "WARN", "Âm thanh: %s" % ("có thiết bị xuất mặc định" if "Default Output Device: Yes" in a else "KHÔNG có thiết bị xuất"))
    c = sh("system_profiler SPCameraDataType 2>/dev/null")
    add(G, "H2", "PASS" if "Camera" in c and "Model ID" in c else "WARN", "Camera: %s" % ("thấy" if "Model ID" in c else "không thấy"))


@check(G, "H3")
def _():
    prods = set()
    for n in ioreg_plist("-r -c IOHIDDevice"):
        for x in walk(n):
            if x.get("Product"):
                prods.add(x["Product"])
    kb = any("Keyboard" in p for p in prods)
    tp = any("Trackpad" in p for p in prods)
    add(G, "H3", "PASS" if kb and tp else "WARN", "HID: bàn phím %s, touchpad I2C %s (%s)" % ("có" if kb else "THIẾU", "có" if tp else "THIẾU", ", ".join(sorted(prods))))


@check(G, "H4")
def _():
    n = sh("system_profiler SPNVMeDataType 2>/dev/null")
    w = re.search(r"Link Width: (\S+)", n)
    s = re.search(r"Link Speed: ([\d.]+) GT/s", n)
    sm = re.search(r"S.M.A.R.T. status: (\S+)", n)
    tr = re.search(r"TRIM Support: (\S+)", n)
    ok = w and w.group(1) == "x4" and s and float(s.group(1)) >= 8
    add(G, "H4", "PASS" if ok else "WARN", "NVMe: %s %s GT/s, SMART %s, TRIM %s" % (w and w.group(1), s and s.group(1), sm and sm.group(1), tr and tr.group(1)))
    bat = {}
    for node in ioreg_plist("-r -n AppleSmartBattery"):
        bat = node
    if bat:
        mx, ds = bat.get("MaxCapacity") or bat.get("AppleRawMaxCapacity"), bat.get("DesignCapacity")
        add(G, "H4", "INFO", "pin: %s chu kỳ, sức khỏe %s%%, %s" % (bat.get("CycleCount"), round(100.0 * mx / ds) if mx and ds else "?", "đang sạc" if bat.get("IsCharging") else "không sạc"))


# ---------------------------------------------------------------- P. static lint (repo)
G = "P. Phân tích tĩnh repo"


@check(G, "P1")
def _():
    miss = []
    for a in CFG["ACPI"]["Add"]:
        if not os.path.exists(os.path.join(OC, "ACPI", a["Path"])):
            miss.append(a["Path"])
    for k in KADD:
        if not os.path.exists(os.path.join(OC, "Kexts", k["BundlePath"])):
            miss.append(k["BundlePath"])
    for t in CFG["Misc"]["Tools"]:
        if not os.path.exists(os.path.join(OC, "Tools", t["Path"])):
            miss.append(t["Path"])
    for d in CFG["UEFI"]["Drivers"]:
        p = d["Path"] if isinstance(d, dict) else d
        if not os.path.exists(os.path.join(OC, "Drivers", p)):
            miss.append(p)
    add(G, "P1", "PASS" if not miss else "FAIL", "mọi file config tham chiếu đều có trong EFI/OC%s" % ("" if not miss else ": THIẾU " + ", ".join(miss)))
    inc = {k["BundlePath"] for k in KADD}
    orphan = [f for f in os.listdir(os.path.join(OC, "Kexts")) if f.endswith(".kext") and f not in inc]
    add(G, "P1", "PASS" if not orphan else "WARN", "kext nằm trong Kexts/ nhưng config không nạp: %s" % (orphan or "không có"))


@check(G, "P2")
def _():
    idx, ident = {}, {}
    for i, k in enumerate(KADD):
        if k["Enabled"]:
            info = kinfo(k)
            ident[info.get("CFBundleIdentifier")] = i
            idx[k["BundlePath"]] = (i, info)
    prob = []
    for bp, (i, info) in idx.items():
        for lib in info.get("OSBundleLibraries", {}):
            if lib.startswith("com.apple."):
                continue
            if lib not in ident:
                prob.append("%s cần %s (không bật)" % (bp.split("/")[-1], lib))
            elif ident[lib] > i:
                prob.append("%s nạp TRƯỚC %s" % (bp.split("/")[-1], lib))
    add(G, "P2", "PASS" if not prob else "FAIL", "phụ thuộc kext và thứ tự nạp %s" % ("đúng" if not prob else "; ".join(prob)))


@check(G, "P3")
def _():
    toks = CFG["NVRAM"]["Add"]["7C436110-AB2A-4BBB-A880-FE41995C9F82"]["boot-args"].split()
    kern = {"keepsyms", "msgbuf", "debug", "watchdog", "-amfi_get_out_of_my_way", "-allow3d", "-disablegfxfirmware"}
    bins = []
    for k in KADD:
        if k["Enabled"] and k.get("ExecutablePath"):
            p = os.path.join(OC, "Kexts", k["BundlePath"], k["ExecutablePath"])
            if os.path.exists(p):
                bins.append(open(p, "rb").read())
    dead = []
    for t in toks:
        key = t.split("=")[0]
        if key in kern or key.lstrip("-") in {x.lstrip("-") for x in kern}:
            continue
        if not any(key.lstrip("-").encode() in b for b in bins):
            dead.append(t)
    add(G, "P3", "PASS" if not dead else "WARN", "boot-args không kext nào đọc: %s" % (dead or "không có"))


@check(G, "P4")
def _():
    q = CFG["Kernel"]["Quirks"]
    notes = []
    if q.get("AppleXcpmExtraMsrs"):
        notes.append("AppleXcpmExtraMsrs (dành cho CPU không có XCPM gốc, hướng dẫn Dortania laptop Ice Lake không dùng)")
    if q.get("CustomPciSerialDevice"):
        notes.append("CustomPciSerialDevice (chỉ cần debug qua serial PCI)")
    if q.get("LapicKernelPanic"):
        notes.append("LapicKernelPanic (Dortania: chỉ cho máy HP)")
    if q.get("PowerTimeoutKernelPanic"):
        notes.append("PowerTimeoutKernelPanic (che lỗi treo khi ngủ)")
    add(G, "P4", "WARN" if notes else "PASS", "quirk bật nhưng thường không cần: %s" % ("; ".join(notes) or "không có"))
    s, m = CFG["Misc"]["Security"], CFG["Misc"]["Debug"]
    add(G, "P4", "INFO", "Security: DmgLoading=%s Vault=%s SecureBootModel=%s; Debug.Target=%s (bit 0x40 = ghi log ra ESP mỗi boot)" % (s["DmgLoading"], s["Vault"], s["SecureBootModel"], m["Target"]))


@check(G, "P5")
def _():
    g = CFG["PlatformInfo"]["Generic"]
    bad = [k for k in ("SystemSerialNumber", "MLB") if not re.fullmatch(r"C02X+", g.get(k, ""))] + (["SystemUUID"] if g.get("SystemUUID") != "00000000-0000-0000-0000-000000000000" else [])
    add(G, "P5", "PASS" if not bad else "FAIL", "SMBIOS trong repo là giá trị ẩn danh" if not bad else "SMBIOS trong repo KHÔNG ẩn danh: %s" % bad)


@check(G, "P6")
def _():
    txt = open(os.path.join(REPO, "README.md"), encoding="utf-8").read()
    diffs = []
    for m in re.finditer(r"([A-Za-z0-9\-]+)\.kext \(v([\d.]+)\)", txt):
        name, ver = m.group(1), m.group(2)
        p = os.path.join(OC, "Kexts", name + ".kext", "Contents", "Info.plist")
        if os.path.exists(p):
            real = plistlib.load(open(p, "rb")).get("CFBundleVersion")
            if real and real != ver:
                diffs.append("%s: README v%s, thực tế %s" % (name, ver, real))
    add(G, "P6", "PASS" if not diffs else "WARN", "phiên bản kext ghi trong README %s" % ("khớp" if not diffs else "LỆCH: " + "; ".join(diffs)))


# ---------------------------------------------------------------- S. sudo-only
G = "S. Cần sudo"
SUDO = False
if "--sudo" in ARGS:
    SUDO = subprocess.run("sudo -v", shell=True).returncode == 0


@check(G, "S1")
def _():
    if not SUDO:
        add(G, "S1", "SKIP", "bỏ qua (thêm --sudo): so sánh phân vùng EFI đang boot với repo")
        return
    info = sh("diskutil info -plist disk0s1")
    mp = (plistlib.loads(info.encode()) if info else {}).get("MountPoint", "")
    mounted_here = False
    msg = ""
    if not mp:
        r = subprocess.run("sudo diskutil mount disk0s1", shell=True, capture_output=True, text=True)
        msg = (r.stdout + r.stderr).strip().replace("\n", " | ")
        mounted_here = True
        time.sleep(2)
        mp = plistlib.loads(sh("diskutil info -plist disk0s1").encode()).get("MountPoint", "")
    dev = sh("df '%s' | tail -1" % mp).split()[0] if mp else ""
    if not mp or dev != "/dev/disk0s1":
        add(G, "S1", "WARN", "không mount được ESP disk0s1 (mount point=%r, thiết bị=%r, diskutil nói: %s)" % (mp, dev, msg[:160]))
        return
    out = sh("diff -rq %s %s/EFI/OC" % (OC, mp))
    diffs = [l for l in out.splitlines() if "AirportItlwm" not in l and ".DS_Store" not in l and "opencore-" not in l]
    add(G, "S1", "PASS" if not diffs else "WARN", "ESP đang boot %s EFI/OC trong repo%s" % ("== " if not diffs else "KHÁC ", "" if not diffs else ": " + "; ".join(d[:90] for d in diffs[:6])))
    logs = sorted(glob.glob(mp + "/EFI/OC/Logs/opencore-*.txt")) + sorted(glob.glob(mp + "/opencore-*.txt"))
    if logs:
        t = open(logs[-1], errors="replace").read()
        for key, label in (("XcpmExtraMsrs", "AppleXcpmExtraMsrs"), ("CustomPciSerial", "CustomPciSerialDevice")):
            ln = [l for l in t.splitlines() if key in l]
            add(G, "S1", "INFO", "log OpenCore (%s): %s" % (label, ln[-1].strip()[:120] if ln else "không có dòng nào"))
        errs = [l.strip() for l in t.splitlines() if re.search(r"\b(Err|Failed|failed|Error|Unsupported|Not Found)\b", l)]
        add(G, "S1", "INFO", "log OpenCore: %s, %d dòng, %d dòng cảnh báo/lỗi" % (os.path.basename(logs[-1]), t.count("\n"), len(errs)))
        for l in errs[:25]:
            add(G, "S1", "INFO", "  OC> " + l[:200])
    if mounted_here:
        sh("sudo diskutil unmount disk0s1")


@check(G, "S2")
def _():
    if not SUDO:
        add(G, "S2", "SKIP", "bỏ qua (thêm --sudo): powermetrics đo công suất gói, nhiệt, lý do giới hạn")
        return
    load = "--load" in ARGS
    n = 80 if load else 10
    procs = [subprocess.Popen(["yes"], stdout=subprocess.DEVNULL) for _ in range(8)] if load else []
    try:
        out = sh("sudo powermetrics --samplers cpu_power,gpu_power,smc,thermal -i 1000 -n %d 2>/dev/null" % n, timeout=n + 40)
    finally:
        for p in procs:
            p.kill()
    samples = []
    for blk in out.split("*** Sampled system activity")[1:]:
        w = re.search(r"package power \(CPUs\+GT\+SA\):\s*([\d.]+)W", blk)
        t = re.search(r"CPU die temperature:\s*([\d.]+)", blk)
        lim = set(re.findall(r"CPU LIMIT (\S+)", blk))
        if w:
            samples.append((float(w.group(1)), float(t.group(1)) if t else 0.0, lim))
    if not samples:
        add(G, "S2", "WARN", "powermetrics không trả số liệu")
        return
    med = lambda v: sorted(v)[len(v) // 2] if v else 0.0
    add(G, "S2", "INFO", "%d mẫu; nhiệt lõi tối đa %.0f °C; giới hạn đã thấy: %s" % (len(samples), max(x[1] for x in samples), sorted(set().union(*[x[2] for x in samples])) or "không"))
    th = sum(1 for x in samples if "THERMAL" in x[2])
    if load and len(samples) >= 60:
        burst = [x[0] for x in samples[:25]]
        sust = [x[0] for x in samples[-25:]]
        sth = sum(1 for x in samples[-25:] if "THERMAL" in x[2])
        add(G, "S2", "INFO", "giai đoạn burst PL2 (25 s đầu): trung vị %.1f W, cao nhất %.1f W" % (med(burst), max(burst)))
        if ACPI_ENABLED.get("SSDT-PL1.aml"):
            m = med(sust)
            st = "PASS" if m >= 15 else "WARN"
            add(G, "S2", st, "duy trì PL1 (25 s cuối, mục tiêu 18 W): trung vị %.1f W -> %s" % (m, "PL1 đã nâng thật (firmware gốc chỉ giữ khoảng 12.5 W)" if st == "PASS" else "chưa thấy PL1 nâng (hoặc nhiệt đang bóp)"))
        if sth:
            add(G, "S2", "WARN", "%d/25 mẫu cuối vẫn bị CPU_LIMIT_THERMAL: 18 W vẫn quá nóng cho tản nhiệt hiện tại" % sth)
    elif load:
        add(G, "S2", "WARN", "quá ít mẫu để tách burst và duy trì")
    if th and not (load and len(samples) >= 60):
        add(G, "S2", "WARN", "%d mẫu CPU_LIMIT_THERMAL" % th)
    pl2_hot = [x for x in samples[:25] if x[1] >= 99]
    if load and pl2_hot:
        add(G, "S2", "WARN", "burst PL2 đã chạm %.0f °C (TJmax) trong 25 s đầu: cân nhắc hạ PL2 xuống khoảng 22 W" % max(x[1] for x in pl2_hot))


# ---------------------------------------------------------------- W. controlled sleep/wake (opt-in)
G = "W. Ngủ/thức có kiểm soát (--sleep)"


def s0ix_props():
    for n in ioreg_plist("-r -c S0ixStandby"):
        return n
    return {}


@check(G, "W1")
def _():
    if "--sleep" not in ARGS:
        add(G, "W1", "SKIP", "bỏ qua (thêm --sleep: máy SẼ đi ngủ thật; chạm chuột/bàn phím để đánh thức, script tự chạy tiếp)")
        return
    before = s0ix_props()
    n0 = before.get("Sleep count") or 0
    pre = run_freq(0)
    t_wall, t_mono = time.time(), time.monotonic()
    print("\n>>> Máy sắp ngủ. Lưu việc đang làm; đánh thức bằng chuột/bàn phím. Script chờ tối đa 5 phút...", flush=True)
    sh("pmset sleepnow")
    slept = 0
    for _ in range(300):
        time.sleep(1)
        gap = (time.time() - t_wall) - (time.monotonic() - t_mono)
        if gap > 3:
            slept = gap
            break
    if not slept:
        add(G, "W1", "FAIL", "máy không ngủ (hoặc không thức lại trong 5 phút)")
        return
    wake = time.time()
    add(G, "W1", "PASS", "đã ngủ %.0f giây và thức lại" % slept)
    time.sleep(8)
    r = run_freq(0)
    add(G, "W1", "PASS" if r and r[1] >= 2500 else "FAIL", "xung ngay sau wake: %.0f MHz (trước ngủ %.0f MHz)" % (r[1] if r else 0, pre[1] if pre else 0) + ("" if r and r[1] >= 2500 else " -> nghi vấn F2 ĐÚNG: GUAM kẹt chế độ vắng mặt"))
    time.sleep(15)
    after = s0ix_props()
    add(G, "W1", "PASS" if (after.get("Sleep count") or 0) > n0 else "WARN", "S0ixStandby Sleep count %s -> %s" % (n0, after.get("Sleep count")))
    add(G, "W1", "INFO", "wake source: %s; EC GPE: %s; GPU sau wake 15 s: %s" % (after.get("Last wake source"), after.get("EC GPE now"), str(after.get("Display power 15 s after wake"))[:90]))
    since = time.strftime("%Y-%m-%d %H:%M:%S", time.localtime(wake - slept - 5))
    gr = sh('/usr/bin/log show --start "%s" --predicate \'(eventMessage CONTAINS "GPU Reset" OR eventMessage CONTAINS "GPU reset") AND process != "log"\' --style compact 2>/dev/null | grep -c -i reset' % since, timeout=90).strip()
    add(G, "W1", "PASS" if gr in ("0", "") else "WARN", "GPU reset trong lúc ngủ/thức: %s dòng log" % (gr or 0))
    gw = re.search(r"gateway: (\S+)", sh("route -n get default 2>/dev/null"))
    if gw:
        p = sh("ping -c 3 -t 8 %s" % gw.group(1), timeout=25)
        add(G, "W1", "PASS" if "0.0% packet loss" in p else "WARN", "mạng sau wake: %s" % ("ổn" if "0.0% packet loss" in p else "mất gói/không có mạng"))
    r2 = run_freq(0)
    add(G, "W1", "PASS" if r2 and r2[1] >= 2500 else "WARN", "xung sau wake 25 s: %.0f MHz" % (r2[1] if r2 else 0))


# ---------------------------------------------------------------- report
def main():
    order = []
    for g, *_ in RES:
        if g not in order:
            order.append(g)
    cnt = {k: 0 for k in COL}
    for g in order:
        print("\n== %s" % g)
        for gg, cid, st, tx in RES:
            if gg != g:
                continue
            cnt[st] += 1
            tag = "[%s]" % st
            if TTY:
                tag = "\033[%sm%s\033[0m" % (COL[st], tag)
            print(" %s %-3s %s" % (tag, cid, tx))
    print("\nTổng: " + ", ".join("%d %s" % (v, k) for k, v in cnt.items() if v))
    out = os.path.expanduser("~/gva-research/tools/selftest_last.json")
    try:
        os.makedirs(os.path.dirname(out), exist_ok=True)
        json.dump({"time": time.strftime("%F %T"), "args": sorted(ARGS), "results": RES}, open(out, "w"), ensure_ascii=False, indent=1)
        print("Báo cáo JSON: " + out)
    except Exception:
        pass
    return 1 if cnt["FAIL"] else 0


if __name__ == "__main__":
    sys.exit(main())
