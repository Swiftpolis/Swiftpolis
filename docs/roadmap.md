# Roadmap

The build order from [Q24](open-questions.md). Each step ends in something that can be tried. The
checklist of features is in [features.md](features.md).

| Step | Delivers | Done when |
| --- | --- | --- |
| 1. Foundation | Project settings, structure, domain types, `@Model` types, repositories, fake clock, test setup | Tests run, and the app launches with the Category list from the store |
| 2. HTTP engine | Parts, Connections, Control file, resume, retries, Speed dial, proxies, subfolders | Engine tests pass against a local server that misbehaves on purpose |
| 3. Main window and Single Downloads | Main table, Add Link, progress, properties, after-download dialog, Preferences basics, menu bar item, notifications. Start and End time fields come with step 4, which adds the clock | A real file can be added, paused, resumed, stopped, and resumed after quitting |
| 4. Queues and schedule | Every rule in [queue-and-schedule.md](queue-and-schedule.md) | Each rule has a test against the fake clock |
| 5. Browsers | Inbox, Safari extension, Chrome and Firefox helper, batch window | A link from each browser arrives in the app with its cookies |
| 6. Video | Helpers, Video Finder, Video pairs, Muxing, single-video links, yt-dlp updates | A YouTube pair downloads and muxes in a notarized build |
| 7. Torrents | libtorrent wrapper, magnet and file flows, file selection; then seeding | A torrent downloads with selected files, then seeds when enabled |
| 8. Release | Persepolis import, 18 languages, shortcuts, remaining windows, notarized DMG | Everything in features.md is ticked |

**Current state:** steps 1 to 6 are built. Step 6's "done when" isn't fully met: see below.

**What step 6 has been through:** in the real app, with the helpers signed and bundled:

- Separate streams from a local server were found, downloaded, muxed with the minimal ffmpeg, and came out as one
  file with both tracks, and the streams removed. The Video Finder, progress and after-download windows were seen in
  snapshots.
- A real Dailymotion video, which is HLS only, downloaded in 18 seconds and came out as a valid mp4.
- YouTube's format list and thumbnail appeared once. Two later tries got its "not a bot" refusal, so **no YouTube pair
  has been downloaded yet.**

The real yt-dlp also ran in tests against a local server: options arriving, stop and resume, and a 404.
Pairs in a Queue, shutdown and failed Muxing have tests with stand-ins, and haven't run in the real app. **No
notarized build exists,** because that needs a Developer ID certificate. Nobody has clicked the buttons yet.

**What step 5 has been through:** a message in the exact browser format went through the real helper, the
shared folder and the wake-up link to the running app, and the test server received the cookies, user agent
and referrer. The batch window and Add Link were seen filled in. Rules and message formats have tests, and the
Safari capture tests run the real script. **No real browser has been used.** Safari needs someone to switch the
extension on, and Chrome and Firefox aren't installed on this Mac. A wake-up was also seen launching the app when
it wasn't running.

**What step 4 has been through:** every Queue and schedule rule has a test against a fake clock, based
on recordings of real Persepolis. A real Queue ran in the app in the right order, and the running and
stopped Queue panels were seen in snapshots. The real shutdown hasn't been run, and the Queue panel's
controls haven't been clicked by anyone yet.

**What step 3's windows have been through,** at the time: automated tests cover the service underneath, including
add, pause, resume, stop, quit, reopen and finish with the real engine and a real store. A real
200 MiB download also ran in the app, and the main table, Add Link, progress and after-download windows
were seen working in snapshots. Killing the app mid-download and relaunching it kept the file, the
control file and the progress. The buttons haven't been clicked by anyone yet, and notifications, sounds,
Preferences, Properties, the menu bar, the quit refusal, open at login and keep awake haven't been seen
running.

## Early checks

These could change the plan, so they happen at the start of the step that depends on them.

| Step | Check |
| --- | --- |
| 2 | Done: record real Persepolis's HTTP behaviour against a local server ([results](persepolis-observed.md)) |
| 2 | Done: one `URLSession` per Connection opens separate connections to an HTTP/2 server |
| 2 | Done: SOCKS5 and authenticated proxies work |
| 4 | **Still open:** shutting down through a system request from an unsandboxed app. It needs someone present, because it really shuts the Mac down |
| 4 | Done: record real Persepolis's Queue Passes, order and clock times ([results](persepolis-observed.md#queues)) |
| 5 | Done: confirm D8 by running the real native-messaging path ([results](persepolis-observed.md#native-messaging)) |
| 5 | **Still open:** the sandboxed Safari handler can write to the App Group and open a `swiftpolis://` link. The unsandboxed helper can |
| 5 | **Still open:** clipboard detection under macOS 27's privacy prompts |
| 6 | Done: yt-dlp self-updates from outside the app, and the signed helpers work ([results](persepolis-observed.md#early-checks-for-video)) |
| 6 | **Still open:** the helpers survive notarization. It needs a Developer ID certificate |
| 6 | **Still open:** a YouTube pair from start to finish. It needs YouTube to answer, or a browser's cookies |
| 7 | libtorrent and Boost build statically for arm64 |
