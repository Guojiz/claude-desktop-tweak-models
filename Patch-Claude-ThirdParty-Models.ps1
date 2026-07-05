param(
  [string]$ClaudePackagePath,
  [switch]$DryRun,
  [switch]$NoElevate,
  [switch]$SkipLaunch,
  [switch]$Quiet,
  [switch]$NoGui,
  [switch]$Revert
)

$ErrorActionPreference = 'Stop'
$repo = 'Guojiz/claude-desktop-tweak-models'
$branch = 'main'
$legacyScript = 'Protect-Claude-Zhipu-GLM52.ps1'
$installDir = Join-Path $env:USERPROFILE '.claude-desktop-tweak-models'
$scriptPath = Join-Path $installDir $legacyScript
$scriptUrl = "https://raw.githubusercontent.com/$repo/$branch/$legacyScript"

New-Item -ItemType Directory -Force -Path $installDir | Out-Null
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Invoke-WebRequest -UseBasicParsing -Uri $scriptUrl -OutFile $scriptPath

$argsList = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $scriptPath)
if ($ClaudePackagePath) { $argsList += @('-ClaudePackagePath', $ClaudePackagePath) }
if ($DryRun) { $argsList += '-DryRun' }
if ($NoElevate) { $argsList += '-NoElevate' }
if ($SkipLaunch) { $argsList += '-SkipLaunch' }
if ($Quiet) { $argsList += '-Quiet' }
if ($NoGui) { $argsList += '-NoGui' }
if ($Revert) { $argsList += '-Revert' }

& powershell @argsList
exit $LASTEXITCODE
