# Heartbeat.ps1
# Runs quietly in the background from logon until you shut down/log off.
# Appends a timestamp to the log every minute (a "heartbeat"), tagged with
# whether the workstation was unlocked ("active") or locked ("locked").
# When the PC turns off or sleeps, heartbeats simply stop -- the last one
# recorded is treated as the moment that session ended (accurate to within
# ~1 minute).
#
# Locking the screen does NOT stop the clock by itself: a class or meeting
# you lock your PC for still counts, as long as you come back and unlock it
# (the dashboard decides how much locked time to count). To mark that you
# are leaving -- e.g. going off campus -- run the "Uptime Loom - Going out"
# shortcut (Ctrl+Alt+G). It locks the PC and creates away.flag; while that
# flag exists and the PC is locked, no heartbeats are written, so the time
# is excluded exactly like a shutdown. Unlocking again clears the flag.
#
# No admin rights needed anywhere in this script.
#
# Resilience notes:
# - Uses a short sleep loop (5s ticks) instead of one long Start-Sleep, so a
#   sleep/wake cycle can't stall it for a full 60s+ or leave it stuck.
# - Wraps the write in try/catch so a transient file-lock or I/O hiccup
#   doesn't kill the whole background process.
# - Lock detection uses a standard Win32 API call (no admin rights, no
#   external modules) to check whether the workstation is currently locked.
# - The 60s interval is measured in UTC, so a daylight-saving change (local
#   clock jumping back an hour) can't pause logging for an hour.
# - A per-user mutex ensures only one copy runs, even if it's started both
#   from the Startup shortcut and by hand.

# --- Single instance ---
$createdNew = $false
$script:InstanceMutex = New-Object System.Threading.Mutex($true, "Local\UptimeLoomHeartbeat", [ref]$createdNew)
if (-not $createdNew) {
    # Another heartbeat logger is already running in this session.
    exit
}

$LogFolder = "$env:USERPROFILE\UptimeLoom"
$LogFile   = "$LogFolder\heartbeat_log.csv"

if (-not (Test-Path $LogFolder)) {
    New-Item -ItemType Directory -Path $LogFolder | Out-Null
}
$AwayFlag  = "$LogFolder\away.flag"

if (-not (Test-Path $LogFile)) {
    "Timestamp,State" | Out-File -FilePath $LogFile -Encoding UTF8
}

# --- Lock-state detection ---
# Checks whether the current session's input desktop is the "Winlogon"
# desktop, which is only active while the workstation is locked. We try to
# open the input desktop and then switch to it: when the user's own desktop
# is active this is a harmless no-op that succeeds; while the lock screen
# (a secure desktop) is active, either the open or the switch fails. This
# requires no special privileges and works entirely within the current
# user's session.
Add-Type @"
using System;
using System.Runtime.InteropServices;

public class SessionState {
    [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Auto)]
    public static extern IntPtr OpenInputDesktop(uint dwFlags, bool fInherit, uint dwDesiredAccess);

    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool SwitchDesktop(IntPtr hDesktop);

    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool CloseDesktop(IntPtr hDesktop);

    private const uint DESKTOP_SWITCHDESKTOP = 0x0100;

    public static bool IsLocked() {
        IntPtr h = OpenInputDesktop(0, false, DESKTOP_SWITCHDESKTOP);
        if (h == IntPtr.Zero) {
            // Access denied to the input desktop means we're on a secure
            // desktop (lock screen, UAC prompt, Ctrl+Alt+Del screen, etc.)
            return true;
        }
        try {
            // Opening can succeed on some builds even while locked;
            // switching to the input desktop cannot.
            return !SwitchDesktop(h);
        } finally {
            CloseDesktop(h);
        }
    }
}
"@ -ErrorAction SilentlyContinue

function Test-WorkstationLocked {
    try {
        return [SessionState]::IsLocked()
    } catch {
        # If the check itself fails for any reason, fail open (assume
        # unlocked) so a detection bug never silently stops all logging.
        return $false
    }
}

# Interval bookkeeping uses UTC so DST changes don't affect it; the value
# written to the log stays local wall-clock time, as the dashboard expects.
$lastWriteUtc = [DateTime]::MinValue

while ($true) {
    try {
        $nowUtc  = [DateTime]::UtcNow
        $elapsed = ($nowUtc - $lastWriteUtc).TotalSeconds
        # A negative value means the system clock was set backwards; treat
        # that as "due" rather than waiting for the clock to catch up.
        if ($elapsed -ge 60 -or $elapsed -lt 0) {
            $locked = Test-WorkstationLocked
            $away   = Test-Path $AwayFlag
            if ($away -and -not $locked) {
                # You're back at the PC: end the "away" period. A short grace
                # period avoids clearing a flag created a moment before the
                # lock screen actually appeared.
                $flagAge = ($nowUtc - (Get-Item $AwayFlag).LastWriteTimeUtc).TotalSeconds
                if ($flagAge -gt 20 -or $flagAge -lt 0) {
                    Remove-Item $AwayFlag -Force -ErrorAction SilentlyContinue
                    $away = $false
                }
            }
            if ($away) {
                # Marked as away: skip the write. The gap this creates is
                # picked up by the dashboard exactly like a shutdown gap.
            } else {
                $state     = if ($locked) { 'locked' } else { 'active' }
                $timestamp = $nowUtc.ToLocalTime().ToString("yyyy-MM-dd HH:mm:ss")
                Add-Content -Path $LogFile -Value "$timestamp,$state" -Encoding UTF8
                $lastWriteUtc = $nowUtc
            }
        }
    } catch {
        # Swallow transient errors (e.g. file briefly locked) and keep looping.
    }
    Start-Sleep -Seconds 5
}
