param(
  [string]$ConfigPath = "$env:USERPROFILE\.claude-desktop-tweak-models\router.config.json",
  [int]$Port = 4318,
  [string]$HostAddress = "127.0.0.1"
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
$routerScript = Join-Path $repoRoot 'router\claude-model-router.mjs'
$nodeCandidates = @(
  "$env:USERPROFILE\.cache\codex-runtimes\codex-primary-runtime\dependencies\node\bin\node.exe",
  'node.exe'
)

$node = $nodeCandidates | Where-Object {
  try { Get-Command $_ -ErrorAction Stop | Out-Null; $true } catch { Test-Path -LiteralPath $_ }
} | Select-Object -First 1

if (-not $node) {
  throw 'Node.js was not found. Install Node.js or run this from Codex Desktop where the bundled Node runtime exists.'
}

if (-not (Test-Path -LiteralPath $ConfigPath)) {
  $targetDir = Split-Path -Parent $ConfigPath
  New-Item -ItemType Directory -Force -Path $targetDir | Out-Null
  Copy-Item -LiteralPath (Join-Path $repoRoot 'router\router.config.example.json') -Destination $ConfigPath -Force
  Write-Host "Created example config: $ConfigPath"
  Write-Host 'Edit it and set provider API keys via environment variables before using the router.'
}

& $node $routerScript --config $ConfigPath --host $HostAddress --port $Port
