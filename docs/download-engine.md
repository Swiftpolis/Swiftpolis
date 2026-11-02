# HTTP download engine

What `persepolis/scripts/persepolis_lib_prime.py` does. It supports HTTP and HTTPS only.
FTP left with aria2, even though the browser extension still matches `ftp://` pages.

## Lifecycle

```
start
 ├─ create session (proxy, auth, cookies, referer, user agent, headers)
 ├─ status = scheduled if Start time, else waiting
 ├─ wait for Start time, if any
 ├─ status = creating download file
 ├─ HEAD with redirects → size, name, ETag, range support
 │    └─ no headers at all → status = error
 ├─ start End time thread, if any
 ├─ create or reuse control file and preallocate the file
 ├─ status = downloading
 ├─ define Parts, start speed loop, start Connections, start control-file writer
 └─ monitor until every Part is complete, all workers end, or status changes
close
 └─ if complete: delete control file, move into subfolder, store the final path
```

Status values: `waiting`, `scheduled`, `creating download file`, `downloading`, `paused`,
`stopped`, `error`, `complete`.

## Request setup

| Input | Behaviour |
| --- | --- |
| Proxy | `http` or `socks5`, optional user and password. **Defect D6** affects authenticated proxies |
| HTTP auth | Basic, from download user and password |
| Cookies | Netscape `cookies.txt` file path. Only 7-field lines are used |
| User agent | Given value, otherwise `PersepolisDM/<version>` |
| Certificates | Verified unless `dont-check-certificate` is `yes` |
| Retries | Transport retries on 429, 500, 502, 503, 504 for HEAD, GET and OPTIONS, with backoff factor `retry-wait` |

## File name

Priority: user-supplied name, then `Content-Disposition` `filename=`, then the last path
component of the percent-decoded URL. Only plain `filename=` is parsed, so RFC 5987
`filename*=` is not understood. **Defect D7** covers surrounding quotes.

If the control-file path is too long for the file system, the name is shortened and the
control file retried.

## Parts

Always described by a list of 64 entries: `[start byte, downloaded bytes, status, retry count]`.
Part status is `pending`, `downloading`, `stopped`, `error` or `complete`. Retry count
starts at `-1`.

| File | Parts | Connections |
| --- | --- | --- |
| Size known, `size // 64 >= 1 MiB` | 64 of `size // 64`; the last takes the remainder | As configured (default 64) |
| Size known, smaller | One per started MiB | Overridden to the Part count. **Defect D4** |
| Size unknown | 1 (open-ended range) | 1 |

Unused entries are marked `complete` and ignored.

## Workers

Each Connection loops:

1. Ask for the first Part that is not `complete` or `downloading` and whose retry count
   has not reached `max-tries`. Exit if there is none.
2. Send `Range: bytes=<start + downloaded>-<end>` and stream it.
3. Write at the right offset, in `chunk-size` KiB reads (default 100).
4. If a full-size read comes back short, drop out and fetch that Part again. This does not
   count as a retry.
5. Mark the Part `complete` when downloaded bytes equal Part size, otherwise `error`.

Connections start 0.1 seconds apart to avoid "Connection refused". The Download is
`complete` when every Part is, and `error` when workers run out while it is still
downloading or paused.

## Control file

`<file name>.persepolis`, next to the file, rewritten every second while the Download is
active:

```json
{
  "ETag": "...",
  "file_name": "...",
  "file_size": 123,
  "number_of_parts": 64,
  "download_infromation_list": [[0, 1024, "pending", -1]]
}
```

The misspelt key is the real one.

## Resuming and collisions

When a control file already exists:

- If it has an `ETag` key, compare it. Otherwise compare `file_size`.
- Match: resume, if the server sends `Accept-Ranges: bytes` and the file exists.
- Mismatch, with the file present: rename using `_1`, `_2` and so on, then start fresh.
- Unreadable control file: start from the beginning.

On resume, Parts that are not `complete` become `pending` with retry count `-1`.

Pause keeps workers connected and holds them in a 0.2 second loop. Stop ends them and
leaves the control file for a later resume.

## Preallocation

A new file with a known size is filled with zeros, 1 MiB at a time, if free space allows.
Stopping during this deletes the file. Not enough space means status `error`, and the main
window then raises an "Insufficient disk space" notification.

## Speed

- **Reported rate and ETA:** recalculated every 2 seconds.
- **Speed dial:** `sleep = (10 - dial) × 0.005 × active Connections` seconds after every
  chunk. Dial 10 is no delay. Because the delay scales with Connections, the total ceiling works
  out at about `chunk size ÷ ((10 - dial) × 5 ms)`: at the default 100 KiB, roughly 2 MiB/s at
  dial 0 and 20 MiB/s at dial 9. The network can hold it below that. The port keeps this formula,
  so it has to pace by `chunk-size` rather than by whatever `URLSession` delivers.

## On completion

Subfolders apply only if the Download's folder equals the default download folder and
`subfolder` is `yes`. Otherwise the file stays where it is.

| Subfolder | Chosen by |
| --- | --- |
| `Audios` | Audio extensions |
| `Videos` | Video extensions, or a file named `videoplayback` |
| `Documents` | Document extensions |
| `Compressed` | Archive extensions |
| `Others` | Everything else |

The full extension lists are in `findDownloadPath()`. `Torrent folders` is also created
for torrents. Name collisions at the destination get `_1`, `_2` and so on. A failed move
keeps the file in place and logs an error. The Download's stored path becomes the final
file path, not a folder.

## Reporting

`tellStatus()` returns display strings for name, status, size, downloaded, percent, active
Connections, rate, ETA, link and error. Main-window polling:

- Every 0.2 seconds: read all active sessions and update the UI.
- About once a second, or when a session has just finished: write to the database.

## Spider

`spider.py` sends a HEAD with the same session options to fill in name and size when a
Download is added without starting. Failures are ignored. Unknown values show as `***`
until a Download starts.

## Port notes

Decided in [ADR 0002](adr/0002-port-engine-to-urlsession.md): `URLSession`, one session per
Connection. `requests` always uses HTTP/1.1, so 64 workers means 64 TCP connections, whereas
`URLSession` negotiates HTTP/2 and would multiplex a shared session onto one connection.

Still to verify in the first engine spike:

- That a session per Connection really produces separate connections against an HTTP/2 server.
- Proxy authentication and SOCKS5 through `ProxyConfiguration`.
