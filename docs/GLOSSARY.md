# Swiftpolis

A macOS download manager that reproduces Persepolis's download, queue and schedule behaviour natively.

## Language

### Downloads

**Download**:
One item in the list: a thing to fetch, its options, and its current status.
_Avoid_: Task, job, item, link

**GID**:
The 16-character hex identifier of a Download.
_Avoid_: ID, UUID

**Status**:
Where a Download is in its life: waiting, scheduled, creating download file, downloading, paused, stopped, error or complete.
_Avoid_: State

**Part**:
A fixed byte range of a file, tracked separately so it can be resumed. A file has at most 64.
_Avoid_: Chunk, segment

**Connection**:
A worker that fetches one Part at a time. A Download's Connection count is separate from its Part count.
_Avoid_: Thread

**Control file**:
The `<file name>.persepolis` file beside a partial download that records its Parts for resuming.
_Avoid_: Metadata file, state file

**Spider**:
The lightweight request that learns a Download's file name and size without fetching it.
_Avoid_: Probe, preflight

### Organising

**Category**:
A named group in the side panel. Every Category is either a built-in list or a Queue.
_Avoid_: Folder, group

**All Downloads**:
The built-in Category listing every Download. Nothing is started from it.

**Single Downloads**:
The built-in Category of Downloads controlled one by one, not by a Queue.

**Queue**:
A Category whose Downloads run one at a time and are started and stopped together.
_Avoid_: Batch, playlist

**Scheduled Downloads**:
The default Queue, which cannot be removed.

**Pass**:
One run through a Queue's Downloads from first to last. A started Queue makes up to five.
_Avoid_: Retry, round

### Time and limits

**Start time**:
A clock time, without a date, at which a Download or Queue begins.
_Avoid_: Schedule date

**End time**:
A clock time, without a date, at which an active Download or Queue is stopped.
_Avoid_: Deadline

**Queue wait**:
The configured pause before each Download in a Queue except the first.
_Avoid_: Delay, gap

**Speed dial**:
The 0 to 10 control that slows a Download. It is a relative setting, not a rate in bytes per second.
_Avoid_: Bandwidth limit

**After-download shutdown**:
The request to shut the Mac down once a Download or Queue finishes.
_Avoid_: Auto power-off

### Media and browser

**Video Finder**:
The feature that lists a page's video and audio formats and downloads the chosen pair.
_Avoid_: YouTube downloader

**Video pair**:
The two linked Downloads, one video stream and one audio stream, that Muxing combines. They move, delete and resume together.
_Avoid_: Video finder item, dual download

**Single-video link**:
A Download fetched as one stream by yt-dlp, such as an `.m3u8`, with no muxing step.
_Avoid_: HLS download

**Muxing**:
Combining a downloaded video stream and audio stream into one file without re-encoding.
_Avoid_: Merging, converting

**Torrent download**:
A Download fetched over BitTorrent from a magnet link or `.torrent` file.

**Seeding**:
Uploading a finished Torrent download to other peers.

**Browser request**:
A set of links with their referrer, user agent and cookies, sent from a browser extension to the app.
_Avoid_: Plugin call
