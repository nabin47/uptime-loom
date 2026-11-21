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
in to Windows. Every 60 seconds, it appends a timestamp to a CSV file, tagged
with whether the PC was unlocked (`active`) or locked (`locked`). When you
shut down or the PC sleeps, heartbeats simply stop. The **last timestamp
before a gap** is treated as the moment that session ended, and a new
session begins the next time a heartbeat is written.

### Locking the PC vs. actually leaving

**Locking your screen (`Win+L`) for a class, meeting or lunch still counts
as office time** — as long as you come back and unlock the PC afterwards.
Two safety rules keep this honest:

- **You have to come back.** A locked stretch only counts when it ends with
  you unlocking the PC. If you lock it and go home, and it later sleeps or
  just stays locked overnight, that locked time is dropped.
- **There's a cap.** A single locked stretch counts for at most **4 hours**
  (changeable in the dashboard, `0` = never count locked time). Longer than
  that is treated as time away.

**When you leave and the time should *not* count** — e.g. going off campus
for some work — use the **"Uptime Loom - Going out"** shortcut instead of
`Win+L` (on your Desktop and in the Start menu, or press **Ctrl+Alt+G**).
It locks the PC and marks you as away; nothing is logged until you unlock
again, so that time is excluded exactly like a shutdown.

Forgot to use the shortcut? Click **− Mark away** in the dashboard's session
log and enter the time range you were out — it's subtracted from your
totals.

The dashboard (`dashboard.html`) is a single self-contained HTML file that
reads that CSV and reconstructs your work sessions, then renders stats and
charts. It runs entirely in your browser — nothing is uploaded anywhere.

```
Login  ──▶  Heartbeat.ps1 starts (via Startup folder shortcut)
              │
              ▼
   writes "timestamp,active|locked" every 60s
              │
    ┌─────────┼──────────────────────┬──────────────────────┐
    ▼                                ▼                      ▼
Win+L (class/meeting)        Going out (Ctrl+Alt+G)   Shutdown/sleep
logged as "locked";          locks + marks away;      heartbeats stop
counts if you unlock         heartbeats stop          (not counted)
again (up to the cap)        until you unlock
              │
              ▼
      open dashboard.html ──▶ load the folder ──▶ see your stats
```

---

## Features

- **Fully automatic** — no clock-in/clock-out button to forget
- **Manual corrections** — edit, delete, or add sessions directly in the
  dashboard for the rare case the automatic tracking needs a fix or a note
- **Classes and meetings still count** — locking the PC (Win+L) doesn't
  stop the clock as long as you come back and unlock it (up to a 4h cap)
- **One-click "Going out"** — Ctrl+Alt+G locks the PC and excludes the time
  until you're back, for when you leave campus
- **Live auto-sync in Chrome/Edge** — load the CSV once, the dashboard
  silently keeps itself current from then on
- **No admin rights needed anywhere** — uses the Startup folder, not Task
  Scheduler or Group Policy
- **Local-only data** — a single CSV file on your own disk
- **Dashboard includes:**
  - Live "today" timer
  - This week's and this month's totals, each compared with the previous
    week/month at the same point
  - Average arrival and departure time (first in / last out each day) and
    a consistency score
  - Current day streak (your weekend days don't break it)
  - 30-day daily hours trend with 7-day rolling average
  - Weekly totals for the last 12 weeks against your weekly target
  - "When you work" — average minutes in each hour of the day
  - Average hours per day worked, by day of week
  - First-in / last-out chart for recent days
  - GitHub-style activity heatmap
  - Auto-generated plain-language insights (longest day, target hit rate,
    time spent in locked breaks such as classes, weekend work, etc.)
  - Session log grouped by day, filterable by period, with CSV export
  - Light and dark mode
- **Settings** — choose the first day of the week, which days are your
  weekend, a weekly hour target, and how long a locked break can count

---

## Installation

No administrator rights needed, and nothing to configure.

1. **Download** this repository as a ZIP (green **Code** button → **Download
   ZIP**), then right-click the ZIP → **Extract All…**.
2. Open the extracted folder and **double-click `Install.cmd`**.
   - If Windows shows *"Windows protected your PC"*, click **More info** →
     **Run anyway**. If it shows *"Open File – Security Warning"*, click
     **Run**. (This is Windows being careful about any file downloaded from
     the internet. Both files are short and readable, so look through
     them first if you like.)
3. That's it. The installer:
   - copies Uptime Loom to `C:\Users\<you>\UptimeLoom`
   - starts logging **right away** and checks that it's working
   - makes it start automatically every time you sign in
   - adds **Uptime Loom** (the dashboard) and **Uptime Loom - Going out**
     (hotkey **Ctrl+Alt+G**) to your Desktop and Start menu
   - opens the dashboard with the folder path already copied, so you just
     click **Load folder** and paste it with **Ctrl+V**

To **update**, download the new version and run `Install.cmd` again. Your
data and corrections are kept, and the new version takes over immediately.
You don't need to log off.

To **uninstall**, double-click `Uninstall.cmd` (also in
`C:\Users\<you>\UptimeLoom`). It stops logging and removes the shortcuts.
Your data stays in the folder until you delete it.

The installer works on locked-down work PCs too. It doesn't depend on
PowerShell's script execution policy, and where a step is blocked (for
example creating shortcuts) it uses a simpler alternative. If anything
still goes wrong, it says so and saves a log to
`C:\Users\<you>\UptimeLoom\install-log.txt`. Send that file to whoever is
helping you.

---

## Manual corrections

Automatic tracking gets it right almost all the time, but sometimes you
need to step in — you turned the PC off for an errand, or a session's
boundary is slightly off. The session log at the bottom of the dashboard
lets you:

- **Edit** any session's start/end time and attach a short note
- **Delete** a session that shouldn't count (e.g. a test run)
- **Add** a fully manual session for time that was never logged (e.g. the
  script wasn't running that day)
- **Mark away** a time range that shouldn't count (e.g. you went off campus
  but only locked the PC instead of using the Going out shortcut)

**In Chrome or Edge**, when you load your UptimeLoom folder, corrections
are saved to a `corrections.json` file in that same folder — right next to
`heartbeat_log.csv`. This means corrections are:

- Durable — they survive closing the tab, clearing browser data, or
  switching browsers, since they live on disk, not in the browser
- Portable — open the dashboard on a different machine pointed at the same
  folder (e.g. via a synced drive) and your corrections come with it
- Inspectable — it's plain JSON, readable in any text editor if you want
  to see exactly what's been changed

`heartbeat_log.csv` itself is **never modified** — corrections are always
a separate overlay applied on top when the dashboard renders, so your raw
heartbeat data stays intact as ground truth no matter how much you edit.

**In Firefox or other browsers** without File System Access API support,
corrections fall back to that browser's local storage instead — meaning
they're specific to that one browser and won't sync anywhere. If you're on
a browser like this and it matters to you, using Chrome or Edge for the
dashboard is worth it just for this reason.

---

## Using the dashboard

Open **Uptime Loom** from your Desktop or Start menu (it's
`C:\Users\<you>\UptimeLoom\dashboard.html`, which opens in your browser). The
first time, click **Load folder** and choose your `UptimeLoom` folder (the
one containing `heartbeat_log.csv`). Choosing your user folder above it
works too.

**In Chrome or Edge**, that's the only time you do this. The dashboard
remembers the folder and re-reads it every 15 seconds; "last synced" in the
header shows when. Next time you open it, it either loads straight away
(if you allowed access "on every visit") or shows a one-click
**Reconnect** button.

**In Firefox or other browsers** without folder access, drag
`heartbeat_log.csv` from the UptimeLoom folder onto the page (or use
**Load folder** to pick the file), and click **Refresh** when you want
newer data.

### Settings

Open **Settings** at the top of the dashboard to set:

- **Week starts on** — used for "This week", the weekly chart, the activity
  calendar's columns and the session log's week filters
- **Weekend days** — any combination (e.g. Friday + Saturday). Weekend days
  don't break your streak and are shown in grey in the day-of-week chart
- **Weekly target** — hours per week (0 turns it off); shown on the weekly
  chart and in the insights
- **Locked PC counts up to** — the cap for a single locked break

The week start and weekend default to your browser's region settings.
Settings are saved in that browser.

### Session log

The log is grouped by day, with each day's total on its header row. Pick a
period (this/last week, this/last month, last 30 days, all time); only 14
days are shown at a time, with **Show more** to load further back, so the
page stays fast however long you've been tracking. **Export** downloads the
selected period as a CSV (one row per session, plus a daily total) for
Excel or anywhere else.

---

## Troubleshooting

### Double-clicking Install.cmd does nothing / a window flashes and closes

Make sure you extracted the ZIP first (right-click → **Extract All…**).
Running `Install.cmd` from inside the ZIP preview doesn't work, because the
other files aren't there. If the window shows an error, it stays open until
you press a key. The details are in
`C:\Users\<you>\UptimeLoom\install-log.txt`.

If your organisation blocks `.cmd` files or PowerShell completely (rare,
but some locked-down PCs do), Uptime Loom can't run there without IT's help.

### Dashboard shows "Not active" even though the PC is on

If you're in Chrome/Edge with live sync active, wait up to 15 seconds for
the next automatic sync, or click **Sync now**. If you're on a browser
without live sync (e.g. Firefox), click **Refresh** and re-select
`heartbeat_log.csv` to pull the latest data.

### No new heartbeats are being written / logging seems stuck

Run `Install.cmd` again. It stops any stuck copy, starts a fresh one and
tells you whether logging is working. To look at the log yourself:

```powershell
Get-Content "$env:USERPROFILE\UptimeLoom\heartbeat_log.csv" -Tail 5
```

A new line should appear about once a minute. Logging can't happen while
the PC itself is asleep, so gaps during sleep are expected.

### Locked time isn't detected correctly

Lock, wait 2 minutes, unlock, and look at the end of `heartbeat_log.csv`:
the lines written while locked should end in `,locked`.

- **No `,active` / `,locked` at the end of the lines at all?** An older
  copy of the heartbeat script is still running. Run `Install.cmd` again.
  It replaces the old copy straight away.
- **Lines say `,active` while you were locked?** Run the built-in check:

  ```powershell
  & ([scriptblock]::Create((Get-Content "$env:USERPROFILE\UptimeLoom\Heartbeat.ps1" -Raw))) -Diagnose
  ```

  (Paste it into a PowerShell window: Start menu → type *PowerShell* →
  Enter.)

  Press `Win+L` as soon as it starts, wait ~30 seconds, then unlock. The
  window (and `lock_diagnose.txt` in your UptimeLoom folder) shows what each
  detection method reported every 5 seconds — lines from while you were
  locked should say `final=LOCKED`. If they don't, that file is exactly
  what's needed to work out why.

Lock detection asks Windows directly for your session's lock state
(`WTSQuerySessionInformation`), falling back to checking for the sign-in
screen (`LogonUI.exe`) if that's unavailable. It can still behave
inconsistently over Remote Desktop or on some managed/corporate builds.
If locking isn't detected, locked breaks are simply logged as active (so
they still count), but the 4-hour cap, the "you have to come back" rule
and the Going out shortcut can't work properly.

### Logging doesn't start after signing in

Check that the startup entry exists (`UptimeLoom.lnk`, or `UptimeLoom.cmd`
on PCs that don't allow shortcuts):

```powershell
Get-ChildItem "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup" -Filter "UptimeLoom*"
```

If nothing is listed, run `Install.cmd` again. Also check that Uptime Loom
isn't turned off under **Settings → Apps → Startup** in Windows.

---

## Data format

`heartbeat_log.csv` is a simple CSV:

```
Timestamp,State
2026-08-16 09:03:12,active
2026-08-16 09:04:12,active
2026-08-16 11:02:12,locked
...
```

`State` is `active` (unlocked) or `locked`. Logs from older versions have no
state column; those lines are treated as `active`.

The dashboard reconstructs sessions by finding gaps larger than 3 minutes
between consecutive timestamps — a gap means the PC was off, asleep, or you
used the Going out shortcut. Locked stretches inside a session count if
they end with an unlock and are no longer than the cap. Timestamps are local wall-clock time. Daily totals are
split at local midnight (a session from 11 PM to 1 AM counts one hour on
each day), and overlapping sessions — e.g. a manual session that overlaps
logged time — are only counted once. This format is intentionally simple so you can also
open it in Excel or process it yourself (Python/pandas, etc.) if you want
custom analysis.

`corrections.json` (created automatically the first time you save a
correction) is a plain array of correction objects:

```json
[
  {
    "type": "edit",
    "rawId": "sess_1755320400000",
    "start": "2026-08-16T09:00:00.000Z",
    "end": "2026-08-16T17:30:00.000Z",
    "note": "class from 1-2pm"
  }
]
```

`type` is one of `edit`, `delete`, `add`, or `away` (a time range
subtracted from your totals). You generally shouldn't need
to hand-edit this file, but it's plain and readable if you ever want to.

---

## Privacy

Everything stays local:
- The heartbeat script only writes to a file on your own disk
- The dashboard is a static HTML file — it makes no network requests
- No telemetry, no accounts, no external services

---

## Limitations

- It can't know *where* you are: a locked PC looks the same whether you're
  in class or off campus. Use the Going out shortcut (or **Mark away**
  afterwards) for time that shouldn't count. If you lock the PC, go to
  class and then leave directly without coming back, that class time isn't
  counted automatically — add it with **+ Add session**
- An idle-but-unlocked screen still counts as active
- Lock-screen detection relies on a standard Windows API check that is
  reliable on typical local sessions but can behave inconsistently over
  Remote Desktop or certain managed/corporate Windows configurations — see
  Troubleshooting if you suspect this
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
