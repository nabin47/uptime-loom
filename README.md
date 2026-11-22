# Uptime Loom

A zero-click, no-admin-required work-hours tracker for Windows. It records
your time automatically from the moment you switch your PC on. Classes and
meetings still count when you lock the screen, while time you're actually
away doesn't. A local dashboard then answers the everyday questions: how
many hours have I done this week, how much is left, was I on time, which
days did I miss?

No accounts, no cloud, no admin rights. Your data never leaves your machine.

![platform](https://img.shields.io/badge/platform-Windows%2010%20%7C%2011-0078D6)
![admin](https://img.shields.io/badge/admin%20rights-not%20required-brightgreen)

---

## Contents

- [Installation](#installation)
- [Day to day](#day-to-day)
- [How time is counted](#how-time-is-counted)
- [The dashboard](#the-dashboard)
- [Settings](#settings)
- [Corrections, days off and time away](#corrections-days-off-and-time-away)
- [Troubleshooting](#troubleshooting)
- [Files](#files)
- [Data format](#data-format)
- [Privacy](#privacy)
- [Limitations](#limitations)

---

## Installation

No administrator rights needed.

1. **Download** this repository as a ZIP (green **Code** button → **Download
   ZIP**), then right-click the ZIP → **Extract All…**.
2. Open the extracted folder and **double-click `Install.cmd`**.
   - If Windows shows *"Windows protected your PC"*, click **More info** →
     **Run anyway**. If it shows *"Open File – Security Warning"*, click
     **Run**. Windows does this for any file downloaded from the internet.
     All the files are short and readable, so look through them first if
     you like.
3. That's it. The installer:
   - copies Uptime Loom to `C:\Users\<you>\UptimeLoom`
   - starts logging **right away** and checks that it's working
   - makes it start automatically every time you sign in
   - adds **Uptime Loom** (the dashboard) and **Uptime Loom - Going out**
     (hotkey **Ctrl+Alt+G**) to your Desktop and Start menu
   - opens the dashboard with the folder path already copied, so you just
     click **Load folder** and paste it with **Ctrl+V**
4. **First time in the dashboard:** open **Settings** and check your weekly
   target, weekend days and work hours. The defaults are 40 hours, your
   region's weekend, and 9:00–17:00.

To **update**, download the new version and run `Install.cmd` again. Your
data, corrections and settings are kept, and the new version takes over
immediately. You don't need to sign out.

To **uninstall**, double-click `Uninstall.cmd` (also in
`C:\Users\<you>\UptimeLoom`). It stops logging and removes the startup entry
and shortcuts. Your data stays in the folder until you delete it.

The installer also works on locked-down work PCs. It doesn't depend on
PowerShell's script execution policy, and where a step is blocked (for
example creating shortcuts) it uses a simpler alternative. If anything
still goes wrong, it says so and saves a log to
`C:\Users\<you>\UptimeLoom\install-log.txt`. Send that file to whoever is
helping you.

---

## Day to day

| Situation | What to do | Counted? |
|---|---|---|
| Arriving | Switch the PC on. Sign in whenever you get to it | ✅ From when you switched it on* |
| Class, meeting, lunch | Lock the PC as usual (**Win+L**) | ✅ When you come back and unlock* |
| Going off campus / leaving for work elsewhere | Use **Uptime Loom - Going out** (**Ctrl+Alt+G**) | ❌ Not until you unlock again |
| Going home | Shut down, sleep, or just lock | ❌ Nothing after you leave |
| Leave, holiday, sick day | Mark it as a **Day off** in the dashboard | Not counted as missed |
| Forgot Ctrl+Alt+G before leaving | **− Mark away** in the dashboard afterwards | ❌ That range is removed |

\* Up to 4 hours per stretch by default (changeable in **Settings**).

---

## How time is counted

A small background script (`Heartbeat.ps1`) starts when you sign in. Every
minute it adds a line to `heartbeat_log.csv`: the time, and whether the PC
was **active** (unlocked) or **locked**. When the PC is shut down or asleep,
nothing is written. The dashboard turns these lines into work sessions.

**Locked time counts, with two safety rules.**

- **You have to come back.** A locked stretch only counts if it ends with
  you unlocking the PC. If you lock it and go home, and it later sleeps or
  stays locked overnight, that locked time is dropped.
- **There's a cap.** One locked stretch counts for at most **4 hours** by
  default. A longer stretch is treated as time away. Set the cap to `0` to
  never count locked time.

**Time before you sign in counts too, with the same rules.** Without
administrator rights nothing can run before you sign in. So when you do
sign in, Uptime Loom checks Windows' own record of when the PC was switched
on (or woke from sleep) and adds a `boot` line for that time. The time from
switching on until signing in then counts, as long as you signed in within
the cap. A PC that wakes at night for updates, with nobody signing in,
never counts. Waking from sleep to the lock screen and unlocking later
works the same way.

**Going out stops the clock.** The **Going out** shortcut locks the PC and
marks you as away. While you're away nothing is logged, so that time is
excluded exactly like a shutdown. Unlocking ends the away period.

```
Switch on ──▶ (sign in later) ──▶ Heartbeat.ps1 starts, adds a "boot" line
                                        │
                                        ▼
                     writes "time,active" or "time,locked" every minute
                                        │
        ┌───────────────────────────────┼───────────────────────────┐
        ▼                               ▼                           ▼
 Win+L (class/meeting)        Going out (Ctrl+Alt+G)          Shutdown / sleep
 logged as "locked";          locks + marks away;             nothing written
 counts once you unlock       nothing written until           (not counted)
 (up to the cap)              you unlock
                                        │
                                        ▼
               open the dashboard ──▶ see hours, targets and attendance
```

A gap of more than 3 minutes between lines ends a session. Daily totals are
split at midnight (a session from 11 PM to 1 AM counts one hour on each
day), and overlapping time, such as a manual session on top of logged
time, is only counted once.

---

## The dashboard

Open **Uptime Loom** from your Desktop or Start menu. It's
`C:\Users\<you>\UptimeLoom\dashboard.html` and opens in your browser.

**Loading your data.** The first time, click **Load folder** and choose your
`UptimeLoom` folder (choosing your user folder above it works too).

- **In Chrome or Edge** you only do this once. The dashboard remembers the
  folder and re-reads it every 15 seconds ("last synced" in the header
  shows when). Next time it either loads straight away (if you allowed
  access "on every visit") or shows a one-click **Reconnect** button.
- **In Firefox or other browsers**, drag `heartbeat_log.csv` from the
  UptimeLoom folder onto the page, and click **Refresh** for newer data.

**What's on it, from top to bottom:**

- **Today**: a live timer, when you started, and the current status:
  - **Active**: the PC is unlocked.
  - **Locked · counting**: the PC is locked, and it shows the time by which
    you need to unlock for the break to count.
  - **Not active**: the PC is off, asleep, or you're away.
- **Quick stats**:
  - Hours this week and this month, with last week/month "by now" for
    comparison
  - **Left this week** (hours still needed for your target)
  - **Days present** this month
  - **Usual arrival** and **usual departure** (average of the last 10 days)
- **Summary**: this week and this month side by side. Each row:

  | Row | Meaning |
  |---|---|
  | Hours worked | All counted time, including class/meeting time and time before signing in |
  | Target | Your weekly target split over workdays, minus any days off (e.g. 8h × 5 workdays) |
  | Still needed | Hours left to reach the target, and about how much that is per remaining workday |
  | Ahead or behind | Finished days only: hours worked compared with the target for those days |
  | Days present | Workdays with any time recorded, and which workdays were missed |
  | Average per day present | Over finished days, so today's partial hours don't lower it |
  | On time | Days you arrived within 15 minutes of your start time |
  | Left early | Days you left more than 15 minutes before your end time |
  | Class / meeting time | Locked breaks that counted |
  | Before signing in | Time between switching the PC on and signing in |
  | Marked away | Time you removed with Mark away (not counted) |
  | Weekend work | Days and hours worked on your weekend days |

- **Things to know**: short notes, only when something needs attention:
  - how many hours a day you need to reach this week's target
  - a workday in the last two weeks with no time recorded, with a
    **Mark as day off** button
  - your last day worked in one line
  - arriving late on most of your recent workdays
  - a day over 10 hours
- **Charts**:
  - daily hours for the last 30 days
  - weekly hours for the last 12 weeks against your target
  - *When you work* (average minutes in each hour of the day)
  - average hours by day of the week
  - first-in / last-out times for recent days
  - an activity calendar
- **Session log**: grouped by day with each day's total. Pick a period
  (this/last week, this/last month, last 30 days, all time). 14 days are
  shown at a time, with **Show more** for older days. **Export** downloads
  the selected period as a CSV for Excel.

Light and dark mode follow your system; switch with the button in the top
corner.

---

## Settings

Open **Settings** at the top of the dashboard:

| Setting | Default | What it does |
|---|---|---|
| Week starts on | Your region | Used for "this week", the weekly chart, the calendar and the log's week filters |
| Weekend days | Your region | Any combination (e.g. Friday + Saturday). Every other day is a workday. Weekend days are never "missed" |
| Weekly target | 40 hours | Split evenly over your workdays (40h ÷ 5 = 8h a day). Gives the monthly target, *Still needed* and *Ahead or behind*. `0` turns targets off |
| Work hours | 9:00–17:00 | Used for *On time* and *Left early* (15 minutes leeway). Clear a field to turn that row off |
| Locked PC counts up to | 4 hours | The cap for one locked break, and for the wait between switching on and signing in |

Settings are saved in the browser you use for the dashboard.

---

## Corrections, days off and time away

The session log lets you fix anything the automatic tracking got wrong:

- **Edit** a session's start/end time and add a note
- **Delete** a session that shouldn't count
- **+ Add session** for time that was never logged (e.g. you worked
  elsewhere, or the PC was on but you never signed in)
- **− Mark away** to remove a time range (e.g. you went off campus but only
  locked the PC)
- **Day off** for leave, holidays or sick days. That day isn't counted as
  missed, and the week's and month's targets are lowered to match. A
  missed workday in *Things to know* also has a **Mark as day off** button.

`heartbeat_log.csv` itself is **never changed**. Corrections are kept
separately and applied on top:

- **In Chrome or Edge** they're saved to `corrections.json` in your
  UptimeLoom folder. That makes them durable (they survive clearing browser
  data), portable (open the dashboard on another PC pointing at the same
  folder) and readable in any text editor.
- **In Firefox or other browsers** they're saved in that browser only.

---

## Troubleshooting

### Double-clicking Install.cmd does nothing / a window flashes and closes

Make sure you extracted the ZIP first (right-click → **Extract All…**).
Running `Install.cmd` from inside the ZIP preview doesn't work, because the
other files aren't there. If the installer shows an error, its window
stays open until you press a key, and the details are in
`C:\Users\<you>\UptimeLoom\install-log.txt`.

If your organisation blocks `.cmd` files or PowerShell completely (rare,
but some locked-down PCs do), Uptime Loom can't run there without IT's
help.

### The dashboard looks out of date

In Chrome/Edge, wait up to 15 seconds for the next sync, or click **Sync
now**. In Firefox, drag the latest `heartbeat_log.csv` onto the page again
or click **Refresh**.

### No new lines are being written / logging seems stuck

Run `Install.cmd` again. It stops any stuck copy, starts a fresh one and
tells you whether logging is working. To look at the log yourself
(Start menu → type *PowerShell* → Enter, then paste):

```powershell
Get-Content "$env:USERPROFILE\UptimeLoom\heartbeat_log.csv" -Tail 5
```

A new line should appear about once a minute. Nothing can be written while
the PC is asleep, so gaps during sleep are expected.

### Logging doesn't start after signing in

Check that the startup entry exists (`UptimeLoom.lnk`, or `UptimeLoom.cmd`
on PCs that don't allow shortcuts):

```powershell
Get-ChildItem "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup" -Filter "UptimeLoom*"
```

If nothing is listed, run `Install.cmd` again. Also check that Uptime Loom
isn't turned off under **Settings → Apps → Startup** in Windows.

### Locked time or time before signing in isn't counted correctly

First check the log. Lines written while the PC was locked should end in
`,locked`, and after switching on and signing in later there should be a
`,boot` line:

```powershell
Get-Content "$env:USERPROFILE\UptimeLoom\heartbeat_log.csv" -Tail 30
```

- **No `,active` / `,locked` at the end of the lines?** An older version is
  still running. Run `Install.cmd` again.
- **Lines say `,active` while you were locked, or there's no `,boot`
  line?** Run the built-in check:

  ```powershell
  & ([scriptblock]::Create((Get-Content "$env:USERPROFILE\UptimeLoom\Heartbeat.ps1" -Raw))) -Diagnose
  ```

  It first prints **"Last switched on / woke up"**: when Windows says the
  PC was last switched on. If it says *not found*, this PC doesn't let
  normal users read that record, so time before signing in can't be
  counted. Then press **Win+L**, wait ~30 seconds and unlock. Lines from
  while you were locked should say `final=LOCKED`. Everything is also
  saved to `lock_diagnose.txt` in your UptimeLoom folder. Send that file if
  you need help.

Lock detection asks Windows directly for your session's lock state, and
falls back to checking for the sign-in screen if that isn't available. It
can be unreliable over Remote Desktop or on some managed work PCs. If
locking isn't detected, locked breaks are logged as active (so they still
count), but the cap, the "you have to come back" rule and the Going out
shortcut can't work properly.

---

## Files

**In the download:**

| File | What it is |
|---|---|
| `Install.cmd` | Double-click to install or update |
| `Uninstall.cmd` | Double-click to remove (keeps your data) |
| `SetupHeartbeat.ps1` | The installer/uninstaller logic, run by the two files above |
| `Heartbeat.ps1` | The background logger |
| `GoingOut.ps1` | Locks the PC and marks you as away (the *Going out* shortcut) |
| `dashboard.html` | The dashboard; a single file that runs in your browser |

**Created in `C:\Users\<you>\UptimeLoom`:**

| File | What it is |
|---|---|
| `heartbeat_log.csv` | The raw log, one line a minute |
| `corrections.json` | Your edits, added sessions, away times and days off (Chrome/Edge) |
| `away.flag` | Exists only while you're marked as away |
| `install-log.txt` | What the installer did, for troubleshooting |
| `lock_diagnose.txt` | Output of the built-in check, if you ran it |

---

## Data format

`heartbeat_log.csv`:

```
Timestamp,State
2026-08-16 07:52:40,boot
2026-08-16 08:31:12,active
2026-08-16 08:32:12,active
2026-08-16 11:02:12,locked
...
```

- Times are local wall-clock time, always written as
  `yyyy-MM-dd HH:mm:ss` whatever your regional settings.
- `State` is one of:
  - `active`: unlocked
  - `locked`: locked
  - `boot`: when the PC was switched on or woke up, written once you sign
    in
- Logs from older versions have no state column; those lines count as
  `active`.

The format is deliberately simple, so you can also open it in Excel or
analyse it yourself (Python/pandas, etc.).

`corrections.json` is a plain list of corrections:

```json
[
  { "type": "edit", "rawId": "sess_1755320400000", "start": "2026-08-16T09:00:00.000Z", "end": "2026-08-16T17:30:00.000Z", "note": "class from 1-2pm" },
  { "type": "add", "id": "manual_1755400000000", "start": "2026-08-17T09:00:00.000Z", "end": "2026-08-17T12:00:00.000Z", "note": "worked from library" },
  { "type": "away", "id": "away_1755500000000", "start": "2026-08-18T13:00:00.000Z", "end": "2026-08-18T15:00:00.000Z", "note": "client visit" },
  { "type": "dayoff", "id": "dayoff_2026-08-19", "date": "2026-08-19", "note": "annual leave" },
  { "type": "delete", "rawId": "sess_1755580000000" }
]
```

You shouldn't need to edit it by hand, but it's readable if you want to.

---

## Privacy

Everything stays on your PC:

- The logger only writes to files in your own `UptimeLoom` folder.
- To count time before you sign in, it reads the switch-on and wake-up
  times from Windows' System event log on your own PC. Nothing else is
  read, and nothing is sent anywhere.
- The dashboard is a static HTML file that makes no network requests.
- No telemetry, no accounts, no external services.

---

## Limitations

- **It can't know where you are.** A locked PC looks the same whether you're
  in class or off campus, so use **Going out** (or **Mark away**
  afterwards) for time that shouldn't count. If you lock the PC, go to
  class and then leave without coming back, that class time isn't counted
  automatically. Add it with **+ Add session**.
- **You have to sign in at some point.** If you switch the PC on and never
  sign in that day, nothing is recorded.
- An unlocked but idle PC still counts as active.
- Times are accurate to about a minute.
- Lock detection and switch-on times come from Windows itself and can be
  unreliable over Remote Desktop or on some managed work PCs. See
  [Troubleshooting](#troubleshooting).
- The logger is Windows-only. The dashboard works in any browser, but
  automatic syncing and saving corrections to the folder need Chrome or
  Edge.
- Settings are saved per browser.

---

## License

MIT — use, modify, and share freely.

---

<sub>© 2026 Jubair Ahmed Nabin. All rights reserved under the MIT License above.</sub>
