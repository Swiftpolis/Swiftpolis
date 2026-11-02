# Video Finder and BitTorrent

## Video Finder

`video_finder_addlink.py`, `video_finder.py`, `ytdlp_downloader.py`, `useful_tools.muxer`.

**Flow**

1. The user enters a URL. `yt_dlp.YoutubeDL.extract_info` runs in a background thread.
2. The window shows title, thumbnail and duration, with format lists for combined media,
   video only and audio only, plus estimated sizes.
3. Choosing separate streams creates **two linked Downloads**, the video first.
4. `VideoFinder` runs video, then audio, then muxes with
   `ffmpeg -i video -i audio -c copy -shortest -map 0:v:0 -map 1:a:0 -loglevel error -strict -2 output`.

**Pair rules**

- In Single Downloads, `VideoFinder` starts each stream itself. In a Queue, the Queue starts
  them and `VideoFinder` only watches.
- A Start time applies only to the video stream.
- Completion flags are stored, so resuming skips a finished stream.
- If muxing fails, a Mux button retries it for that Download.
- Removing, deleting or moving one stream acts on both.
- After-download shutdown waits for muxing to finish.

**Browser routing:** a link containing one of these goes to Video Finder instead of Add Link,
up to `settings/video_finder/max_links` per Browser request (default 3). Extra links are
handled as normal links.

`youtube.com/watch`, `aparat.com/v/`, `vimeo.com/`, `dailymotion.com/video`, `https://soundcloud.com/`

**Single-video link:** a name ending in `.m3u8` is downloaded by yt-dlp as one Download, with
fragment counts in place of Connections and an estimated size.

**yt-dlp options used:** `noplaylist`, retries from `max-tries`, socket timeout from `timeout`,
`continue_dl`, cookies, referer, user agent, proxy, certificate check.

**The port constraint:** Persepolis imports yt-dlp as a Python library. Swift cannot, so
Swiftpolis runs yt-dlp as a separate program and parses its output
([ADR 0003](adr/0003-bundle-non-swift-helpers.md)).

**Helper facts, checked 2026-11-03:**

- `yt-dlp_macos` (2026.10.26) is a universal binary with an arm64 slice, about 37 MB. A
  `yt-dlp_macos.zip` is also published.
- yt-dlp [needs a JavaScript runtime for full YouTube support](https://github.com/yt-dlp/yt-dlp/issues/15012).
  Without one, available formats may be limited. Official executables already include the
  `yt-dlp-ejs` component. [Deno is the recommended runtime](https://github.com/yt-dlp/yt-dlp/wiki/EJS)
  and can be set with `--js-runtimes deno:/path/to/deno`. The arm64 Deno 2.9.8 zip is 39 MB.
  Swiftpolis bundles it ([ADR 0003](adr/0003-bundle-non-swift-helpers.md)).
- The `mac-package-build` script downloads ffmpeg from evermeet.cx, which a
  [2022 mailing-list post](https://ffmpeg.org/pipermail/ffmpeg-user/2022-May/054888.html) says
  builds for Intel only. If still true, it would hit the same Rosetta deadline. Not confirmed for
  current builds. Swiftpolis builds its own minimal copy instead.
- Persepolis uses ffmpeg only to remux, so no encoders are needed.
- Homebrew's ffmpeg is GPL-3.0-or-later, and libtorrent-rasterbar is BSD-3-Clause. Both are
  compatible with a GPLv3 app.

## BitTorrent

`libtorrent_wrapper.py`, `addtorrent.py`, `addmagnet.py`, `torrent_progress.py`. **`test`
branch only; `master` has none of it.**

**Adding**

- A magnet link is resolved to metadata first, limited by `magnet_timeout` (default 30 s).
- A `.torrent` file is read directly.
- The window shows the files. The user selects which to download, and sees the total size.
- Selected files, folder flag, source type, limits and a seeding flag go in `torrent_db_table`.

**Downloading**

- Listens on `listen_interface` (default `0.0.0.0:6890`).
- Honours proxy (`socks5` or `http`, with or without auth) and user agent.
- The Connections column shows peers.
- The progress window has a per-file table.
- A torrent with folders ends up under `Torrent folders`.
- Pause, resume, stop, Start time, End time and speed limit follow the same session shape as
  HTTP.

**Seeding is unfinished.** `TorrentSeed` exists and Preferences has options for seeding after
download, seeding hours and an upload limit, but `mainwindow.py`, `addtorrent.py` and
`properties.py` never reference `TorrentSeed` or seeding. The last commits on `test` are still
adding this. It is a feature with UI and no working path. The intended behaviour, from those
pieces: seeding starts when a download finishes, the Download's status is `complete` when not
seeding, and a per-torrent `seeding` flag can stop it. Swiftpolis builds this after torrent
downloading, off by default ([Q13](open-questions.md)).

**The port constraint:** libtorrent is C++, with a Boost dependency. Swiftpolis builds it from
source and reaches it through a small Objective-C++ wrapper
([ADR 0008](adr/0008-libtorrent-behind-objective-cpp-wrapper.md)).
