# SetupHeartbeat.ps1
# Run this ONCE as your normal user -- no admin rights needed.
# Right-click -> "Run with PowerShell", or from a normal (non-admin)
# PowerShell prompt: .\SetupHeartbeat.ps1

$ErrorActionPreference = 'Stop'

# Resolve files relative to this script, not the current directory, so setup
# works no matter where it's launched from.
$SourceDir   = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
$LogFolder   = "$env:USERPROFILE\UptimeLoom"
$ScriptPath  = "$LogFolder\Heartbeat.ps1"
$StartupDir  = [Environment]::GetFolderPath('Startup')
$ShortcutPath = "$StartupDir\UptimeLoom.lnk"

function Exit-WithPause([int]$code) {
    # "Run with PowerShell" closes the window immediately; keep it open so
    # the output can actually be read.
    if ($Host.Name -eq 'ConsoleHost') {
        Write-Host ""
        Read-Host "Press Enter to close" | Out-Null
    }
    exit $code
}

try {
    $SourceScript = Join-Path $SourceDir 'Heartbeat.ps1'
    if (-not (Test-Path $SourceScript)) {
        Write-Host "Couldn't find Heartbeat.ps1 next to this setup script ($SourceDir)." -ForegroundColor Red
        Write-Host "Keep Heartbeat.ps1, SetupHeartbeat.ps1 and dashboard.html together in one folder and try again."
        Exit-WithPause 1
    }

    # 1. Make sure the folder exists and copy the heartbeat script there
    if (-not (Test-Path $LogFolder)) {
        New-Item -ItemType Directory -Path $LogFolder | Out-Null
    }
    $sameFolder = (Resolve-Path $SourceDir).Path.TrimEnd('\') -ieq (Resolve-Path $LogFolder).Path.TrimEnd('\')
    if (-not $sameFolder) {
        Copy-Item -Path $SourceScript -Destination $ScriptPath -Force
    }

    # 2. Copy the dashboard next to it too, for convenience
    $SourceDashboard = Join-Path $SourceDir 'dashboard.html'
    if ((Test-Path $SourceDashboard) -and -not $sameFolder) {
        Copy-Item -Path $SourceDashboard -Destination "$LogFolder\dashboard.html" -Force
    }

    # Copies keep the downloaded file's "Mark of the Web"; clear it on the
    # installed copies (you've already chosen to run this setup).
    foreach ($f in @($ScriptPath, "$LogFolder\dashboard.html")) {
        if (Test-Path $f) { Unblock-File -Path $f -ErrorAction SilentlyContinue }
    }

    # 3. Create a shortcut in the Startup folder that runs the script hidden,
    #    with no console window popping up.
    $WScriptShell = New-Object -ComObject WScript.Shell
    $Shortcut = $WScriptShell.CreateShortcut($ShortcutPath)
    $Shortcut.TargetPath = "powershell.exe"
    $Shortcut.Arguments  = "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$ScriptPath`""
    $Shortcut.WorkingDirectory = $LogFolder
    $Shortcut.WindowStyle = 7   # 7 = minimized/hidden
    $Shortcut.Description = "Uptime Loom Heartbeat Logger"
    $Shortcut.Save()
} catch {
    Write-Host "Setup failed: $($_.Exception.Message)" -ForegroundColor Red
    Exit-WithPause 1
}

$StartArgs = "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$ScriptPath`""

Write-Host "Setup complete! No admin rights were used."
Write-Host ""
Write-Host "A shortcut was added to your Startup folder:"
Write-Host "  $ShortcutPath"
Write-Host "It will silently start logging heartbeats every time you log in."
Write-Host ""
Write-Host "Heartbeats will be saved to:"
Write-Host "  $LogFolder\heartbeat_log.csv"
Write-Host ""

# Offer to start logging right away. Starting it twice is harmless -- the
# heartbeat script exits if another copy is already running.
$startNow = $false
if ($Host.Name -eq 'ConsoleHost') {
    $answer = Read-Host "Start logging now without logging off? [Y/n]"
    $startNow = ($answer -eq '' -or $answer -match '^(y|yes)$')
}
if ($startNow) {
    Start-Process powershell.exe -ArgumentList $StartArgs -WorkingDirectory $LogFolder
    Write-Host "Logging started."
} else {
    Write-Host "To start logging right now WITHOUT restarting, run:"
    Write-Host "  Start-Process powershell.exe -ArgumentList '$StartArgs'"
}
Write-Host ""
Write-Host "To remove it later: delete the shortcut at"
Write-Host "  $ShortcutPath"

Exit-WithPause 0
