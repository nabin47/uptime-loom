# SetupHeartbeat.ps1 -- Uptime Loom installer / uninstaller.
#
# You don't need to run this file directly: double-click Install.cmd (or
# Uninstall.cmd) instead. Those run this script in a way that works even
# when PowerShell scripts are blocked or open in Notepad when double-clicked.
#
# No administrator rights are needed: everything goes into your own user
# profile (C:\Users\<you>\UptimeLoom, your Startup folder, Desktop and
# Start menu).
#
# Written to also work on locked-down PCs (Group Policy execution policy,
# PowerShell "Constrained Language Mode"): every step that might be blocked
# has a simpler fallback, and a log of the run is saved to
# UptimeLoom\install-log.txt.

param(
    [switch]$Uninstall,
    [string]$SourceDir
)

$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------- paths --
if (-not $SourceDir) {
    if ($env:UL_SRC)       { $SourceDir = $env:UL_SRC }
    elseif ($PSScriptRoot) { $SourceDir = $PSScriptRoot }
    else                   { $SourceDir = (Get-Location).Path }
}
$SourceDir = $SourceDir.TrimEnd('\')
$AppDir    = Join-Path $env:USERPROFILE 'UptimeLoom'

function Get-KnownFolder([string]$Name, [string]$Fallback) {
    try {
        $p = [Environment]::GetFolderPath($Name)
        if ($p) { return $p }
    } catch { }
    return $Fallback
}
$StartupDir  = Get-KnownFolder 'Startup'  "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup"
$ProgramsDir = Get-KnownFolder 'Programs' "$env:APPDATA\Microsoft\Windows\Start Menu\Programs"
$DesktopDir  = Get-KnownFolder 'Desktop'  "$env:USERPROFILE\Desktop"

# Everything this installer may create (old and new names), so updates and
# uninstall can clean up reliably.
$StartupLnk     = Join-Path $StartupDir  'UptimeLoom.lnk'
$StartupCmd     = Join-Path $StartupDir  'UptimeLoom.cmd'
$DashLnk        = Join-Path $DesktopDir  'Uptime Loom.lnk'
$DashUrl        = Join-Path $DesktopDir  'Uptime Loom.url'
$GoOutLnk       = Join-Path $DesktopDir  'Uptime Loom - Going out.lnk'
$GoOutCmd       = Join-Path $DesktopDir  'Uptime Loom - Going out.cmd'
$MenuDashLnk    = Join-Path $ProgramsDir 'Uptime Loom.lnk'
$MenuGoOutLnk   = Join-Path $ProgramsDir 'Uptime Loom - Going out.lnk'

# ------------------------------------------------------------- helpers --
function Say([string]$Text)  { Write-Host "  $Text" }
function Ok([string]$Text)   { Write-Host "  [OK]   $Text" -ForegroundColor Green }
function Warn([string]$Text) { Write-Host "  [!]    $Text" -ForegroundColor Yellow }
function Fail([string]$Text) { Write-Host "  [X]    $Text" -ForegroundColor Red }

# Command line that runs one of our scripts hidden. The script's text is
# loaded and run as a script block instead of with -File, so it works even
# when a policy blocks running .ps1 files. Uses %USERPROFILE% at run time,
# so paths with spaces or apostrophes are never a problem.
function Get-LaunchArgs([string]$ScriptName, [string]$ExtraArgs = '') {
    return "-NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -Command `"& ([scriptblock]::Create((Get-Content -LiteralPath (Join-Path `$env:USERPROFILE 'UptimeLoom\$ScriptName') -Raw -Encoding UTF8)))$ExtraArgs`""
}

function New-Shortcut {
    param([string]$Path, [string]$Target, [string]$Arguments = '', [string]$Description = '',
          [string]$Hotkey = '', [string]$Icon = '', [int]$WindowStyle = 1)
    $shell = New-Object -ComObject WScript.Shell
    $sc = $shell.CreateShortcut($Path)
    $sc.TargetPath = $Target
    if ($Arguments)   { $sc.Arguments = $Arguments }
    $sc.WorkingDirectory = $AppDir
    $sc.WindowStyle = $WindowStyle
    if ($Description) { $sc.Description = $Description }
    if ($Icon)        { $sc.IconLocation = $Icon }
    if ($Hotkey)      { $sc.Hotkey = $Hotkey }
    $sc.Save()
}

function Remove-IfExists([string[]]$Paths) {
    foreach ($p in $Paths) {
        if ($p -and (Test-Path -LiteralPath $p)) {
            Remove-Item -LiteralPath $p -Force -ErrorAction SilentlyContinue
        }
    }
}

# Stop any running heartbeat logger (older or current version) so the new
# one takes over straight away -- no need to log off.
function Stop-Heartbeat {
    $stopped = 0
    try {
        $procs = Get-CimInstance Win32_Process -Filter "Name='powershell.exe' OR Name='pwsh.exe'" -ErrorAction Stop |
            Where-Object { $_.ProcessId -ne $PID -and $_.CommandLine -match 'UptimeLoom\\Heartbeat\.ps1' }
        foreach ($p in $procs) {
            try { Stop-Process -Id $p.ProcessId -Force -ErrorAction Stop; $stopped++ } catch { }
        }
    } catch { }
    return $stopped
}

function Start-Heartbeat {
    Start-Process -FilePath 'powershell.exe' -ArgumentList (Get-LaunchArgs 'Heartbeat.ps1') -WindowStyle Hidden -WorkingDirectory $AppDir
}

$WinPS = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
if (-not (Test-Path -LiteralPath $WinPS)) { $WinPS = 'powershell.exe' }

Write-Host ""
Write-Host "  Uptime Loom" -ForegroundColor Cyan
Write-Host "  -----------" -ForegroundColor Cyan
Write-Host ""

# ------------------------------------------------------------ uninstall --
if ($Uninstall) {
    $n = Stop-Heartbeat
    if ($n -gt 0) { Ok "Stopped the background logger." } else { Say "The background logger wasn't running." }
    Remove-IfExists @($StartupLnk, $StartupCmd, $DashLnk, $DashUrl, $GoOutLnk, $GoOutCmd, $MenuDashLnk, $MenuGoOutLnk,
                      (Join-Path $AppDir 'away.flag'))
    Ok "Removed the startup entry and shortcuts."
    Write-Host ""
    Say "Your tracked data has been kept in:"
    Say "  $AppDir"
    Say "Delete that folder if you don't need it any more."
    return
}

# -------------------------------------------------------------- install --
$transcript = $false
try {
    if (-not (Test-Path -LiteralPath $AppDir)) { New-Item -ItemType Directory -Path $AppDir | Out-Null }
    try { Start-Transcript -LiteralPath (Join-Path $AppDir 'install-log.txt') -Force | Out-Null; $transcript = $true } catch { }

    $mode = $ExecutionContext.SessionState.LanguageMode
    $psv  = $PSVersionTable.PSVersion
    Write-Host "  (PowerShell $psv, $mode, installing from $SourceDir)" -ForegroundColor DarkGray

    # 1. Check the downloaded files are all here.
    $needed  = @('Heartbeat.ps1', 'GoingOut.ps1', 'dashboard.html', 'SetupHeartbeat.ps1')
    $missing = @($needed | Where-Object { -not (Test-Path -LiteralPath (Join-Path $SourceDir $_)) })
    if ($missing.Count -gt 0) {
        Fail "Missing file(s) next to Install.cmd: $($missing -join ', ')"
        Say  "Extract the whole ZIP first (right-click > Extract All), then run Install.cmd again."
        exit 1
    }

    # 2. Stop an already-running logger (update / reinstall).
    $n = Stop-Heartbeat
    if ($n -gt 0) { Ok "Stopped the previous version of the logger." }

    # 3. Copy the program files into C:\Users\<you>\UptimeLoom.
    $same = $false
    try { $same = ((Resolve-Path -LiteralPath $SourceDir).Path.TrimEnd('\') -ieq (Resolve-Path -LiteralPath $AppDir).Path.TrimEnd('\')) } catch { }
    if (-not $same) {
        foreach ($f in @($needed + @('Install.cmd', 'Uninstall.cmd', 'README.md'))) {
            $src = Join-Path $SourceDir $f
            if (Test-Path -LiteralPath $src) { Copy-Item -LiteralPath $src -Destination (Join-Path $AppDir $f) -Force }
        }
    }
    # Clear the "downloaded from the internet" mark on the installed copies.
    Get-ChildItem -LiteralPath $AppDir -File | ForEach-Object {
        try { Unblock-File -LiteralPath $_.FullName -ErrorAction Stop } catch { }
    }
    Ok "Installed to $AppDir"

    # 4. Start automatically at every login (Startup folder, no admin).
    Remove-IfExists @($StartupLnk, $StartupCmd)
    try {
        New-Shortcut -Path $StartupLnk -Target $WinPS -Arguments (Get-LaunchArgs 'Heartbeat.ps1') `
            -Description 'Uptime Loom background logger' -WindowStyle 7
    } catch {
        # Shortcuts can't be created on some locked-down PCs; a small batch
        # file in the Startup folder does the same job.
        "@echo off`r`nstart `"`" /min `"$WinPS`" $(Get-LaunchArgs 'Heartbeat.ps1')`r`n" |
            Out-File -LiteralPath $StartupCmd -Encoding ASCII
    }
    Ok "Logging will start automatically every time you sign in."

    # 5. Shortcuts: dashboard + "Going out" (Desktop and Start menu).
    $dashboard = Join-Path $AppDir 'dashboard.html'
    $lockIcon  = "$env:SystemRoot\System32\shell32.dll,44"
    $shortcutsOk = $true
    Remove-IfExists @($DashLnk, $DashUrl, $GoOutLnk, $GoOutCmd, $MenuDashLnk, $MenuGoOutLnk)
    try {
        New-Shortcut -Path $DashLnk     -Target $dashboard -Description 'Open the Uptime Loom dashboard'
        New-Shortcut -Path $MenuDashLnk -Target $dashboard -Description 'Open the Uptime Loom dashboard'
        New-Shortcut -Path $GoOutLnk    -Target $WinPS -Arguments (Get-LaunchArgs 'GoingOut.ps1') -WindowStyle 7 `
            -Icon $lockIcon -Hotkey 'CTRL+ALT+G' -Description "Lock the PC and stop counting until you're back (e.g. going off campus)"
        New-Shortcut -Path $MenuGoOutLnk -Target $WinPS -Arguments (Get-LaunchArgs 'GoingOut.ps1') -WindowStyle 7 `
            -Icon $lockIcon -Description "Lock the PC and stop counting until you're back (e.g. going off campus)"
    } catch {
        $shortcutsOk = $false
        Remove-IfExists @($DashLnk, $GoOutLnk, $MenuDashLnk, $MenuGoOutLnk)
        "[InternetShortcut]`r`nURL=file:///$($dashboard -replace '\\','/')`r`n" | Out-File -LiteralPath $DashUrl -Encoding ASCII
        "@echo off`r`nstart `"`" /min `"$WinPS`" $(Get-LaunchArgs 'GoingOut.ps1')`r`n" | Out-File -LiteralPath $GoOutCmd -Encoding ASCII
    }
    if ($shortcutsOk) {
        Ok "Added 'Uptime Loom' and 'Uptime Loom - Going out' to your Desktop and Start menu."
    } else {
        Ok "Added 'Uptime Loom' and 'Uptime Loom - Going out' to your Desktop."
        Warn "This PC doesn't allow keyboard shortcuts for them, so Ctrl+Alt+G won't work -- use the Desktop icon."
    }

    # 6. Start logging right now and check that it actually works.
    $csv = Join-Path $AppDir 'heartbeat_log.csv'
    $before = $null
    if (Test-Path -LiteralPath $csv) { $before = (Get-Item -LiteralPath $csv).LastWriteTimeUtc }
    Start-Heartbeat
    $working = $false
    for ($i = 0; $i -lt 30 -and -not $working; $i++) {
        Start-Sleep -Milliseconds 500
        if (Test-Path -LiteralPath $csv) {
            $after = (Get-Item -LiteralPath $csv).LastWriteTimeUtc
            if ($null -eq $before -or $after -gt $before) { $working = $true }
        }
    }
    if ($working) {
        Ok "Logging is running now."
    } else {
        Fail "The logger didn't start. Please send install-log.txt from $AppDir to whoever set this up."
    }
    if ($mode -ne 'FullLanguage') {
        Warn "This PC restricts PowerShell ($mode). Tracking works; lock detection uses a simpler check."
    }

    # 7. Open the dashboard, with the folder path ready to paste.
    try { Set-Clipboard -Value $AppDir } catch { }
    try { Start-Process -FilePath $dashboard } catch { }
    Write-Host ""
    Write-Host "  All done." -ForegroundColor Cyan
    Write-Host ""
    Say "The dashboard is opening in your browser. Click 'Load folder' and choose:"
    Say "  $AppDir"
    Say "(That path is already copied -- paste it into the folder box with Ctrl+V.)"
    Write-Host ""
    Say "Locking your PC (Win+L) for a class or meeting still counts as work time."
    Say "Going off campus? Use 'Uptime Loom - Going out' (Ctrl+Alt+G) instead."
    Say "To remove Uptime Loom later, run Uninstall.cmd in $AppDir"
} catch {
    Write-Host ""
    Fail "Setup failed: $($_.Exception.Message)"
    Say  "Please send install-log.txt from $AppDir to whoever set this up."
    exit 1
} finally {
    if ($transcript) { try { Stop-Transcript | Out-Null } catch { } }
}
