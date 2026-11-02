# Queue and schedule behaviour

What Persepolis does today, from `persepolis/scripts/queue.py`,
`persepolis_lib_prime.py`, `shutdown.py` and `mainwindow.py`. Swiftpolis keeps these
rules and fixes the items marked **defect**, detailed in
[upstream-defects.md](upstream-defects.md) ([ADR 0001](adr/0001-parity-with-defects-fixed.md)).

## Categories

- Three exist from first launch: **All Downloads**, **Single Downloads**, **Scheduled Downloads**.
- A new Queue's name cannot be empty, `Single Downloads`, or an existing name.
- `Scheduled Downloads`, `All Downloads` and `Single Downloads` cannot be removed.
- Removing a Queue also removes its Downloads from the list, after a warning that can be
  silenced with "don't show this message again". Files on disk stay.
- Each Category stores an ordered list of GIDs. All Downloads holds every GID too.
- New GIDs are appended, and the table shows the list newest first.
- Move up and move down exist only for Queues, and are disabled while the Queue runs.
- Sorting rewrites the current Category's stored order, so a sort also changes the order a
  Queue runs in.

## Who may control a Download

| Action | Single Downloads | Download in a Queue |
| --- | --- | --- |
| Adding it | Starts now unless "download later" is chosen | Never starts; status `stopped` |
| Resume, pause, stop from the main window | Allowed | Refused with a notification naming the Queue |
| Remove or delete | Allowed | Refused while the Queue is running |
| Move to another Category | Only while `error`, `stopped` or `complete` | Same, and refused while the source Queue runs |

Moving a Download between Categories clears its Start time, End time and
After-download shutdown. A Video Finder pair always moves together.

## Running a Queue

Starting a Queue saves its panel options, then runs this on its own thread:

```
for pass in 1...5:
    reload the Category's GID list and Download statuses
    order = reverse is off ? list reversed (newest first, the table's top-to-bottom)
                           : list as stored (oldest first)

    if pass == 1 and a Start time is set:
        give that Start time to the first Download that is not complete

    for each Download in order:
        skip if complete
        counter += 1                          # never resets across passes
        set its End time to the Queue's, if any
        if Queue wait != 0 and counter != 1:
            Start time = now + Queue wait     # one minute later if now's seconds > 30
        start the Download; sleep 3 s
        while status is downloading, waiting, paused or scheduled:
            sleep 1 s; re-read status from the database
            if the Queue was stopped: stop this Download
            if the Speed dial moved and status is downloading: apply it
        if status == stopped:
            leave both loops                  # "Queue Stopped!"
        # status error or complete: carry on with the next Download

if the Queue was not stopped:                 # "Queue completed!"
    if After-download shutdown is on: request shutdown
```

Rules that follow from this:

- **Strictly one active Download per Queue.** Different Queues run at the same time, and
  Single Downloads run alongside them.
- **Failures are retried by later Passes**, up to five times in total, with no delay of
  their own.
- **Downloads added while running** are picked up at the next Pass.
- **"Queue completed!" does not mean everything succeeded.** Five Passes can end with
  items still in `error`.
- **A `stopped` Download ends the whole Queue**, whether from the user, End time or a
  stop issued some other way.
- Queue-driven HTTP Downloads get the Speed dial's value when they start.
- Reverse and the Speed dial are read from the main-window widgets at run time. **Defect D9.**

## Queue panel

| Queue state | Panel shows |
| --- | --- |
| Stopped | Start time checkbox and time, End time checkbox and time, Reverse |
| Started | Speed dial (0 to 10, "Minimum" and "Maximum" at the ends), After-download shutdown |

Times are `HH:MM`. New Categories store `0:0` for both.

## How a clock time fires

Start time and End time share one mechanism, in the HTTP, yt-dlp and torrent engines:

- A time is converted to minutes since midnight. There is no date.
- A loop compares it with the current minute **for equality** every 2.1 seconds.
- Start time holds the Download in status `scheduled`. When it fires, the stored Start time
  is cleared and the Download proceeds.
- End time runs on a side thread from when the Download starts. When it fires, the
  Download is stopped and the stored End time is cleared.

Consequences:

- A time earlier than now means tomorrow.
- If the Mac is asleep for that whole minute, the time is missed and the loop waits about
  24 more hours. **Defect D1.**
- A Download that finishes before its End time appears to flip to `stopped` when that time
  arrives. **Defect D2.**

### Swiftpolis: missed times

Decided in [Q17](open-questions.md), replacing Defect D1. The scenario is a Queue set for 02:00
to 06:00 with the Mac asleep past 02:00:

| Mac wakes | Result |
| --- | --- |
| Before 02:00 | Normal |
| 04:00 | Start then, and stop at 06:00 |
| 08:00 | Don't start. Notify that the window was missed |

The End time is the first occurrence after the Start time, so 23:00 to 01:00 crosses midnight
correctly.

## Keep Awake

If `awake` is on, Persepolis nudges the mouse pointer while any session exists. Sessions include
Downloads waiting in status `scheduled`.

Swiftpolis keeps the same condition but uses a power assertion
([Q19](open-questions.md)). This only prevents idle sleep. A closed lid can still put the Mac to
sleep, and the app can't wake the Mac by itself without root access, so the Start time field
needs a note saying so.

## What survives a restart

At every launch `setDBTablesToDefaultValue()` runs:

- Every Category's Start time flag, End time flag, Reverse, limit and After-download flags
  are cleared. The `HH:MM` values remain.
- Every Download's Start time, End time and After-download value are cleared.
- Every status except `complete` and `error` becomes `stopped`.

**So schedules do not survive quitting the app, and no Queue resumes on launch.**
Quitting is refused while any Download is active.

Swiftpolis keeps this rule ([Q18](open-questions.md)), with a clear note in the UI that schedules
don't survive quitting.

## After-download shutdown

**Queue:** checking the panel box and confirming asks for the root password, verified with
`sudo -S echo`. A background loop then polls every 5 seconds.

**Single Download:** the progress window has the same control.

When the Queue completes, or the Download finishes with status `error`, `stopped` or
`complete` while the request is still pending:

1. Notify the user, then stop all Downloads.
2. Wait 20 seconds, then wait for all sessions to end.
3. Close databases and threads, then run `sudo -S shutdown -h now`.

Unchecking the box, or stopping the Queue or Download from the main window, cancels the
request. See **Defect D10** about holding the root password. Swiftpolis keeps the same sequence
but asks the system to shut down, without a password.

## Single-Download scheduling

The Add Link window can set Start time and End time. A Start time produces a "Download
Scheduled" notification and a Spider request to fill in name and size straight away.

## Queue wait

Set in Preferences as hours and minutes (`settings/wait-queue`, default `[0, 0]`). It
applies to every Queue. It is implemented as a Start time, so it inherits the same
equality matching and can be missed in the same way.
