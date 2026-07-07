param(
  [string]$ConfigPath = "$env:USERPROFILE\.claude-desktop-tweak-models\router.config.json",
  [int]$Port = 4318,
  [string]$HostAddress = "127.0.0.1"
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
$startScript = Join-Path $repoRoot 'router\Start-Claude-Model-Router.ps1'
$startupDir = [Environment]::GetFolderPath('Startup')
$cmdPath = Join-Path $startupDir 'Claude Model Router.cmd'

$cmd = @"
@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "$startScript" -ConfigPath "$ConfigPath" -HostAddress "$HostAddress" -Port $Port
"@

Set-Content -LiteralPath $cmdPath -Value $cmd -Encoding ASCII
Write-Host "Installed startup launcher: $cmdPath"
Write-Host 'The router will start after the next Windows sign-in.'
