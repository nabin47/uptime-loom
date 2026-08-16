# Heartbeat.ps1
# Runs quietly in the background from logon until you shut down/log off.
# Appends a timestamp to the log every minute (a "heartbeat"). When the PC
# turns off, the heartbeats simply stop -- the last one recorded is treated
# as the moment you turned it off (accurate to within ~1 minute).
#
# No admin rights needed anywhere in this script.
#
# Resilience notes:
# - Uses a short sleep loop (5s ticks) instead of one long Start-Sleep, so a
#   sleep/wake cycle can't stall it for a full 60s+ or leave it stuck.
# - Wraps the write in try/catch so a transient file-lock or I/O hiccup
#   doesn't kill the whole background process.

$LogFolder = "$env:USERPROFILE\UptimeLoom"
$LogFile   = "$LogFolder\heartbeat_log.csv"

if (-not (Test-Path $LogFolder)) {
    New-Item -ItemType Directory -Path $LogFolder | Out-Null
}
if (-not (Test-Path $LogFile)) {
    "Timestamp" | Out-File -FilePath $LogFile -Encoding UTF8
}

$lastWrite = Get-Date "1970-01-01"

while ($true) {
    try {
        $now = Get-Date
        if (($now - $lastWrite).TotalSeconds -ge 60) {
            $timestamp = $now.ToString("yyyy-MM-dd HH:mm:ss")
            Add-Content -Path $LogFile -Value $timestamp -Encoding UTF8
            $lastWrite = $now
        }
    } catch {
        # Swallow transient errors (e.g. file briefly locked) and keep looping.
    }
    Start-Sleep -Seconds 5
}
