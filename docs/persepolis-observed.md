# Observed Persepolis behaviour

What the real HTTP engine and Queue thread did when run, unmodified, against a local server that
misbehaves on purpose. This is the reference for the Swift tests. Where it disagrees with the other
docs, this wins.

- **Code:** Persepolis `test` at `8940bcf`, using its own `venv` (Python 3.12, requests 2.32.5).
- **Date:** 3 November 2026.
- **To repeat it:** [`observe_http_engine.py`](../tools/persepolis-characterization/observe_http_engine.py)
  and [`observe_queue.py`](../tools/persepolis-characterization/observe_queue.py).
- **Limits:** the main window was faked, so nothing here covers the real UI. The Queue scenarios use the
  real Queue thread, engine and database, with a copy of the thread that writes live status to the
  database. Everything was on loopback, so real-network timing will differ.

## What matched the reading of the code

| Behaviour | Observed |
| --- | --- |
| 64 MiB or larger, 64 Connections | 64 Parts; 61 requests running at once when the server was slow |
| Smaller file | One Part per started MiB (10 MiB gives 10) |
| Unknown size | 1 Part, 1 Connection, status `complete` |
| Empty file | `complete`, 0 bytes |
| Request headers | Basic auth, referer, user agent and custom headers go on both HEAD and GET |
| Cookie file | Only cookies matching the host are sent |
| Range | `bytes=<start>-<end>`, with an inclusive end |
| Default user agent | `PersepolisDM/5.2.0` |
| Redirect to another host | Followed, and `Authorization` is dropped |
| Stop, then start again | Resumes: only the unfinished ranges are requested, and the file is intact |
| Control file | Keys `ETag`, `download_infromation_list`, `file_name`, `file_size`, `number_of_parts`; always 64 entries, with the unused ones marked `complete` |
| ETag changed since stopping | Starts again as `file_1.bin`; the old partial file and its control file stay |
| Subfolders | `song.MP3` to `Audios`, `clip.mkv` to `Videos`, `book.pdf` to `Documents`, `data.zip` and `old.Z` to `Compressed`, no extension to `Others` |

### Unique names at the destination

| Existing | New | Result |
| --- | --- | --- |
| `long.bin` | `long.bin` | `long_1.bin` |
| `long.bin`, `long_1.bin` | `long.bin` | `long_2.bin` |
| `x_1.bin` | `x_1.bin` | `x_2.bin` |
| `long_9.bin` | `long_9.bin` | `long_10.bin` |
| `noext` | `noext` | `noext_1` |

### How many requests a failure takes

A server that always returned 503, with `retry-wait` at 0:

| `max-tries` | GET requests |
| --- | --- |
| 1 | 4 |
| 2 | 9 |

So each Part gets `max-tries + 1` attempts, and each attempt makes `max-tries + 1` requests. The
default of 5 means 36 requests for a failing Part. Those inner retries back off using `retry-wait`.

## New defects found by running it

All are in [upstream-defects.md](upstream-defects.md).

- **D19, a false `error`.** A download that finishes before the last worker has started is reported
  as `error`, even though the file is intact. Workers start 0.1 seconds apart, so this affects
  anything finishing within `Connections × 0.1` seconds. It happened on most fast runs, including all
  three runs of a 128 MiB file (`percent: 99`, control file left behind).
- **D20, a request loop.** A server returning 404 with a short body was asked again forever: 115,564
  requests in 90 seconds, never ending by itself. A short read doesn't count as an attempt.
- **D21, resume lost by stopping early.** Stopping before the first control-file write (up to
  `Connections × 0.1` seconds in) leaves an empty control file, so the next run fetches everything
  again. The run observed had downloaded 4 MB and fetched the full 42 MB again.
- **D22, silent corruption without an ETag.** With no ETag, a changed file size is not noticed: the
  control file's `ETag` key exists holding `null`, which equals the new `null`. A file that shrank from
  40 MiB to 30 MiB "resumed", reached 112%, and left a damaged 40 MiB file.
- **D23, off by one.** The last Part counts one byte too few, so `downloaded_size` ends one short.

## Earlier suspicions, tested

| ID | Claim | Result |
| --- | --- | --- |
| D4 | Small files override Connections | **Confirmed.** 4 requested, 10 used. Resuming also ignores the Part count (64 workers for 40 Parts) |
| D6 | Authenticated proxy URL is malformed | **Confirmed.** `http://me:pw@://127.0.0.1:9`, ending in `Request error` |
| D7 | Quotes kept in file names | **Confirmed.** Saved as `"report.pdf"`, with the quotes. Worse, `filename*=` produced a file literally named `attachment; filename*=UTF-8''r%C3%A9sum%C3%A9.pdf` |
| D12 | Shared `Range` header could corrupt Parts | **Not reproduced.** Three runs with 61 requests at once all gave 64 distinct ranges and intact files. The race remains possible in the code |
| D13 | No range support still runs every worker | **Confirmed.** A 4 MiB file cost 16 MiB of transfer. The result is intact only because each worker writes the same bytes |
| D14 | Missing comma in the document list | **Confirmed.** `book.mobi` and `book.pub` went to `Others` |
| D15 | Mixed-case archive extensions can't match | **Mostly wrong.** `old.Z` did reach `Compressed`, because lowercase `z` is also listed. Only `.f` is affected |
| D16 | One-character names crash on collision | **Confirmed.** `IndexError`, and the file stays outside its subfolder |

D2 and D9 are confirmed under [Queues](#queues), and D8 under [Native messaging](#native-messaging). D3
and D5 are UI wiring.

## Other details

- `#HttpOnly_` lines in a cookie file aren't used, because the prefix is taken as part of the domain.
- A failed HEAD that still returns headers doesn't stop the download. A 405 with `Content-Length` went
  on to finish normally.
- `error_message` isn't cleared: a download with no `Content-Length` can finish as `complete` and still
  carry the message `Error`.

## Queues

Files were added `a`, then `b`, then `c`, each on one Connection.

| Scenario | Observed |
| --- | --- |
| Default order | `c, b, a`, newest first, with never more than one request at a time |
| Reverse | `a, b, c` |
| `b` always fails, `max-tries` 0 | Requests in order: `c, b, a, b, b, b, b`, so five tries. `b` ends `error`, and the notification is still "Queue completed!" |
| Added while running | `a` finishes, then `late` runs on the next Pass |
| Stopped by the user | Only `c` ever ran, and "Queue Stopped!" appeared about 2 seconds later |
| Already complete | Skipped, with no requests |
| Empty Queue | "Queue completed!" straight away |
| Reverse changed during a run | The next Pass used the new order (`b, a, a, b, a, b, ...`). It's read live from the window's check box, which is D9 |
| Speed dial | Applied at the start (sleep 0.025 s at dial 5, one Connection), and again when moved (0.05 s at dial 0) |
| Time per item | About 4 seconds per 1-second file, which includes the Queue's own 3 second sleep |

### Clock times

| Scenario | Observed |
| --- | --- |
| Start time | The first unfinished item shows `scheduled`, and the rest stay `stopped` with no Start time. The first request came 1.9 seconds into the chosen minute, and the stored time was then cleared |
| End time | Set on each item as it starts. At the minute, the item stopped and the Queue ended 3.2 seconds in. The next item never ran. **Both** "Queue Stopped!" and "Queue completed!" appeared, which is D29 |
| Finishing before the End time | **D2 confirmed.** The Queue finished with the item `complete`, but one session stayed open. At the End time, the item flipped to `stopped`, even though its file was finished |
| Queue wait of 1 minute | First request at 07:26:08, second at 07:27:01: it lands on the clock minute |

### After-download shutdown

- A finished Queue sets the shutdown request, and notifies "your system in 20 seconds", then "Queue completed!".
- Stopping the Queue clears the check box, and no request is made.
- From reading `queue.py`: an End-time stop leaves `start` set, so a requested shutdown still happens.

The real shutdown wasn't run, because `shutDown()` needs a root password and would turn the Mac off.

## Native messaging

From [`observe_native_host.py`](../tools/persepolis-characterization/observe_native_host.py), which sends
the real program the exact message its extension sends.

**D8 confirmed.** The extension sent `"cookies": "session=abc123; theme=dark"`, and what Persepolis stored
for the Add Link window has `load_cookies: null`, with no cookies anywhere. The URL, referrer and user agent
all came through. The reply was `{"enable": true, "version": "1.85"}`.

## yt-dlp's options

Run with Persepolis's own `venv` (yt-dlp 2025.11.12), against a local server that logs each request. Persepolis's
option names and the real ones were each given the same values.

| Options | Cookie | Referer | User agent |
| --- | --- | --- | --- |
| Persepolis's (`cookies`, `referer`, `user-agent`) | none | none | yt-dlp's default Chrome string |
| The real ones (`cookiefile`, `http_headers`) | sent | sent | sent |

So **D31 is confirmed.** The options that do work are `retries`, `socket_timeout`, `outtmpl`, `noplaylist`, `proxy`,
`username` and `password`.

## Early checks for Video

Run with the helpers signed for the hardened runtime, the way the app ships them.

| Check | Result |
| --- | --- |
| Signed helpers run | **Yes.** yt-dlp takes 12 s on its first start and about 5 s after, because it unpacks itself each time. Deno runs |
| yt-dlp updates itself outside the app | **Yes.** 2026.10.21, as downloaded, updated itself to 2026.10.26 from a plain folder. The result is ad-hoc signed, has no quarantine flag and runs. A second `--update` says it's up to date |
| The minimal ffmpeg remuxes | **Yes.** mp4 with m4a, webm with webm into mkv, and both mixed combinations came out with the right codecs |
| The minimal ffmpeg fixes up HLS | **Yes.** With nothing else on `PATH`, a real HLS stream came out as a valid mp4 |
| Progress lines | One JSON object a line. Fragmented streams give `fragment_index`, `fragment_count` and `total_bytes_estimate`, and plain ones `total_bytes` |
| A direct stream link | **Works,** which is how Persepolis uses it. yt-dlp's generic extractor takes the HLS playlist link |
| YouTube without a login | **Comes and goes.** The same Mac got "Sign in to confirm you're not a bot" and, later, a full format list with Best quality, then the refusal again |
| Vimeo, SoundCloud | Vimeo asks for a login. The SoundCloud link tried was a 404 |
| Dailymotion | **Works.** Two combined `m3u8_native` formats, with no separate streams |

**Not yet checked:** that the helpers survive notarization, because this Mac has no Developer ID certificate.

## Early checks for the Swift engine

Run on the same day with throwaway programs.

| Check | Result |
| --- | --- |
| One `URLSession` per Connection | **Works.** Six requests on a shared session used one HTTP/2 connection. Six sessions used six local ports |
| Slow reader in the data delegate | **Memory stays bounded,** at about 23 MB against a fast 2 GiB source. Holding the delegate queue slows the transfer. Chunks arrived at about 2 MiB each on loopback |
| `URLSessionTask.suspend()` for Pause | **Doesn't work.** Data kept arriving at the same rate while suspended, so Pause holds the delegate queue instead, as Persepolis holds its workers |
| `ProxyConfiguration` with credentials | **Works** for HTTP and SOCKS5, for `http` and `https`; the proxy logged the credentials and the target |
| `ProxyConfiguration` on loopback | **Bypasses the proxy,** so automated tests can't use it against a local server |
| `ProxyConfiguration` and plain `http` | **Always uses `CONNECT`,** even to port 80, where Persepolis sends an ordinary proxied `GET`. Proxies often refuse `CONNECT` to port 80 |
| `connectionProxyDictionary` and plain `http` | **Sends an ordinary proxied `GET`,** matching Persepolis |
| The finished engine against a real server | **Works.** A 10 MiB file from `proof.ovh.net` (HTTP/2, HTTPS) matched `curl`'s SHA-256 directly, through an HTTP proxy and through SOCKS5. The proxies logged the credentials, and 9 connections per run: 1 HEAD and 8 Connections |
