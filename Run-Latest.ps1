$ErrorActionPreference = 'Stop'

$repo = 'Guojiz/claude-desktop-tweak-models'
$branch = 'main'
$installDir = Join-Path $env:USERPROFILE '.claude-desktop-tweak-models'
$scriptName = 'Protect-Claude-Zhipu-GLM52.ps1'
$scriptUrl = "https://raw.githubusercontent.com/$repo/$branch/$scriptName"
$scriptPath = Join-Path $installDir $scriptName

New-Item -ItemType Directory -Force -Path $installDir | Out-Null

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Invoke-WebRequest -UseBasicParsing -Uri $scriptUrl -OutFile $scriptPath

powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath
