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

$PatchReason = 'expected a gateway model route referencing an Anthropic model (e.g. claude-sonnet-4-5, anthropic/claude-*). Name routes to match the underlying model.'
$PatchedSnippet = 'case"gateway":case"mantle":return{ok:!0}'

function Test-IsAdministrator {
  $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
  $principal = [Security.Principal.WindowsPrincipal]::new($identity)
  return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Write-Status {
  param([string]$Message)
  Write-Host $Message
}

function Find-ClaudePackage {
  if ($ClaudePackagePath) {
    return Get-Item -LiteralPath (Resolve-Path -LiteralPath $ClaudePackagePath).Path
  }

  $packages = @()
  try {
    $packages += @(Get-AppxPackage -AllUsers -ErrorAction Stop)
  } catch {
    try { $packages += @(Get-AppxPackage -ErrorAction Stop) } catch { $packages = @() }
  }

  $match = $packages |
    Where-Object {
      $_.Name -match 'Claude|Anthropic' -or
      $_.PackageFullName -match 'Claude|Anthropic|pzs8sxrjxfjjc'
    } |
    Sort-Object InstallLocation, PackageFullName -Descending |
    Select-Object -First 1

  if ($match -and $match.InstallLocation -and (Test-Path -LiteralPath $match.InstallLocation)) {
    return Get-Item -LiteralPath $match.InstallLocation
  }

  $windowsApps = 'C:\Program Files\WindowsApps'
  if (Test-Path -LiteralPath $windowsApps) {
    $dir = Get-ChildItem -LiteralPath $windowsApps -Directory -ErrorAction SilentlyContinue |
      Where-Object { $_.Name -match '^Claude_|Anthropic|pzs8sxrjxfjjc' } |
      Sort-Object LastWriteTime -Descending |
      Select-Object -First 1
    if ($dir) { return $dir }
  }

  return $null
}

function Get-BackupRoot {
  param([IO.DirectoryInfo]$Package)
  $workspace = Split-Path -Parent $MyInvocation.ScriptName
  if (-not $workspace) { $workspace = (Get-Location).Path }
  return Join-Path $workspace "backups\$($Package.Name)"
}

function Get-ClaudeFrontendFiles {
  param([IO.DirectoryInfo]$Package)
  $ionDist = Join-Path $Package.FullName 'app\resources\ion-dist'
  if (-not (Test-Path -LiteralPath $ionDist)) {
    throw "Claude frontend folder was not found: $ionDist"
  }
  return @(Get-ChildItem -LiteralPath $ionDist -Recurse -File -Filter '*.js' -ErrorAction Stop)
}

function Get-PatchState {
  param([IO.DirectoryInfo]$Package)

  $files = Get-ClaudeFrontendFiles -Package $Package
  $targets = @()
  $alreadyPatched = @()

  foreach ($file in $files) {
    $text = [IO.File]::ReadAllText($file.FullName)
    if ($text.Contains($PatchReason)) { $targets += $file }
    elseif ($text.Contains($PatchedSnippet)) { $alreadyPatched += $file }
  }

  return [pscustomobject]@{
    Package = $Package.FullName
    TargetCount = $targets.Count
    PatchedCount = $alreadyPatched.Count
    Targets = $targets
    PatchedFiles = $alreadyPatched
  }
}

function Grant-FileWriteAccess {
  param([string[]]$Paths)

  $adminSid = 'S-1-5-32-544'
  $adminAccount = ([Security.Principal.SecurityIdentifier]::new($adminSid)).Translate([Security.Principal.NTAccount]).Value

  foreach ($path in $Paths) {
    & takeown.exe /F $path | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Failed to take ownership of $path" }

    & icacls.exe $path /grant:r "${adminAccount}:(F)" | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Failed to grant administrator access to $path" }

    & attrib.exe -R $path | Out-Null
  }
}

function Stop-ClaudeProcesses {
  Get-Process -ErrorAction SilentlyContinue |
    Where-Object { $_.ProcessName -like '*Claude*' } |
    Stop-Process -Force -ErrorAction SilentlyContinue
  Start-Sleep -Milliseconds 800
}

function Apply-FrontendPatch {
  param([IO.DirectoryInfo]$Package)

  $state = Get-PatchState -Package $Package
  if ($state.TargetCount -eq 0) {
    if ($state.PatchedCount -gt 0) {
      Write-Status "Already patched: $($state.PatchedCount) frontend file(s)."
      return $state
    }
    throw 'No known Claude frontend model-route validation snippet was found. Claude may have changed this code.'
  }

  if ($DryRun) {
    Write-Status "Dry run: would patch $($state.TargetCount) file(s)."
    return $state
  }

  if (-not (Test-IsAdministrator)) {
    throw 'Administrator permission is required to modify the protected Claude Desktop package.'
  }

  Stop-ClaudeProcesses
  Grant-FileWriteAccess -Paths @($state.Targets | ForEach-Object { $_.FullName })

  $backupRoot = Get-BackupRoot -Package $Package
  New-Item -ItemType Directory -Force -Path $backupRoot | Out-Null

  $regex = [regex]'case"gateway":case"mantle":return function\(([A-Za-z_$][\w$]*)\)\{return [A-Za-z_$][\w$]*\(\1\)\?\{ok:!0\}:\{ok:!1,reason:"expected a gateway model route referencing an Anthropic model \(e\.g\. claude-sonnet-4-5, anthropic/claude-\*\)\. Name routes to match the underlying model\."\}\}\([A-Za-z_$][\w$]*\)'
  $changed = 0

  foreach ($file in $state.Targets) {
    $relative = $file.FullName.Substring($Package.FullName.Length).TrimStart('\')
    $backup = Join-Path $backupRoot ($relative -replace '[\\/:*?"<>|]', '_')
    if (-not (Test-Path -LiteralPath $backup)) {
      Copy-Item -LiteralPath $file.FullName -Destination $backup -Force
    }

    $text = [IO.File]::ReadAllText($file.FullName)
    $newText = $regex.Replace($text, $PatchedSnippet)
    if ($newText -eq $text) {
      throw "Patch pattern was found by text search but regex replacement failed in $($file.FullName)."
    }
    [IO.File]::WriteAllText($file.FullName, $newText, [Text.UTF8Encoding]::new($false))
    $changed += 1
  }

  Write-Status "Patched $changed Claude Desktop frontend file(s)."
  return Get-PatchState -Package $Package
}

function Restore-FrontendPatch {
  param([IO.DirectoryInfo]$Package)

  $backupRoot = Get-BackupRoot -Package $Package
  if (-not (Test-Path -LiteralPath $backupRoot)) {
    throw "No backups found: $backupRoot"
  }
  if (-not (Test-IsAdministrator)) {
    throw 'Administrator permission is required to restore the protected Claude Desktop package.'
  }

  Stop-ClaudeProcesses
  $backups = @(Get-ChildItem -LiteralPath $backupRoot -File -ErrorAction Stop)
  if (-not $backups) { throw "No backup files found in $backupRoot" }

  $restored = 0
  foreach ($backup in $backups) {
    $targetName = $backup.Name
    $target = Get-ClaudeFrontendFiles -Package $Package |
      Where-Object { (($_.FullName.Substring($Package.FullName.Length).TrimStart('\')) -replace '[\\/:*?"<>|]', '_') -eq $targetName } |
      Select-Object -First 1
    if ($target) {
      Grant-FileWriteAccess -Paths @($target.FullName)
      Copy-Item -LiteralPath $backup.FullName -Destination $target.FullName -Force
      $restored += 1
    }
  }

  Write-Status "Restored $restored Claude Desktop frontend file(s)."
}

function Restart-SelfElevated {
  if ($NoElevate -or (Test-IsAdministrator) -or $DryRun) { return }
  if (-not $PSCommandPath) { throw 'This script must be run from a saved .ps1 file to request administrator rights.' }

  $args = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$PSCommandPath`"", '-NoGui', '-NoElevate')
  if ($ClaudePackagePath) { $args += @('-ClaudePackagePath', "`"$ClaudePackagePath`"") }
  if ($SkipLaunch) { $args += '-SkipLaunch' }
  if ($Quiet) { $args += '-Quiet' }
  if ($Revert) { $args += '-Revert' }

  $process = Start-Process -FilePath 'powershell.exe' -ArgumentList $args -Verb RunAs -Wait -PassThru
  exit $process.ExitCode
}

function Launch-Claude {
  param([IO.DirectoryInfo]$Package)
  $exe = Join-Path $Package.FullName 'app\Claude.exe'
  if ((Test-Path -LiteralPath $exe) -and -not $SkipLaunch) {
    Start-Process -FilePath $exe
  }
}

function Run-Console {
  Restart-SelfElevated

  $package = Find-ClaudePackage
  if (-not $package) { throw 'Claude Desktop package was not found. Install Claude Desktop, open it once, then rerun this helper.' }

  $state = Get-PatchState -Package $package
  Write-Status "Claude package: $($package.FullName)"
  Write-Status "Needs patch: $($state.TargetCount)"
  Write-Status "Already patched: $($state.PatchedCount)"

  if ($DryRun) { return }

  if ($Revert) {
    Restore-FrontendPatch -Package $package
  } else {
    Apply-FrontendPatch -Package $package | Out-Null
  }

  Launch-Claude -Package $package
}

function Show-Gui {
  Add-Type -AssemblyName System.Windows.Forms
  Add-Type -AssemblyName System.Drawing

  $form = [Windows.Forms.Form]::new()
  $form.Text = 'Claude Desktop Tweak Models'
  $form.Size = [Drawing.Size]::new(760, 500)
  $form.StartPosition = 'CenterScreen'

  $title = [Windows.Forms.Label]::new()
  $title.Text = 'Claude Desktop frontend model validation patch'
  $title.Font = [Drawing.Font]::new('Segoe UI', 14, [Drawing.FontStyle]::Bold)
  $title.AutoSize = $true
  $title.Location = [Drawing.Point]::new(18, 18)
  $form.Controls.Add($title)

  $summary = [Windows.Forms.Label]::new()
  $summary.Text = 'This only relaxes the local frontend model ID check for Gateway / Mantle providers. It does not configure a gateway, store API keys, edit app.asar, block hosts, or disable updates.'
  $summary.Size = [Drawing.Size]::new(700, 48)
  $summary.Location = [Drawing.Point]::new(20, 55)
  $form.Controls.Add($summary)

  $log = [Windows.Forms.TextBox]::new()
  $log.Multiline = $true
  $log.ReadOnly = $true
  $log.ScrollBars = 'Vertical'
  $log.Font = [Drawing.Font]::new('Consolas', 10)
  $log.Location = [Drawing.Point]::new(20, 115)
  $log.Size = [Drawing.Size]::new(700, 260)
  $form.Controls.Add($log)

  function Add-Log([string]$Text) {
    $log.AppendText("[$(Get-Date -Format HH:mm:ss)] $Text`r`n")
  }

  $btnDetect = [Windows.Forms.Button]::new()
  $btnDetect.Text = 'Detect'
  $btnDetect.Location = [Drawing.Point]::new(20, 395)
  $btnDetect.Size = [Drawing.Size]::new(110, 34)
  $form.Controls.Add($btnDetect)

  $btnPatch = [Windows.Forms.Button]::new()
  $btnPatch.Text = 'Apply Patch'
  $btnPatch.Location = [Drawing.Point]::new(145, 395)
  $btnPatch.Size = [Drawing.Size]::new(130, 34)
  $form.Controls.Add($btnPatch)

  $btnRestore = [Windows.Forms.Button]::new()
  $btnRestore.Text = 'Restore'
  $btnRestore.Location = [Drawing.Point]::new(290, 395)
  $btnRestore.Size = [Drawing.Size]::new(110, 34)
  $form.Controls.Add($btnRestore)

  $btnClose = [Windows.Forms.Button]::new()
  $btnClose.Text = 'Close'
  $btnClose.Location = [Drawing.Point]::new(610, 395)
  $btnClose.Size = [Drawing.Size]::new(110, 34)
  $form.Controls.Add($btnClose)

  $btnDetect.Add_Click({
    try {
      $package = Find-ClaudePackage
      if (-not $package) { Add-Log 'Claude Desktop package was not found. Reinstall Claude Desktop, open it once, then run this helper again.'; return }
      $state = Get-PatchState -Package $package
      Add-Log "Package: $($package.FullName)"
      Add-Log "Needs patch: $($state.TargetCount); already patched: $($state.PatchedCount)"
    } catch { Add-Log "ERROR: $($_.Exception.Message)" }
  })

  $btnPatch.Add_Click({
    try {
      $args = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$PSCommandPath`"", '-NoGui')
      Start-Process -FilePath 'powershell.exe' -ArgumentList $args -Verb RunAs -Wait
      Add-Log 'Patch command finished. Click Detect to refresh status.'
    } catch { Add-Log "ERROR: $($_.Exception.Message)" }
  })

  $btnRestore.Add_Click({
    try {
      $args = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$PSCommandPath`"", '-NoGui', '-Revert')
      Start-Process -FilePath 'powershell.exe' -ArgumentList $args -Verb RunAs -Wait
      Add-Log 'Restore command finished. Click Detect to refresh status.'
    } catch { Add-Log "ERROR: $($_.Exception.Message)" }
  })

  $btnClose.Add_Click({ $form.Close() })
  $form.Add_Shown({ $btnDetect.PerformClick() })
  [void]$form.ShowDialog()
}

if (-not $NoGui -and -not $Quiet -and -not $DryRun -and -not $Revert) {
  Show-Gui
} else {
  Run-Console
}
