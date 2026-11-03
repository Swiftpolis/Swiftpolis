# Persepolis defects

Found in the code at `8940bcf`. Swiftpolis fixes these rather than copying them
([ADR 0001](adr/0001-parity-with-defects-fixed.md)). **Confirmed** means it was seen by running the
real engine ([persepolis-observed.md](persepolis-observed.md)). **Read** means it comes only from
reading the code so far.

| ID | Status | Defect | Where | Effect | Fix |
| --- | --- | --- | --- | --- | --- |
| D1 | Read | Start and End times compare for an exact minute | `startTime`, `endTime` in all engines | A Mac asleep through that minute misses it, and the time recurs a day later | Fire at the first check at or after the time; see [Q17](open-questions.md) |
| D2 | Confirmed | The End time loop keeps going after `complete` | `endTime`, and `close()` joining threads | A finished Download flips to `stopped` at its End time, and its session lingers until then | End the timer when the Download ends |
| D3 | Read | Main-window Pause calls `downloadUnpause()` | `pauseButtonPressed` | The main window's Pause action does not pause. The progress window's Pause button works | Call pause |
| D4 | Confirmed | Connections aren't what was asked for | `definePartSizes` | A 10 MiB file uses 10 Connections when 4 were set; resuming 40 Parts uses 64 | Use the lower of Connections and Parts |
| D5 | Read | The clipboard thread's first loop never exits while running | `CheckClipBoardThread.run` | Clipboard monitoring appears never to fire | Implement the intended behaviour |
| D6 | Confirmed | The authenticated proxy URL is malformed | `createSession`, `spider` | Proxy authentication always fails | Build it correctly |
| D7 | Confirmed | `Content-Disposition` is parsed crudely | `getFileName` | Names keep their quotes; `filename*=` gives a name containing the whole header | Parse properly, including `filename*=` |
| D8 | Read | The host ignores the extension's `cookies` | `persepolis.py` message parsing | Downloads needing a login fail despite the extension collecting cookies | Use them |
| D9 | Confirmed | The Queue thread reads shared widgets | `queue.py:74`, `:208`, `:290` | Reverse and Speed dial reflect whichever Category is showing, not this Queue | Store per Queue |
| D10 | Read | Root password held in memory and piped to `sudo` | `afterPushButtonPressed`, `shutDown` | Needless exposure of the root password | Request shutdown from the system, with no password |
| D11 | Read | Passwords stored in plain text | `addlink_db_table` | Proxy and site passwords are readable on disk | Keychain |
| D12 | Not reproduced | All workers share one session's `Range` header | `threadHandler` | Could corrupt a Part, but three heavily concurrent runs stayed intact | Per-request header |
| D13 | Confirmed | No range support, but all workers still run | `runDownloadThreads` sets unused `thread_number` | A 4 MiB file cost 16 MiB of transfer | One Part, one Connection |
| D14 | Confirmed | Missing comma in the document list | `findDownloadPath` | `pub` and `mobi` files go to `Others` | Fix the list |
| D15 | Confirmed, minor | One archive extension can't match | `findDownloadPath` | The list has uppercase `F` only, so `.f` goes to `Others`. Other uppercase entries have lowercase twins | Fix the list |
| D16 | Confirmed | One-character file stems crash the rename | `returnNewFileName` reads `[-2]` | `IndexError` on a collision with a name like `a.zip`; the file stays outside its subfolder | Fix |
| D17 | Read | Seeding has UI but isn't wired in | `TorrentSeed` is unreferenced | Preferences for it do nothing | See [Q13](open-questions.md) |
| D18 | Read | Notification sounds downloaded at runtime | `createNotificationSounds` | They need network access, and come from a remote repository | Bundle them |
| D19 | Confirmed | A fast download is reported as `error` | `start`, `checkDownloadProgress` | A file that finishes before the last worker starts shows `error`, at 99%, with its control file left behind | Decide from the Parts when the workers end |
| D20 | Confirmed | Short reads aren't counted as attempts | `threadHandler` | A 404 caused 115,564 requests in 90 seconds, forever | Treat HTTP errors as failures, and count every attempt |
| D21 | Confirmed | The first control-file write comes late | `runDownloadThreads`, `saveInfo` | Stopping early loses resume | Write it before any worker starts |
| D22 | Confirmed | With no ETag, a size change isn't noticed | `createControlFile` compares `null` with `null` | A changed file "resumes" and is silently damaged | Compare ETags only if both exist, otherwise sizes |
| D23 | Confirmed, minor | The last Part counts one byte too few | `threadHandler` part size | `downloaded_size` ends one short | Use the true size |
| D24 | Confirmed, minor | `#HttpOnly_` cookie lines are ignored | `readCookieJar` | Those cookies aren't sent | Strip the prefix |
| D25 | Confirmed, minor | `error_message` is never cleared | `getFileSize` | A `complete` download can still carry `Error` | Clear it, or only set it on failure |
| D26 | Read | A finished file with the same name is overwritten | `createControlFile` | Downloading to a folder that already has that file name, with no control file, truncates the existing file | Pick a new name |
| D28 | Read | Removing a Download deletes any file with its name | `DeleteThingsThatAreNoLongerNeededThread` | A Download that never ran, whose Spider-found name matches a file you already have, deletes that file when removed | Delete only if the Download's control file is beside it |
| D29 | Confirmed, minor | An End time reports twice | `queue.py` leaves `start` set | "Queue Stopped!" and "Queue completed!" both appear | Report it once, as stopped |
| D27 | Read | A server-supplied name isn't checked | `getFileName`, then `os.path.join` | A `Content-Disposition` name like `../../x` could write outside the download folder | Keep only the last path component |
