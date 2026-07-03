$ErrorActionPreference = 'Stop'

$workspace = Split-Path -Parent $MyInvocation.MyCommand.Path
$packages = Get-ChildItem 'C:\Program Files\WindowsApps' -Directory -ErrorAction Stop |
  Where-Object { $_.Name -like 'Claude_*_x64__pzs8sxrjxfjjc' } |
  Sort-Object LastWriteTime -Descending

if (-not $packages) {
  throw 'Claude Windows package was not found.'
}

$package = $packages[0]
$appDir = Join-Path $package.FullName 'app'
$exe = Join-Path $appDir 'Claude.exe'
$asar = Join-Path $appDir 'resources\app.asar'
$ionDist = Join-Path $appDir 'resources\ion-dist'
$backupDir = Join-Path $workspace "backups\$($package.Name)"
New-Item -ItemType Directory -Force -Path $backupDir | Out-Null

Get-Process | Where-Object { $_.ProcessName -like '*Claude*' } | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Milliseconds 800

foreach ($path in @($exe, $asar)) {
  takeown /F $path | Out-Null
  icacls $path /grant:r 'Administrator:(F)' | Out-Null
}

if (-not (Test-Path (Join-Path $backupDir 'Claude.exe.original'))) {
  Copy-Item -LiteralPath $exe -Destination (Join-Path $backupDir 'Claude.exe.original')
}
if (-not (Test-Path (Join-Path $backupDir 'app.asar.original'))) {
  Copy-Item -LiteralPath $asar -Destination (Join-Path $backupDir 'app.asar.original')
}

$python = @'
from pathlib import Path
import hashlib
import os
import re
import struct
import subprocess
import time

exe = Path(os.environ["CLAUDE_EXE"])
asar = Path(os.environ["CLAUDE_ASAR"])
ion_dist = Path(os.environ["CLAUDE_ION_DIST"])

def patch_bytes(path, replacements):
    data = path.read_bytes()
    changed = 0
    for old, new in replacements:
        old_b = old.encode("ascii")
        new_b = new.encode("ascii")
        if len(new_b) > len(old_b):
            raise RuntimeError("replacement is longer than target")
        new_b = new_b + (b" " * (len(old_b) - len(new_b)))
        count = data.count(old_b)
        if count:
            data = data.replace(old_b, new_b)
            changed += count
    if changed:
        path.write_bytes(data)
    return changed

frontend_targets = [
    (
        'case"gateway":case"mantle":return function(e){return sr(e)?{ok:!0}:{ok:!1,reason:"expected a gateway model route referencing an Anthropic model (e.g. claude-sonnet-4-5, anthropic/claude-*). Name routes to match the underlying model."}}(t)',
        'case"gateway":case"mantle":return{ok:!0}',
    ),
]

frontend_changed = 0
if ion_dist.exists():
    for js in ion_dist.rglob("*.js"):
        try:
            frontend_changed += patch_bytes(js, frontend_targets)
        except UnicodeError:
            pass

asar_targets = [
    (
        'function Vri(A){return grA(A)?{ok:!0}:{ok:!1,reason:"expected a gateway model route referencing an Anthropic model (e.g. claude-sonnet-4-5, anthropic/claude-*). Name routes to match the underlying model."}}',
        'function Vri(A){return{ok:!0}}',
    ),
    (
        'function zH(t){return kA(t)?{ok:!0}:{ok:!1,reason:"expected a gateway model route referencing an Anthropic model (e.g. claude-sonnet-4-5, anthropic/claude-*). Name routes to match the underlying model."}}',
        'function zH(t){return{ok:!0}}',
    ),
    (
        'async function mVn(){{const A=FQe();D.info("[updater] Update URL: %s",new URL(A).origin);const e=ql();sA.autoUpdater.setFeedURL({url:A,...e?{serverType:"json"}:{}})}sA.autoUpdater.checkForUpdates()}',
        'async function mVn(){D.info("[updater] Disabled locally to preserve Zhipu GLM-5.2 patch")}',
    ),
]
asar_changed = patch_bytes(asar, asar_targets)

def run_once():
    proc = subprocess.Popen([str(exe)], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    try:
        out, err = proc.communicate(timeout=6)
        return (out or "") + (err or "")
    except subprocess.TimeoutExpired:
        proc.terminate()
        try:
            out, err = proc.communicate(timeout=2)
        except subprocess.TimeoutExpired:
            proc.kill()
            out, err = proc.communicate(timeout=2)
        return (out or "") + (err or "")

hash_re = re.compile(r"(?:ASAR Integrity Violation: got a hash mismatch|Integrity check failed for asar archive) \(([0-9a-f]{64}) vs ([0-9a-f]{64})\)")

integrity_updates = 0
for _ in range(8):
    output = run_once()
    match = hash_re.search(output)
    if not match:
        break
    first, second = match.group(1), match.group(2)
    archive_level = "asar archive" in match.group(0)
    target = exe if archive_level else asar
    old_hash, new_hash = (first, second) if archive_level else (second, first)
    data = target.read_bytes()
    count = data.count(old_hash.encode("ascii"))
    if not count:
        raise RuntimeError(f"Integrity hash {old_hash} was not found in {target}")
    target.write_bytes(data.replace(old_hash.encode("ascii"), new_hash.encode("ascii")))
    integrity_updates += count
    time.sleep(0.5)

subprocess.run(
    ["powershell", "-NoProfile", "-Command", "Get-Process | Where-Object { $_.ProcessName -like '*Claude*' } | Stop-Process -Force -ErrorAction SilentlyContinue"],
    capture_output=True,
)

print({
    "frontend_changed": frontend_changed,
    "asar_changed": asar_changed,
    "integrity_updates": integrity_updates,
    "exe_sha256": hashlib.sha256(exe.read_bytes()).hexdigest().upper(),
    "asar_sha256": hashlib.sha256(asar.read_bytes()).hexdigest().upper(),
})
'@

$env:CLAUDE_EXE = $exe
$env:CLAUDE_ASAR = $asar
$env:CLAUDE_ION_DIST = $ionDist
$tmp = Join-Path $env:TEMP 'protect_claude_zhipu_glm52.py'
Set-Content -LiteralPath $tmp -Value $python -Encoding UTF8
python $tmp

$hosts = "$env:SystemRoot\System32\drivers\etc\hosts"
$marker = '# Claude auto-update block - keep patched Zhipu GLM-5.2 setup'
$block = @"
$marker
0.0.0.0 api.anthropic.com
::1 api.anthropic.com
# End Claude auto-update block
"@
$current = Get-Content -LiteralPath $hosts -Raw
if ($current -notmatch [regex]::Escape($marker)) {
  Add-Content -LiteralPath $hosts -Value "`r`n$block" -Encoding ASCII
}

New-Item -Path 'HKLM:\SOFTWARE\Policies\Microsoft\WindowsStore' -Force | Out-Null
New-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\WindowsStore' -Name 'AutoDownload' -PropertyType DWord -Value 2 -Force | Out-Null
ipconfig /flushdns | Out-Null

Start-Process -FilePath $exe
