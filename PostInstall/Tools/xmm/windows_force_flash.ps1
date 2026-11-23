# Force the Dell/Fibocom FwSwitchService to flash the DW5820e (XMM 7360) again.
# Run in an ELEVATED PowerShell on Windows, on AC power with battery > 25%.
# Derived from strings in FwSwitchService.exe / WWANFirmwareFlash.dll (not run by the author).
#   -Fls <dir>  folder holding the L850_Secureboot .fls files (enables the manual path)
param([string]$Fls = "")
$ErrorActionPreference = "Continue"
$bk = "$env:USERPROFILE\Desktop\xmm_backup_$(Get-Date -f yyyyMMdd_HHmmss)"
New-Item -ItemType Directory $bk | Out-Null

# 1. Back up and clear the cached "already updated" state.
$keys = "HKLM:\SOFTWARE\WOW6432Node\Intel\FlashService","HKLM:\SOFTWARE\WOW6432Node\Intel\MBIMToolkit"
foreach ($k in $keys) {
  if (Test-Path $k) {
    reg export ($k -replace '^HKLM:','HKLM') "$bk\$(Split-Path $k -Leaf).reg" /y | Out-Null
    Write-Host "== $k"; Get-ItemProperty $k | Format-List
    foreach ($v in "CurrentIMEI","Version","DriverVer","PackageVer") {
      if ($null -ne (Get-ItemProperty $k -Name $v -ErrorAction SilentlyContinue)) {
        Remove-ItemProperty $k -Name $v; Write-Host "removed $k\$v" }
    }
  }
}

# 2. Turn the recovery workaround on and drop the "skip if same" limit in every installed fbconfig.ini.
$ini = Get-ChildItem "C:\Windows\System32\DriverStore\FileRepository","C:\Program Files*","C:\ProgramData" `
        -Recurse -Filter fbconfig.ini -ErrorAction SilentlyContinue
foreach ($f in $ini) {
  Copy-Item $f.FullName "$bk\$($f.Directory.Name)_fbconfig.ini"
  $t = @(Get-Content $f.FullName | Where-Object { $_ -notmatch '^\s*FwUpdateCfgVal' })
  $t = $t -replace '^\s*;\s*(CONFIG_PCIE0000_WA\s*=).*','$1 1'
  # $t is an array of lines: test it with Select-String, not -notmatch (which returns the non-matching lines and is always truthy).
  if (-not ($t | Select-String -Pattern '^\s*CONFIG_PCIE0000_WA\s*=\s*1' -Quiet)) { $t += "CONFIG_PCIE0000_WA = 1" }
  $t = $t -replace '^\s*;\s*(FLASH_SIM_NEED\s*=).*','$1 0'
  Set-Content $f.FullName $t
  Write-Host "patched $($f.FullName)"
}

# 3. Optional manual path: stage the images and raise the flag the flash DLL watches.
if ($Fls) {
  $dst = "C:\Windows\firmware\firmwareflash"
  New-Item -ItemType Directory $dst -Force | Out-Null
  Remove-Item "$dst\*.fls" -ErrorAction SilentlyContinue
  Copy-Item (Get-ChildItem $Fls -Filter "18500*_Secureboot.fls" | Sort-Object Name | Select-Object -First 1).FullName "$dst\module_sw.fls"
  Copy-Item (Join-Path $Fls "Generic_cust.001.033_signed.fls") "$dst\nvm.fls"
  Set-ItemProperty "HKLM:\SOFTWARE\WOW6432Node\Intel\FlashService" -Name Fls_Ready -Value 1 -Type DWord
  Write-Host "staged fls + Fls_Ready=1"
}

# 4. Restart the service and show where its log is.
Restart-Service FwSwitchService -Force -ErrorAction SilentlyContinue
Write-Host "Backups: $bk"
Write-Host "Watch: C:\ProgramData\Fibocom L850 Driver Package\logs\FwSwitchService.exeEx.log"
Write-Host "       %LOCALAPPDATA%\...\IFWD_DownloadDll_*.log"
