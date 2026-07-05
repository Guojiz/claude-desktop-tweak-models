param(
  [string]$ClaudePackagePath,
  [switch]$DryRun,
  [switch]$NoElevate,
  [switch]$SkipLaunch,
  [switch]$Quiet
)

$ErrorActionPreference = 'Stop'

function Test-IsAdministrator {
  $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
  $principal = [Security.Principal.WindowsPrincipal]::new($identity)
  return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Show-SetupMessage {
  param(
    [string]$Title,
    [string]$Message,
    [string]$Url
  )

  if ($Quiet) {
    Write-Host "$Title`n$Message"
    if ($Url) { Write-Host $Url }
    return
  }

  Add-Type -AssemblyName System.Windows.Forms
  $buttons = if ($Url) {
    [System.Windows.Forms.MessageBoxButtons]::OKCancel
  } else {
    [System.Windows.Forms.MessageBoxButtons]::OK
  }
  $result = [System.Windows.Forms.MessageBox]::Show($Message, $Title, $buttons, [System.Windows.Forms.MessageBoxIcon]::Information)
  if ($Url -and $result -eq [System.Windows.Forms.DialogResult]::OK) {
    Start-Process $Url
  }
}

function Request-ClaudeInstall {
  $downloadUrl = 'https://claude.ai/api/desktop/win32/x64/exe/latest/redirect'

  if ($Quiet) {
    Write-Host 'Claude Desktop was not found.'
    Write-Host 'Install it from the official Anthropic download URL, open Claude once, then run this helper again:'
    Write-Host $downloadUrl
    return $null
  }

  Add-Type -AssemblyName System.Windows.Forms
  $message = @"
Claude Desktop was not found for this Windows user.

Choose OK to download and run the official Claude Desktop Windows installer from Anthropic. After the installer finishes, this helper will look for Claude again.

Choose Cancel to open the public download page instead.
"@
  $result = [System.Windows.Forms.MessageBox]::Show($message, 'Install Claude Desktop', [System.Windows.Forms.MessageBoxButtons]::OKCancel, [System.Windows.Forms.MessageBoxIcon]::Information)

  if ($result -ne [System.Windows.Forms.DialogResult]::OK) {
    Start-Process 'https://claude.ai/download'
    return $null
  }

  $installer = Join-Path $env:TEMP 'ClaudeSetup.exe'
  try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -UseBasicParsing -Uri $downloadUrl -OutFile $installer
    $installProcess = Start-Process -FilePath $installer -Wait -PassThru
    if ($installProcess.ExitCode -ne 0) {
      throw "Claude installer exited with code $($installProcess.ExitCode)."
    }
    return Find-ClaudePackage
  } catch {
    Show-SetupMessage `
      -Title 'Claude Desktop install failed' `
      -Message "The helper could not download or run the official installer automatically.`n`nOpen the official download page, install Claude Desktop, open it once, then run this helper again.`n`nError: $($_.Exception.Message)" `
      -Url 'https://claude.ai/download'
    return $null
  }
}

function Restart-SelfElevated {
  if ($NoElevate -or (Test-IsAdministrator)) {
    return
  }

  $scriptPath = $PSCommandPath
  if (-not $scriptPath) {
    throw 'This script must be run from a saved .ps1 file so it can request administrator rights.'
  }

  $args = @(
    '-NoProfile',
    '-ExecutionPolicy', 'Bypass',
    '-File', "`"$scriptPath`""
  )

  if ($ClaudePackagePath) { $args += @('-ClaudePackagePath', "`"$ClaudePackagePath`"") }
  if ($DryRun) { $args += '-DryRun' }
  if ($SkipLaunch) { $args += '-SkipLaunch' }
  if ($Quiet) { $args += '-Quiet' }
  $args += '-NoElevate'

  Show-SetupMessage `
    -Title 'Claude Desktop Setup' `
    -Message 'Claude Desktop needs administrator permission so this helper can patch the protected Windows app package, update integrity metadata, and apply update protection. Choose OK in the next Windows prompt to continue.' `
    -Url $null

  $process = Start-Process -FilePath 'powershell.exe' -ArgumentList $args -Verb RunAs -Wait -PassThru
  exit $process.ExitCode
}

function Find-ClaudePackage {
  if ($ClaudePackagePath) {
    $resolved = Resolve-Path -LiteralPath $ClaudePackagePath -ErrorAction Stop
    return Get-Item -LiteralPath $resolved.Path
  }

  $rawAppxPackages = @()
  try {
    $rawAppxPackages += @(Get-AppxPackage -AllUsers -ErrorAction Stop)
  } catch {
    try {
      $rawAppxPackages += @(Get-AppxPackage -ErrorAction Stop)
    } catch {
      $rawAppxPackages = @()
    }
  }

  $appxPackages = @($rawAppxPackages |
    Where-Object {
      $_.Name -match 'Claude|Anthropic' -or
      $_.PackageFullName -match 'Claude|Anthropic|pzs8sxrjxfjjc'
    } |
    Sort-Object InstallLocation, PackageFullName -Descending)

  foreach ($appx in $appxPackages) {
    if ($appx.InstallLocation -and (Test-Path -LiteralPath $appx.InstallLocation)) {
      return Get-Item -LiteralPath $appx.InstallLocation
    }
  }

  $windowsApps = 'C:\Program Files\WindowsApps'
  if (Test-Path -LiteralPath $windowsApps) {
    $packages = @(Get-ChildItem -LiteralPath $windowsApps -Directory -ErrorAction SilentlyContinue |
      Where-Object { $_.Name -match '^Claude_|Anthropic|pzs8sxrjxfjjc' } |
      Sort-Object LastWriteTime -Descending)
    if ($packages) {
      return $packages[0]
    }
  }

  return $null
}

function Ensure-ClaudeUserConfig {
  $configDir = Join-Path $env:APPDATA 'Claude'
  $configPath = Join-Path $configDir 'claude_desktop_config.json'
  $guidePath = Join-Path $configDir 'third-party-model-setup.txt'

  New-Item -ItemType Directory -Force -Path $configDir | Out-Null

  if (-not (Test-Path -LiteralPath $configPath)) {
    @'
{
  "mcpServers": {}
}
'@ | Set-Content -LiteralPath $configPath -Encoding UTF8
  }

  @'
Claude Desktop third-party model setup

This helper has patched Claude Desktop so Gateway / Mantle model IDs can use non-Anthropic names.

After Claude opens:
1. Open Settings.
2. Enable Developer Mode if it is not already enabled.
3. Open the third-party inference / models / providers section.
4. Add a Gateway provider.
5. Fill in the gateway details from your provider.

Example:
Provider: Gateway
Gateway base URL: https://open.bigmodel.cn/api/anthropic
Gateway auth scheme: x-api-key
Model ID: glm-5.2
Display name: GLM-5.2
Model discovery: off

Do not paste API keys into this helper. Enter keys only in Claude Desktop or your trusted provider UI.
'@ | Set-Content -LiteralPath $guidePath -Encoding UTF8

  return @{
    ConfigPath = $configPath
    GuidePath = $guidePath
  }
}

function Grant-ClaudeFileAccess {
  param([string[]]$Paths)

  $adminSid = 'S-1-5-32-544'
  $adminAccount = ([Security.Principal.SecurityIdentifier]::new($adminSid)).Translate([Security.Principal.NTAccount]).Value

  foreach ($path in $Paths) {
    if (-not (Test-Path -LiteralPath $path)) {
      throw "Required Claude file was not found: $path"
    }

    & takeown.exe /F $path | Out-Null
    if ($LASTEXITCODE -ne 0) {
      throw "Failed to take ownership of $path"
    }

    & icacls.exe $path /grant:r "${adminAccount}:(F)" | Out-Null
    if ($LASTEXITCODE -ne 0) {
      throw "Failed to grant administrator access to $path"
    }
  }
}

function Stop-ClaudeProcesses {
  Get-Process -ErrorAction SilentlyContinue |
    Where-Object { $_.ProcessName -like '*Claude*' } |
    Stop-Process -Force -ErrorAction SilentlyContinue
  Start-Sleep -Milliseconds 800
}

Restart-SelfElevated

$workspace = Split-Path -Parent $MyInvocation.MyCommand.Path
$package = Find-ClaudePackage

if (-not $package) {
  $package = Request-ClaudeInstall
  if (-not $package) {
    throw 'Claude Desktop package was not found.'
  }
}

$appDir = Join-Path $package.FullName 'app'
$exe = Join-Path $appDir 'Claude.exe'
$asar = Join-Path $appDir 'resources\app.asar'
$ionDist = Join-Path $appDir 'resources\ion-dist'
$backupDir = Join-Path $workspace "backups\$($package.Name)"
$userConfig = Ensure-ClaudeUserConfig

if ($DryRun) {
  Write-Host "Claude package: $($package.FullName)"
  Write-Host "Claude exe: $exe"
  Write-Host "Claude asar: $asar"
  Write-Host "User config: $($userConfig.ConfigPath)"
  Write-Host "Setup guide: $($userConfig.GuidePath)"
  return
}

New-Item -ItemType Directory -Force -Path $backupDir | Out-Null

Stop-ClaudeProcesses
Grant-ClaudeFileAccess -Paths @($exe, $asar)

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
        'async function mVn(){D.info("[updater] Disabled locally to preserve third-party model patch")}',
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
$marker = '# Claude auto-update block - keep patched third-party model setup'
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

Show-SetupMessage `
  -Title 'Claude Desktop is ready' `
  -Message "Claude Desktop has been patched and a first-run setup guide was saved here:`n`n$($userConfig.GuidePath)`n`nIf Developer Mode is not already enabled inside Claude, open Settings and enable it before adding your Gateway provider." `
  -Url $null

if (-not $SkipLaunch) {
  Start-Process -FilePath $exe
}
