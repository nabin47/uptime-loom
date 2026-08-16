# Uptime Loom

A zero-click, no-admin-required time tracker for Windows 11. It automatically
logs when your PC is on, and gives you a local analytics dashboard to see
patterns in your work hours — arrival/departure trends, daily totals, a
GitHub-style activity heatmap, and more.

No accounts, no cloud, no installs. Your data never leaves your machine.

![status](https://img.shields.io/badge/platform-Windows%2011-0078D6)
![admin](https://img.shields.io/badge/admin%20rights-not%20required-brightgreen)

---

## How it works

A small PowerShell script (`Heartbeat.ps1`) starts automatically when you log
in to Windows. Every 60 seconds, it appends a timestamp to a CSV file. When
you shut down or log off, the process simply stops — there's nothing to
detect, no shutdown hook required. The **last timestamp before a gap** is
treated as the moment you turned your PC off.

The dashboard (`dashboard.html`) is a single self-contained HTML file that
reads that CSV and reconstructs your work sessions, then renders stats and
charts. It runs entirely in your browser — nothing is uploaded anywhere.

```
Login  ──▶  Heartbeat.ps1 starts (via Startup folder shortcut)
              │
              ▼
     writes a timestamp every 60s to heartbeat_log.csv
              │
              ▼
Shutdown ──▶ process stops, heartbeats stop
              │
              ▼
      open dashboard.html ──▶ load the CSV ──▶ see your stats
```

---

## Features

- **Fully automatic** — no clock-in/clock-out button to forget
- **Live auto-sync in Chrome/Edge** — load the CSV once, the dashboard
  silently keeps itself current from then on
- **No admin rights needed anywhere** — uses the Startup folder, not Task
  Scheduler or Group Policy
- **Local-only data** — a single CSV file on your own disk
- **Dashboard includes:**
  - Live "today" timer
  - This week's total hours, with week-over-week trend
  - Average arrival time and a consistency score
  - Current day streak
  - 30-day daily hours trend with 7-day rolling average
  - Average hours by day of week
  - Arrival/departure time chart for recent sessions
  - GitHub-style activity heatmap
  - Auto-generated plain-language insights (busiest day, weekend work
    detected, etc.)
  - Full session log
  - Light and dark mode

---

## Installation

1. **Download** the files in this repo and put them together in one
   folder — anywhere is fine, e.g. `Downloads\uptime-loom\`:
   - `Heartbeat.ps1`
   - `SetupHeartbeat.ps1`
   - `dashboard.html`

2. **Unblock the scripts.** Windows tags downloaded files with a "Mark of
   the Web" flag that can prevent them from running even after the setup
   below. Right-click each `.ps1` file → **Properties** → check **Unblock**
   at the bottom → OK. (Or see the [PowerShell alternative](#unblock-files)
   below.)

   > Before unblocking anything you download from the internet — this
   > repo included — you should read through the script yourself. Both
   > files here are short and plain PowerShell; there's nothing to hide.

3. **Run the setup script.** Right-click `SetupHeartbeat.ps1` → **Run with
   PowerShell**. No "Run as administrator" needed — a normal click is fine.

   This will:
   - Create `C:\Users\<you>\UptimeLoom\`
   - Copy `Heartbeat.ps1` and the dashboard into that folder
   - Add a shortcut to your Startup folder so logging begins automatically
     on every future login

4. **Done.** From your next login onward, it just works. To start logging
   immediately without restarting, the setup script prints a one-line
   command you can paste to start it right away.

---

## Using the dashboard

Open `dashboard.html` (found in `C:\Users\<you>\UptimeLoom\`) in any
browser. Click **Load CSV** and select `heartbeat_log.csv` from the same
folder.

**In Chrome or Edge**, the dashboard uses the File System Access API to
keep itself in sync automatically — after you load the file once, it
silently re-reads it every 15 seconds with no further clicks. You'll see
"last synced" update in the header. This permission is granted per browser
session; you'll need to click **Load CSV** again if you close and reopen
the tab.

**In Firefox or other browsers** that don't support this API, the
dashboard falls back to manual refresh — click **Refresh** any time you
want current data.

---

## Troubleshooting

### "Running scripts is disabled on this system"

You'll see this if you try to run the script directly and PowerShell's
execution policy blocks it:

```
File ...\Heartbeat.ps1 cannot be loaded because running scripts is
disabled on this system.
```

Check what's set:

```powershell
Get-ExecutionPolicy -List
```

- If `MachinePolicy` or `UserPolicy` show anything other than `Undefined`,
  your policy is locked by Group Policy (common on managed/work machines) —
  you'll need an administrator to change it.
- If those two are `Undefined`, you can fix it yourself, no admin needed:

  ```powershell
  Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
  ```

  This only affects your own user account. It allows locally-written
  scripts to run while still blocking unsigned scripts from the internet —
  a reasonable, commonly-used default.

### "The file ... is not digitally signed"

Even after fixing the execution policy, downloaded files carry a separate
"Mark of the Web" tag that `RemoteSigned` respects. Check for it:

```powershell
Get-Item "$env:USERPROFILE\UptimeLoom\Heartbeat.ps1" -Stream Zone.Identifier
```

If that returns something instead of an error, unblock the file:

<a name="unblock-files"></a>
```powershell
Unblock-File "$env:USERPROFILE\UptimeLoom\Heartbeat.ps1"
Unblock-File "$env:USERPROFILE\UptimeLoom\SetupHeartbeat.ps1"
```

Only do this after you've actually read the script — that's what the flag
is there to make you stop and consider.

### Dashboard shows "off" even though the PC is on

If you're in Chrome/Edge with live sync active, wait up to 15 seconds for
the next automatic sync, or click **Sync now**. If you're on a browser
without live sync (e.g. Firefox), click **Refresh** and re-select
`heartbeat_log.csv` to pull the latest data.

### No new heartbeats are being written / logging seems stuck

First check whether the process is actually running:

```powershell
Get-Process powershell -ErrorAction SilentlyContinue
Get-Content "$env:USERPROFILE\UptimeLoom\heartbeat_log.csv" -Tail 5
```

If the process is running but the last timestamp is old (more than a couple
of minutes stale), the loop has likely stalled — this can happen if the PC
goes to sleep while the script is running, and the process gets suspended
mid-cycle rather than cleanly stopped. Restart it:

```powershell
# find the PID from Get-Process above, then:
Stop-Process -Id <PID> -Force
Start-Process powershell.exe -ArgumentList '-WindowStyle Hidden -ExecutionPolicy Bypass -File "C:\Users\<you>\UptimeLoom\Heartbeat.ps1"'
```

The version of `Heartbeat.ps1` in this repo already includes a fix for this
(it checks wall-clock time in short 5-second ticks instead of one long
60-second sleep, so a sleep/wake cycle can't stall it as easily) — if
you're still hitting this often, it may be worth checking your power plan's
sleep settings, since a script can't write to disk while the PC itself is
actually asleep.

### Startup shortcut isn't firing at all

Confirm it exists:

```powershell
Test-Path "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\UptimeLoom.lnk"
```

If `False`, re-run `SetupHeartbeat.ps1`. If `True` but it's still not
starting, check what it's actually pointing to:

```powershell
$s = (New-Object -ComObject WScript.Shell).CreateShortcut("$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\UptimeLoom.lnk")
$s.TargetPath
$s.Arguments
```

It should show `powershell.exe` and arguments pointing only at
`Heartbeat.ps1` inside your `UptimeLoom` folder.

---

## Data format

`heartbeat_log.csv` is a single-column CSV:

```
Timestamp
2026-08-16 09:03:12
2026-08-16 09:04:12
2026-08-16 09:05:12
...
```

The dashboard reconstructs sessions by finding gaps larger than 3 minutes
between consecutive timestamps — a gap means the PC was off in between.
This format is intentionally simple so you can also open it in Excel or
process it yourself (Python/pandas, etc.) if you want custom analysis.

---

## Privacy

Everything stays local:
- The heartbeat script only writes to a file on your own disk
- The dashboard is a static HTML file — it makes no network requests
- No telemetry, no accounts, no external services

---

## Limitations

- Tracks **login-to-shutdown** time, not active/idle time — a locked or
  idle screen still counts as "on"
- Timestamp resolution is ~1 minute, so session boundaries are accurate to
  within about a minute, not to the second
- Windows-only (uses PowerShell and the Windows Startup folder)
- The dashboard is Windows-only in the sense that it's built around this
  Windows-specific logging setup; the HTML file itself works in any
  browser, but live auto-sync (File System Access API) is Chromium-only
  (Chrome, Edge, Opera) — Firefox and Safari fall back to manual refresh

---

## License

MIT — use, modify, and share freely.

---

<sub>© 2026 Jubair Ahmed Nabin. All rights reserved under the MIT License above.</sub>
