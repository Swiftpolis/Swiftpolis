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

**The helpers Swiftpolis ships:** `tools/fetch-helpers.sh` downloads yt-dlp and Deno at pinned versions with
checked hashes, and builds ffmpeg from source with `--disable-everything`, then only the demuxers, muxers,
parsers, decoders and bitstream filters that remuxing needs. It uses no GPL or non-free options, so the result is
LGPL. The binary is under 4 MB. An `Embed Helpers` build phase copies all three to `Contents/Helpers` and signs
them with the hardened runtime and the entitlements in `Helpers/`.

### How Swiftpolis does it

**yt-dlp runs as a program.** `YtDlpEngine` starts it with `--progress-template "download:%(progress)j"`, and
reads one JSON line per update. Everything but the link goes in a config file only this user can read, in a
private temporary folder that's deleted afterwards, because a command line can be read by every process on the
Mac. The link comes last, after `--`, so a link can't be taken for an option. Stopping sends an interrupt, then
a terminate after 3 seconds, then a kill after 5 more.

**A finished Download's file:** if a finished file of that name is already there, the Download takes a new name.
A `.part` file stays, and is resumed. yt-dlp saves its cookies back over the file it read, so it only ever gets a
copy of the user's cookie file.

**Which engine:** a name ending in `.m3u8`, or any format that isn't a plain HTTP stream, goes to yt-dlp. A plain
combined format goes to the HTTP engine, with its Parts and Pause. Both streams of a pair always go to yt-dlp.

**A pair runs as one job.** `DownloadCoordinator` holds one run per pair, from its first stream to the end of
Muxing, and a second start is refused. Whether a stream is finished comes from its status, so Persepolis's
`video_completed` and `audio_completed` flags aren't stored. Stopping either stream stops the pair.

**In a Queue,** the streams are ordinary items, so the newer one runs first, which is the audio, as in Persepolis.
When the second finishes, Muxing runs before the Queue goes on, and before its 3-second minimum runs out.

**Muxing** writes to `Videos` if the Download was in the default folder with subfolders on. Otherwise it writes to
the Download's folder. On success, both stream files and the audio row go, and the video row becomes the finished
file. On failure both stay, and Start Mixing or Resume tries again without fetching anything. Any half-written
output is deleted, so it can't take the name from the next try. Muxing cut off by quitting counts as failed.

**yt-dlp updates.** `HelperInstallation` checks at most once a day, in the background. It copies the bundled
yt-dlp to `Application Support/Swiftpolis/Helpers` if there's no copy, or if the app has brought a newer version,
then runs `--update` on the copy. A copy that no longer runs is deleted, which puts the bundled one back in use.
A failed update, with no network say, leaves the copy as it was.

**Where it differs from Persepolis on purpose:** see D31 to D38 in [upstream-defects.md](upstream-defects.md). Also:

- The speed dial isn't shown for yt-dlp Downloads. In Persepolis it's there and does nothing.
- Changing the format no longer replaces a name the user has typed.
- A storyboard isn't offered as a video format.
- "Worst quality" and "Best quality" mark the ends of the combined list, rather than of all formats.

**YouTube can refuse this.** From here it sometimes answers "Sign in to confirm you're not a bot", and sometimes
lists every format, a few minutes apart. Video Finder shows the message as it stands. Cookies from a browser
request, or a cookie file in Advanced, go to the extraction as well as the download, which is yt-dlp's documented
answer to this.

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
