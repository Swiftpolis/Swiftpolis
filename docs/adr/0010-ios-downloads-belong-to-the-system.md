# On iOS, downloads belong to the system

iOS suspends an app soon after it leaves the screen, so the Mac's engine would stop downloading the moment
someone locked their iPad. On iOS and iPadOS each Download is instead a task in a background `URLSession`, which
the system runs whether or not the app is alive. `BackgroundDownloadEngine` wraps one task, and
`BackgroundTransfers` owns the session.

This gives up some of what the Mac does, because the app isn't there to do it:

| On the Mac | On iOS and iPadOS | Why |
| --- | --- | --- |
| Up to 64 Connections per file | One per file | A task is one connection |
| One Download at a time in a Queue | Everything handed over at once, up to 3 per host | A task the app starts while in the background can be held back for hours, so the next one can't wait for the last |
| Speed dial | None | The system paces the transfer |
| Start time and End time | Start time only, roughly | The system holds a task back until a date, but nothing can stop one at a time |
| Queue wait | None | Same as handing everything over |
| Video Finder, Muxing | None | iOS can't run other programs, so no yt-dlp or ffmpeg |
| Proxies, per Download | None | A session has one proxy setting, for all its tasks |
| Choose any folder | The app's Documents folder, shown in the Files app | Paths would need security-scoped bookmarks |
| Shutdown afterwards, Dock, menu bar, clipboard watching | None | iOS has no such things |

This is an exception to [ADR 0001](0001-parity-with-defects-fixed.md). Queue rules that can still hold do: five
Passes retry what failed, complete Downloads are skipped, and a Queue's Downloads are controlled through the Queue.

## Consequences

- **The app can vanish at any time.** At launch `DownloadCoordinator.adopt` takes back whatever the system kept, or
  finished while the app was gone. A finished file waits in `Application Support/Swiftpolis/Transfers` under its
  GID, because the system deletes it the moment the delegate call returns.
- **A person force-quitting the app cancels its tasks.** That's iOS's rule. Those Downloads show as stopped, and
  their resume data, if any, was lost.
- **Redirects aren't the app's to decide.** Tasks in a background session follow redirects without asking. So a
  Download with a password or cookies follows them first in an ordinary session, and those headers only go if the
  file is on the same host.
- **Saved paths move.** iOS moves an app's folders when it updates the app, so `moveSavedPaths` rewrites them.
- **Plain HTTP is allowed** with `NSAllowsArbitraryLoads`, as a download manager can't know its links in advance.
  This needs explaining if the app ever goes to App Review.
