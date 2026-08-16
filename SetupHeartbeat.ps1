# SetupHeartbeat.ps1
# Run this ONCE as your normal user -- no admin rights needed.
# Right-click -> "Run with PowerShell", or from a normal (non-admin)
# PowerShell prompt: .\SetupHeartbeat.ps1

$LogFolder   = "$env:USERPROFILE\UptimeLoom"
$ScriptPath  = "$LogFolder\Heartbeat.ps1"
$StartupDir  = [Environment]::GetFolderPath('Startup')
$ShortcutPath = "$StartupDir\UptimeLoom.lnk"

# 1. Make sure the folder exists and copy the heartbeat script there
if (-not (Test-Path $LogFolder)) {
    New-Item -ItemType Directory -Path $LogFolder | Out-Null
}
Copy-Item -Path ".\Heartbeat.ps1" -Destination $ScriptPath -Force

# 2. Copy the dashboard next to it too, for convenience
if (Test-Path ".\dashboard.html") {
    Copy-Item -Path ".\dashboard.html" -Destination "$LogFolder\dashboard.html" -Force
}

# 3. Create a shortcut in the Startup folder that runs the script hidden,
#    with no console window popping up.
$WScriptShell = New-Object -ComObject WScript.Shell
$Shortcut = $WScriptShell.CreateShortcut($ShortcutPath)
$Shortcut.TargetPath = "powershell.exe"
$Shortcut.Arguments  = "-WindowStyle Hidden -ExecutionPolicy Bypass -File `"$ScriptPath`""
$Shortcut.WorkingDirectory = $LogFolder
$Shortcut.WindowStyle = 7   # 7 = minimized/hidden
$Shortcut.Description = "Uptime Loom Heartbeat Logger"
$Shortcut.Save()

Write-Host "Setup complete! No admin rights were used."
Write-Host ""
Write-Host "A shortcut was added to your Startup folder:"
Write-Host "  $ShortcutPath"
Write-Host "It will silently start logging heartbeats the next time you log in."
Write-Host ""
Write-Host "To start logging right now WITHOUT restarting, run:"
Write-Host "  Start-Process powershell.exe -ArgumentList '-WindowStyle Hidden -ExecutionPolicy Bypass -File `"$ScriptPath`"'"
Write-Host ""
Write-Host "Heartbeats will be saved to:"
Write-Host "  $LogFolder\heartbeat_log.csv"
Write-Host ""
Write-Host "To remove it later: delete the shortcut at"
Write-Host "  $ShortcutPath"
