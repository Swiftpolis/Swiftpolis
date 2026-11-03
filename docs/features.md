# Feature inventory

The parity checklist. A tick means it's built and available in the app. Automated tests cover the rules
behind these, but the windows themselves are checked by hand, so see the note in
[roadmap.md](roadmap.md) for what has been clicked through. "Mac change" marks a decided replacement of
Persepolis's mechanism.

## Adding downloads

- [x] Add Link window: link, name, folder, Connections
- [x] Add Link window: Start time, End time
- [x] Add options: proxy (`http`, `socks5`), HTTP auth, referer, user agent, headers, cookie file
- [x] Choose a Category
- [x] Create a Queue from the Add Link window
- [x] "Download later"
- [x] Warning when the same link was added before
- [x] Drag and drop links onto the main window
- [x] Import links from a text file, one per line, into a Queue
- [x] Import links from the clipboard into a Queue
- [x] Clipboard monitoring ([D5](upstream-defects.md))
- [x] A list of links in a Link field moves to the batch window, in Add Link and Video Finder (new in Swiftpolis)
- [x] Batch window: per-link selection, select all, shared proxy, auth and folder options
- [x] Spider fills in name and size in the background

## Download control

- [x] Multi-Connection HTTP and HTTPS, up to 64
- [x] Pause, resume, stop with control-file resume
- [x] Stop all active Downloads
- [x] Retries, timeout, certificate option
- [x] Speed dial, live
- [x] Free-space check and "Insufficient disk space" notification
- [x] Automatic subfolders by file type
- [x] Unique file names on collision

## Queues and scheduling

Full rules in [queue-and-schedule.md](queue-and-schedule.md).

- [x] Built-in Categories and user Queues: create, remove, select
- [x] Start and stop a Queue
- [x] One active Download per Queue; five Passes
- [x] Queue Start time, End time, Reverse, Speed dial
- [x] Queue wait
- [x] Move items up and down; multi-selection
- [x] Move items between Categories from the context menu
- [x] After-download shutdown, for Queue and single Download. Mac change: no root password
- [x] Per-Download Start time and End time

## Main window

- [x] Toolbar with actions that follow the selected Download's status
- [x] Side panel with Category list
- [x] Side panel Queue options
- [x] Table with 11 toggleable columns and saved widths
- [x] Sort by name, size, status, first try date, last try date
- [x] Multiple selection and context menu
- [x] Double-click to open the file
- [x] Open file, open folder, open default folder
- [x] Remove from list; delete files; clear list; move files to another folder
- [x] Properties window: edit a stopped Download's options
- [x] Progress window per Download: live labels, controls, Speed dial
- [x] Progress window: After-download shutdown
- [x] After-download dialog: open file, open folder, "don't show again"
- [ ] Log window with copy and report actions
- [ ] About, Help, Report Issue, new-version check

## Video

Details in [video-and-torrent.md](video-and-torrent.md).

- [x] Video Finder: format lists, thumbnail, duration, sizes, advanced options
- [x] Separate video and audio Downloads, then Muxing
- [x] Mux retry button; pair progress window
- [x] Single-video links (`.m3u8`)
- [x] Automatic routing from browser requests

## BitTorrent

In scope, because the baseline is `test`.

- [ ] Magnet links and `.torrent` files
- [ ] File selection; per-file progress; peers
- [ ] Proxy, listen interface, magnet timeout
- [ ] Seeding (unfinished upstream)

## Browser and platform

Details in [browser-integration.md](browser-integration.md).

- [x] **New:** Safari extension
- [x] Chrome family and Firefox native messaging, with the existing store extensions
- [ ] Command-line arguments
- [x] Menu bar item replacing the tray icon
- [ ] Start hidden in the menu bar
- [x] Open at login. Mac change: replaces a hand-written LaunchAgent
- [x] Keep system awake. Mac change: replaces moving the mouse pointer every 20 seconds
- [x] Notifications with sounds and volume. Mac change: bundled sounds
- [ ] Three rotating log files
- [ ] 18 locales, including right-to-left
- [ ] Editable shortcuts
- [x] Hide on close; refuse to quit while Downloads are active
- [ ] `--default` and `--clear` reset behaviours

## Not carried over

Linux, BSD and Windows code; Qt styles, icon packs and fonts; `compatibility.py` for versions
below 2.6; dead code such as `queue_prime.py`.
