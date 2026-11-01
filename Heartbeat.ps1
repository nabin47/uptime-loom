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
# Checking lock detection on your PC:
#   powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\UptimeLoom\Heartbeat.ps1" -Diagnose
# then press Win+L, wait ~30 seconds, unlock, and read the window (or
# lock_diagnose.txt in the UptimeLoom folder). Lines written while locked
# should say "final=LOCKED".
#
# Resilience notes:
# - Uses a short sleep loop (5s ticks) instead of one long Start-Sleep, so a
#   sleep/wake cycle can't stall it for a full 60s+ or leave it stuck.
# - Wraps the write in try/catch so a transient file-lock or I/O hiccup
#   doesn't kill the whole background process.
# - The 60s interval is measured in UTC, so a daylight-saving change (local
#   clock jumping back an hour) can't pause logging for an hour.
# - A per-user mutex ensures only one copy runs, even if it's started both
#   from the Startup shortcut and by hand.

param(
    # Print what each lock-detection method reports every 5 seconds for 90
    # seconds, instead of logging heartbeats.
    [switch]$Diagnose
)

$LogFolder = "$env:USERPROFILE\UptimeLoom"
$LogFile   = "$LogFolder\heartbeat_log.csv"
$AwayFlag  = "$LogFolder\away.flag"

if (-not (Test-Path $LogFolder)) {
    New-Item -ItemType Directory -Path $LogFolder | Out-Null
}

# --- Lock-state detection ---
# 1. Primary: ask Windows directly via WTSQuerySessionInformation
#    (WTSSessionInfoEx -> SessionFlags). This is the documented way to read
#    the session's lock state; it flips to "locked" the moment you press
#    Win+L, needs no special privileges, and only looks at your own session.
#
# 2. Fallbacks, used only if (1) can't give an answer:
#    - LogonUI.exe running in your session (it hosts the lock/sign-in UI).
#    - The input desktop can't be opened/switched to (secure desktop).
#
# Note: (2b) on its own is NOT enough on Windows 10/11 -- the lock screen
# "curtain" (picture + clock) runs on your normal desktop, so that check
# only notices the lock once the password box is showing.
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

public static class UptimeLoomLock {
    [DllImport("wtsapi32.dll", SetLastError = true)]
    static extern bool WTSQuerySessionInformationW(IntPtr hServer, int sessionId, int infoClass, out IntPtr buffer, out int bytesReturned);

    [DllImport("wtsapi32.dll")]
    static extern void WTSFreeMemory(IntPtr memory);

    [DllImport("kernel32.dll")]
    static extern uint GetCurrentProcessId();

    [DllImport("kernel32.dll")]
    static extern bool ProcessIdToSessionId(uint processId, out uint sessionId);

    [DllImport("user32.dll", SetLastError = true)]
    static extern IntPtr OpenInputDesktop(uint dwFlags, bool fInherit, uint dwDesiredAccess);

    [DllImport("user32.dll", SetLastError = true)]
    static extern bool SwitchDesktop(IntPtr hDesktop);

    [DllImport("user32.dll", SetLastError = true)]
    static extern bool CloseDesktop(IntPtr hDesktop);

    const int WTS_CURRENT_SESSION = -1;
    const int WTSSessionInfoEx = 25;
    const uint DESKTOP_SWITCHDESKTOP = 0x0100;

    // 1 = locked, 0 = unlocked, -1 = unknown
    public static int WtsLockState() {
        IntPtr buf;
        int bytes;
        if (!WTSQuerySessionInformationW(IntPtr.Zero, WTS_CURRENT_SESSION, WTSSessionInfoEx, out buf, out bytes)) {
            return -1;
        }
        try {
            // WTSINFOEX { DWORD Level; <4 bytes padding>; WTSINFOEX_LEVEL1 Data }
            // WTSINFOEX_LEVEL1 { ULONG SessionId; WTS_CONNECTSTATE_CLASS SessionState; LONG SessionFlags; ... }
            if (buf == IntPtr.Zero || bytes < 20) return -1;
            if (Marshal.ReadInt32(buf, 0) != 1) return -1;
            // Sanity check: the record must be for our own session. If the
            // layout were ever different, this fails and we fall back to the
            // other checks instead of misreading a field.
            uint mySession;
            if (!ProcessIdToSessionId(GetCurrentProcessId(), out mySession)) return -1;
            if ((uint)Marshal.ReadInt32(buf, 8) != mySession) return -1;
            int flags = Marshal.ReadInt32(buf, 16);
            // On Windows 7 / Server 2008 R2 the two values are swapped.
            bool swapped = Environment.OSVersion.Version < new Version(6, 2);
            if (flags == 0) return swapped ? 0 : 1;   // WTS_SESSIONSTATE_LOCK
            if (flags == 1) return swapped ? 1 : 0;   // WTS_SESSIONSTATE_UNLOCK
            return -1;                                // WTS_SESSIONSTATE_UNKNOWN
        } finally {
            WTSFreeMemory(buf);
        }
    }

    public static bool InputDesktopLocked() {
        IntPtr h = OpenInputDesktop(0, false, DESKTOP_SWITCHDESKTOP);
        if (h == IntPtr.Zero) return true;
        try {
            return !SwitchDesktop(h);
        } finally {
            CloseDesktop(h);
        }
    }
}
"@ -ErrorAction SilentlyContinue

$MySessionId = (Get-Process -Id $PID).SessionId

function Get-LockSignals {
    $wts = -1
    try { $wts = [UptimeLoomLock]::WtsLockState() } catch { $wts = -1 }

    $logonUI = $false
    try {
        $logonUI = [bool](Get-Process -Name LogonUI -ErrorAction SilentlyContinue |
            Where-Object { $_.SessionId -eq $MySessionId })
    } catch { }

    $desktop = $false
    try { $desktop = [UptimeLoomLock]::InputDesktopLocked() } catch { }

    if ($wts -ne -1) {
        # Windows answered directly -- trust it. (This also avoids counting a
        # UAC prompt, which uses a secure desktop, as "locked".)
        $locked = ($wts -eq 1)
    } else {
        $locked = $logonUI -or $desktop
    }
    [pscustomobject]@{ Wts = $wts; LogonUI = $logonUI; InputDesktop = $desktop; Locked = $locked }
}

function Test-WorkstationLocked {
    try {
        return (Get-LockSignals).Locked
    } catch {
        # If the check itself fails for any reason, fail open (assume
        # unlocked) so a detection bug never silently stops all logging.
        return $false
    }
}

# --- Diagnose mode ---
if ($Diagnose) {
    $out = "$LogFolder\lock_diagnose.txt"
    $typeLoaded = [bool]('UptimeLoomLock' -as [type])
    $header = "Uptime Loom lock diagnostics -- $(Get-Date) -- Windows $([Environment]::OSVersion.Version) -- session $MySessionId -- detector loaded: $typeLoaded"
    $header | Out-File -FilePath $out -Encoding UTF8
    Write-Host $header
    Write-Host "Press Win+L now, wait ~30 seconds, then unlock. Running for 90 seconds..."
    $end = (Get-Date).AddSeconds(90)
    while ((Get-Date) -lt $end) {
        $s = Get-LockSignals
        $wtsText = switch ($s.Wts) { 1 { 'locked' } 0 { 'unlocked' } default { 'unknown' } }
        $line = "{0}  wts={1,-8} logonui={2,-5} inputdesktop={3,-5} final={4}" -f (Get-Date).ToString('HH:mm:ss'), $wtsText, $s.LogonUI, $s.InputDesktop, $(if ($s.Locked) { 'LOCKED' } else { 'active' })
        Add-Content -Path $out -Value $line -Encoding UTF8
        Write-Host $line
        Start-Sleep -Seconds 5
    }
    Write-Host ""
    Write-Host "Saved to $out"
    Read-Host "Press Enter to close" | Out-Null
    exit
}

# --- Single instance ---
$createdNew = $false
$script:InstanceMutex = New-Object System.Threading.Mutex($true, "Local\UptimeLoomHeartbeat", [ref]$createdNew)
if (-not $createdNew) {
    # Another heartbeat logger is already running in this session.
    exit
}

if (-not (Test-Path $LogFile)) {
    "Timestamp,State" | Out-File -FilePath $LogFile -Encoding UTF8
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
