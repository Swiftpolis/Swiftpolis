# Persepolis defects found while reading

Found by reading the code at `8940bcf`. **None were confirmed by running Persepolis**, so each
needs a behavioural test before Swiftpolis relies on the claim. Swiftpolis fixes these rather
than copying them ([ADR 0001](adr/0001-parity-with-defects-fixed.md)). The last column is the
intended fix.

| ID | Defect | Where | Effect | Proposal |
| --- | --- | --- | --- | --- |
| D1 | Start and End times compare for an exact minute | `startTime`, `endTime` in all engines | A Mac asleep through that minute misses it, and the time recurs a day later | Fire at the first check at or after the time; see [Q17](open-questions.md) |
| D2 | The End time loop keeps going after `complete` | `endTime`, and `close()` joining threads | A finished Download can flip to `stopped`, and its session lingers until End time. A Queue could then fetch it again | End the timer when the Download ends |
| D3 | Main-window Pause calls `downloadUnpause()` | `pauseButtonPressed` | The main window's Pause action does not pause. The progress window's Pause button works | Call pause |
| D4 | Small files override the configured Connections | `definePartSizes` | A 10 MiB file uses 10 Connections even if the user set 4 | Use the lower of the two |
| D5 | The clipboard thread's first loop never exits while running | `CheckClipBoardThread.run` | Clipboard monitoring appears never to fire | Implement the intended behaviour |
| D6 | The authenticated proxy URL is built twice over | `createSession`, `spider` | Produces `://user:pw@://host:port`, so proxy auth should fail | Build it correctly |
| D7 | `Content-Disposition` quotes aren't stripped by the engine, though the Spider strips them | `getFileName` | Files can be saved with literal quote marks | Parse properly, including `filename*=` |
| D8 | The host ignores the extension's `cookies` | `persepolis.py` message parsing | Downloads needing a login fail despite the extension collecting cookies | Use them |
| D9 | The Queue thread reads shared widgets | `queue.py:74`, `:208`, `:290` | Reverse and Speed dial reflect whichever Category is showing, not this Queue | Store per Queue |
| D10 | Root password held in memory and piped to `sudo` | `afterPushButtonPressed`, `shutDown` | Needless exposure of the root password | Request shutdown from the system, with no password |
| D11 | Passwords stored in plain text | `addlink_db_table` | Proxy and site passwords are readable on disk | Keychain |
| D12 | All workers share one session's `Range` header | `threadHandler` | One worker can overwrite another's range before sending, which could corrupt a Part | Per-request header |
| D13 | No range support, but all workers still run | `runDownloadThreads` sets unused `thread_number` | Every worker fetches the whole file from byte 0 | One Connection |
| D14 | Missing comma in the document list | `findDownloadPath` | `pub` and `mobi` merge into `pubmobi`, so those files go to `Others` | Fix the list |
| D15 | Mixed-case archive extensions can't match | `findDownloadPath` | `LBR`, `F`, `Z` and `tar.Z` entries never match a lowercased extension | Fix the list |
| D16 | One-character file stems crash the rename | `returnNewFileName` reads `[-2]` | An `IndexError` on a collision with a name like `a.zip` | Fix |
| D17 | Seeding has UI but isn't wired in | `TorrentSeed` is unreferenced | Preferences for it do nothing | See [Q13](open-questions.md) |
| D18 | Notification sounds downloaded at runtime | `createNotificationSounds` | They need network access, and come from a remote repository | Bundle them |
