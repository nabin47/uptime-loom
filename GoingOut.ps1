# GoingOut.ps1
# One click when you leave (e.g. going off campus for work): locks the PC
# and marks you as away, so the time until you next unlock is NOT counted.
#
# Normal locking (Win+L) for a class or meeting still counts as office time;
# use this instead only when the time away shouldn't count.
#
# Setup creates a shortcut for this ("Uptime Loom - Going out") on your
# Desktop and in the Start menu, with the hotkey Ctrl+Alt+G.
# No admin rights needed.

$LogFolder = "$env:USERPROFILE\UptimeLoom"
$AwayFlag  = "$LogFolder\away.flag"

if (-not (Test-Path $LogFolder)) {
    New-Item -ItemType Directory -Path $LogFolder | Out-Null
}

# Lock first, then create the flag: Heartbeat.ps1 clears the flag whenever
# it sees the PC unlocked, so the flag must only appear once we're locked.
# If locking isn't possible (blocked by policy), the flag is cleared again
# on the next heartbeat and nothing changes -- it never silently stops
# tracking while you're still at the PC.
rundll32.exe user32.dll,LockWorkStation
Start-Sleep -Seconds 2
(Get-Date).ToString("yyyy-MM-dd HH:mm:ss") | Out-File -FilePath $AwayFlag -Encoding UTF8 -Force
