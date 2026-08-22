# Heartbeat.ps1
# Runs quietly in the background from logon until you shut down/log off.
# Appends a timestamp to the log every minute (a "heartbeat"). When the PC
# turns off, or the screen is locked, heartbeats simply stop -- the last one
# recorded is treated as the moment that session ended (accurate to within
# ~1 minute). This means locking your screen to step away automatically
# excludes that time, with no button to press.
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

$LogFolder = "$env:USERPROFILE\UptimeLoom"
$LogFile   = "$LogFolder\heartbeat_log.csv"

if (-not (Test-Path $LogFolder)) {
    New-Item -ItemType Directory -Path $LogFolder | Out-Null
}
if (-not (Test-Path $LogFile)) {
    "Timestamp" | Out-File -FilePath $LogFile -Encoding UTF8
}

# --- Lock-state detection ---
# Checks whether the current session's input desktop is the "Winlogon"
# desktop, which is only active while the workstation is locked. This is
# the same signal Windows itself uses internally; it requires no special
# privileges and works entirely within the current user's session.
Add-Type @"
using System;
using System.Runtime.InteropServices;

public class SessionState {
    [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Auto)]
    public static extern IntPtr OpenInputDesktop(uint dwFlags, bool fInherit, uint dwDesiredAccess);

    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool CloseDesktop(IntPtr hDesktop);

    public static bool IsLocked() {
        IntPtr h = OpenInputDesktop(0, false, 0x0100); // GENERIC_READ-ish access
        if (h == IntPtr.Zero) {
            // Access denied to the input desktop means we're on a secure
            // desktop (lock screen, UAC prompt, Ctrl+Alt+Del screen, etc.)
            return true;
        }
        CloseDesktop(h);
        return false;
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

$lastWrite = Get-Date "1970-01-01"

while ($true) {
    try {
        $now = Get-Date
        if (($now - $lastWrite).TotalSeconds -ge 60) {
            if (-not (Test-WorkstationLocked)) {
                $timestamp = $now.ToString("yyyy-MM-dd HH:mm:ss")
                Add-Content -Path $LogFile -Value $timestamp -Encoding UTF8
                $lastWrite = $now
            }
            # If locked, we simply skip the write -- the gap this creates
            # is picked up by the dashboard exactly like a shutdown gap.
        }
    } catch {
        # Swallow transient errors (e.g. file briefly locked) and keep looping.
    }
    Start-Sleep -Seconds 5
}
