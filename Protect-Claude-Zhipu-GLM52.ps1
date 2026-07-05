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
$AsarPatchedSnippet = 'function Vri(A){return{ok:!0}}'
$AsarValidationRegex = [regex]'function\s+([A-Za-z_$][\w$]*)\(([A-Za-z_$][\w$]*)\)\{return\s+[A-Za-z_$][\w$]*\(\2\)\?\{ok:!0\}:\{ok:!1,reason:"expected a gateway model route referencing an Anthropic model \(e\.g\. claude-sonnet-4-5, anthropic/claude-\*\)\. Name routes to match the underlying model\."\}\}'

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

function Get-ClaudePaths {
  param([IO.DirectoryInfo]$Package)
  $exe = Join-Path $Package.FullName 'app\Claude.exe'
  $asar = Join-Path $Package.FullName 'app\resources\app.asar'
  if (-not (Test-Path -LiteralPath $exe)) { throw "Claude.exe was not found: $exe" }
  if (-not (Test-Path -LiteralPath $asar)) { throw "app.asar was not found: $asar" }
  return [pscustomobject]@{
    Exe = $exe
    Asar = $asar
  }
}

function Get-PatchState {
  param([IO.DirectoryInfo]$Package)

  $files = Get-ClaudeFrontendFiles -Package $Package
  $paths = Get-ClaudePaths -Package $Package
  $targets = @()
  $alreadyPatched = @()

  foreach ($file in $files) {
    $text = [IO.File]::ReadAllText($file.FullName)
    if ($text.Contains($PatchReason)) { $targets += $file }
    elseif ($text.Contains($PatchedSnippet)) { $alreadyPatched += $file }
  }

  $asarText = [IO.File]::ReadAllText($paths.Asar, [Text.Encoding]::GetEncoding(28591))
  $asarNeedsPatch = $AsarValidationRegex.IsMatch($asarText)
  $asarAlreadyPatched = $asarText.Contains($AsarPatchedSnippet)

  return [pscustomobject]@{
    Package = $Package.FullName
    TargetCount = $targets.Count
    PatchedCount = $alreadyPatched.Count
    Targets = $targets
    PatchedFiles = $alreadyPatched
    AsarNeedsPatch = $asarNeedsPatch
    AsarAlreadyPatched = $asarAlreadyPatched
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
  if ($state.TargetCount -eq 0 -and -not $state.AsarNeedsPatch) {
    if ($state.PatchedCount -gt 0 -and $state.AsarAlreadyPatched) {
      Write-Status "Already patched: $($state.PatchedCount) frontend file(s) and app.asar."
      return $state
    }
    throw 'No known Claude model-route validation snippet was found. Claude may have changed this code.'
  }

  if ($DryRun) {
    Write-Status "Dry run: would patch $($state.TargetCount) frontend file(s); app.asar needs patch: $($state.AsarNeedsPatch)."
    return $state
  }

  if (-not (Test-IsAdministrator)) {
    throw 'Administrator permission is required to modify the protected Claude Desktop package.'
  }

  $paths = Get-ClaudePaths -Package $Package
  Stop-ClaudeProcesses
  Grant-FileWriteAccess -Paths @(@($state.Targets | ForEach-Object { $_.FullName }) + @($paths.Asar, $paths.Exe))

  $backupRoot = Get-BackupRoot -Package $Package
  New-Item -ItemType Directory -Force -Path $backupRoot | Out-Null
  if (-not (Test-Path -LiteralPath (Join-Path $backupRoot 'app.asar.original'))) {
    Copy-Item -LiteralPath $paths.Asar -Destination (Join-Path $backupRoot 'app.asar.original') -Force
  }
  if (-not (Test-Path -LiteralPath (Join-Path $backupRoot 'Claude.exe.original'))) {
    Copy-Item -LiteralPath $paths.Exe -Destination (Join-Path $backupRoot 'Claude.exe.original') -Force
  }

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

  $asarChanged = Patch-AsarValidation -AsarPath $paths.Asar
  $integrityChanges = Repair-AsarIntegrity -ExePath $paths.Exe -AsarPath $paths.Asar

  Write-Status "Patched $changed frontend file(s), app.asar changes: $asarChanged, integrity fixes: $integrityChanges."
  return Get-PatchState -Package $Package
}

function Patch-AsarValidation {
  param([string]$AsarPath)

  $encoding = [Text.Encoding]::GetEncoding(28591)
  $text = [IO.File]::ReadAllText($AsarPath, $encoding)
  if ($text.Contains($AsarPatchedSnippet) -and -not $text.Contains($PatchReason)) {
    return 0
  }

  $matches = @($AsarValidationRegex.Matches($text))
  if (-not $matches) {
    if ($text.Contains($PatchReason)) {
      throw 'app.asar contains the validation error text, but the function pattern was not recognized.'
    }
    return 0
  }

  $newText = $text
  for ($i = $matches.Count - 1; $i -ge 0; $i--) {
    $match = $matches[$i]
    $replacement = "function $($match.Groups[1].Value)($($match.Groups[2].Value)){return{ok:!0}}"
    if ($replacement.Length -gt $match.Value.Length) {
      throw 'app.asar replacement is longer than the original validation function.'
    }
    $replacement = $replacement + (' ' * ($match.Value.Length - $replacement.Length))
    $newText = $newText.Remove($match.Index, $match.Length).Insert($match.Index, $replacement)
  }

  [IO.File]::WriteAllText($AsarPath, $newText, $encoding)
  return $matches.Count
}

function Repair-AsarIntegrity {
  param(
    [string]$ExePath,
    [string]$AsarPath
  )

  $encoding = [Text.Encoding]::GetEncoding(28591)
  $fixed = 0
  for ($i = 0; $i -lt 12; $i++) {
    $stdout = Join-Path $env:TEMP "claude_tweak_integrity_$i.out.txt"
    $stderr = Join-Path $env:TEMP "claude_tweak_integrity_$i.err.txt"
    Remove-Item $stdout, $stderr -ErrorAction SilentlyContinue

    $process = Start-Process -FilePath $ExePath -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
    Start-Sleep -Seconds 6
    if (-not $process.HasExited) {
      Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
    }

    $output = ((Get-Content -LiteralPath $stdout -Raw -ErrorAction SilentlyContinue) + "`n" + (Get-Content -LiteralPath $stderr -Raw -ErrorAction SilentlyContinue))
    if ($output -notmatch '(?:hash mismatch|Integrity check failed for asar archive) \(([0-9a-f]{64}) vs ([0-9a-f]{64})\)') {
      return $fixed
    }

    $left = $Matches[1]
    $right = $Matches[2]
    $updated = $false

    foreach ($candidate in @($AsarPath, $ExePath)) {
      $data = [IO.File]::ReadAllText($candidate, $encoding)
      if ($data.Contains($right)) {
        [IO.File]::WriteAllText($candidate, $data.Replace($right, $left), $encoding)
        Write-Status "Fixed integrity hash in $candidate`: $right -> $left"
        $fixed += 1
        $updated = $true
        break
      }
    }

    if (-not $updated) {
      foreach ($candidate in @($AsarPath, $ExePath)) {
        $data = [IO.File]::ReadAllText($candidate, $encoding)
        if ($data.Contains($left)) {
          [IO.File]::WriteAllText($candidate, $data.Replace($left, $right), $encoding)
          Write-Status "Fixed archive hash in $candidate`: $left -> $right"
          $fixed += 1
          $updated = $true
          break
        }
      }
    }

    if (-not $updated) {
      throw "Claude reported an integrity mismatch, but neither hash could be found in app.asar or Claude.exe: $left vs $right"
    }
  }

  throw 'Claude still reports ASAR integrity mismatches after 12 repair attempts.'
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
    if ($backup.Name -eq 'app.asar.original') {
      $paths = Get-ClaudePaths -Package $Package
      Grant-FileWriteAccess -Paths @($paths.Asar)
      Copy-Item -LiteralPath $backup.FullName -Destination $paths.Asar -Force
      $restored += 1
      continue
    }
    if ($backup.Name -eq 'Claude.exe.original') {
      $paths = Get-ClaudePaths -Package $Package
      Grant-FileWriteAccess -Paths @($paths.Exe)
      Copy-Item -LiteralPath $backup.FullName -Destination $paths.Exe -Force
      $restored += 1
      continue
    }
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

  Write-Status "Restored $restored Claude Desktop file(s)."
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
  Write-Status "app.asar needs patch: $($state.AsarNeedsPatch)"
  Write-Status "app.asar already patched: $($state.AsarAlreadyPatched)"

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
  $title.Text = 'Claude Desktop model validation patch'
  $title.Font = [Drawing.Font]::new('Segoe UI', 14, [Drawing.FontStyle]::Bold)
  $title.AutoSize = $true
  $title.Location = [Drawing.Point]::new(18, 18)
  $form.Controls.Add($title)

  $summary = [Windows.Forms.Label]::new()
  $summary.Text = 'Automatically relaxes Claude Desktop model ID validation in frontend assets and app.asar, then repairs Electron integrity metadata. It does not configure a gateway, store API keys, block hosts, or disable updates.'
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
      if (-not $package) { Add-Log 'Claude Desktop package was not found.'; return }
      $state = Get-PatchState -Package $package
      Add-Log "Package: $($package.FullName)"
      Add-Log "Frontend needs patch: $($state.TargetCount); already patched: $($state.PatchedCount)"
      Add-Log "app.asar needs patch: $($state.AsarNeedsPatch); already patched: $($state.AsarAlreadyPatched)"
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
