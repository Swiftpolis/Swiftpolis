# Feature inventory

The parity checklist. Nothing here is implemented yet. "Mac change" marks a decided replacement
of Persepolis's mechanism.

## Adding downloads

- [ ] Add Link window: link, name, folder, Connections, Start time, End time, Speed dial
- [ ] Add options: proxy (`http`, `socks5`), HTTP auth, referer, user agent, headers, cookie file
- [ ] Choose a Category, or create a Queue from the window
- [ ] "Download later"
- [ ] Warning when the same link was added before
- [ ] Drag and drop links onto the main window
- [ ] Import links from a text file, one per line, into a Queue
- [ ] Import links from the clipboard into a Queue
- [ ] Clipboard monitoring ([D5](upstream-defects.md))
- [ ] Batch window: per-link selection, select all, shared proxy, auth and folder options
- [ ] Spider fills in name and size in the background

## Download control

- [ ] Multi-Connection HTTP and HTTPS, up to 64
- [ ] Pause, resume, stop with control-file resume
- [ ] Stop all active Downloads
- [ ] Retries, timeout, certificate option
- [ ] Speed dial, live
- [ ] Free-space check and "Insufficient disk space" notification
- [ ] Automatic subfolders by file type
- [ ] Unique file names on collision

## Queues and scheduling

Full rules in [queue-and-schedule.md](queue-and-schedule.md).

- [ ] Built-in Categories and user Queues: create, remove, select
- [ ] Start and stop a Queue
- [ ] One active Download per Queue; five Passes
- [ ] Queue Start time, End time, Reverse, Speed dial
- [ ] Queue wait
- [ ] Move items up and down; multi-selection
- [ ] Move items between Categories from the context menu
- [ ] After-download shutdown, for Queue and single Download. Mac change: no root password
- [ ] Per-Download Start time and End time

## Main window

- [ ] Toolbar with actions that change by Category
- [ ] Side panel with Category list and Queue options
- [ ] Table with 11 toggleable columns and saved widths
- [ ] Sort by name, size, status, first try date, last try date
- [ ] Multi-select mode and context menu
- [ ] Double-click to open the file
- [ ] Open file, open folder, open default folder
- [ ] Remove from list; delete files; clear list; move files to another folder
- [ ] Properties window: edit a stopped Download's options
- [ ] Progress window per Download: live labels, controls, Speed dial, After-download shutdown
- [ ] After-download dialog: open file, open folder, "don't show again"
- [ ] Log window with copy and report actions
- [ ] About, Help, Report Issue, new-version check

## Video

Details in [video-and-torrent.md](video-and-torrent.md).

- [ ] Video Finder: format lists, thumbnail, duration, sizes, advanced options
- [ ] Separate video and audio Downloads, then Muxing
- [ ] Mux retry button; pair progress window
- [ ] Single-video links (`.m3u8`)
- [ ] Automatic routing from browser requests

## BitTorrent

In scope, because the baseline is `test`.

- [ ] Magnet links and `.torrent` files
- [ ] File selection; per-file progress; peers
- [ ] Proxy, listen interface, magnet timeout
- [ ] Seeding (unfinished upstream)

## Browser and platform

Details in [browser-integration.md](browser-integration.md).

- [ ] **New:** Safari extension
- [ ] Chrome family and Firefox native messaging, with the existing store extensions
- [ ] Command-line arguments
- [ ] Menu bar item replacing the tray icon, including start hidden
- [ ] Open at login. Mac change: replaces a hand-written LaunchAgent
- [ ] Keep system awake. Mac change: replaces moving the mouse pointer every 20 seconds
- [ ] Notifications with sounds and volume. Mac change: bundled sounds
- [ ] Three rotating log files
- [ ] 18 locales, including right-to-left
- [ ] Editable shortcuts
- [ ] Hide on close; refuse to quit while Downloads are active
- [ ] `--default` and `--clear` reset behaviours

## Not carried over

Linux, BSD and Windows code; Qt styles, icon packs and fonts; `compatibility.py` for versions
below 2.6; dead code such as `queue_prime.py`.
