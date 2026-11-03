# Persepolis data model

The source schema from `persepolis/scripts/data_base.py`. Swiftpolis imports this data once
when you first switch, and keeps the Control file format so partial downloads can resume. The
Swift model isn't designed yet. Everything is stored as text unless noted, including numbers and
`yes`/`no` flags.

## `persepolis.db`, the main database

**`category_db_table`**: one row per Category.

| Column | Meaning |
| --- | --- |
| `category` | Name, primary key. Renames and deletes cascade |
| `start_time_enable`, `start_time` | Flag and `H:M` |
| `end_time_enable`, `end_time` | Flag and `H:M` |
| `reverse` | Run oldest first |
| `limit_enable`, `limit_value` | Stored but superseded by the Speed dial |
| `after_download` | After-download flag |
| `gid_list` | Ordered GIDs, a serialised list |

**`download_db_table`**: what the table shows, one row per Download.

`file_name`, `status`, `size`, `downloaded_size`, `percent`, `connections`, `rate`,
`estimate_time_left`, `gid` (primary key), `link`, `first_try_date`, `last_try_date`,
`category`. Size and rate columns are **formatted display strings** like `1.5 GiB`, and
`***` means unknown.

**`addlink_db_table`**: a Download's options, one row per Download.

`gid`, `out` (name), `start_time`, `end_time`, `link`, `ip`, `port`, `proxy_user`,
`proxy_passwd`, `proxy_type`, `download_user`, `download_passwd`, `connections`,
`limit_value`, `download_path`, `referer`, `load_cookies` (a file path), `user_agent`,
`header`, `after_download`. **Passwords are in plain text.**

`download_path` is a folder until completion and the final file path afterwards.

**`video_finder_db_table`**: one row per video and audio pair.

`video_gid`, `audio_gid`, `video_completed`, `audio_completed`, `muxing_status`, `checking`,
`download_path`.

**`video_finder_db_table2`**: live yt-dlp progress per Download.

`gid`, `download_status`, `file_name`, `eta`, `download_speed_str`, `downloaded_size`,
`file_size`, `download_percent`, `fragments`, `error_message`.

**`torrent_db_table`**: `test` branch.

`gid`, `files_list`, `selected_files_list`, `is_dir`, `type` (magnet or file),
`download_limit`, `upload_limit`, `seeding`.

## `temp.db`, shutdown coordination

- **`single_db_table`**: `gid`, `status` (active or deactive), `shutdown`.
- **`queue_db_table`**: `category`, `shutdown`.

`shutdown` is `wait`, `shutdown` or `canceled`. Pair shutdowns use a `video_finder_<gid>` key.

## `plugins.db`, the Browser request inbox

**`plugins_db_table`**: `link`, `referer`, `load_cookies`, `user_agent`, `header`, `out`,
`status`. The native-host process writes here and the running app drains it.

## Concurrency

Each database object has a hand-rolled boolean lock. Callers spin on it. Background threads
also use module-level flags (`checking_flag`, `shutdown_notification`) to pause polling
during remove, delete and sort.

## Files on disk

Config folder on macOS: `~/Library/Application Support/persepolis_download_manager/`.

- The databases above
- `initialization_log_file.log`, `downloads_log_file.log`, `errors_log_file.log`. A log over
  300 lines is trimmed to the last 200 at launch
- `persepolis_tmp/`, including the `persepolis-plugin-ready` and show-window flag files
- Notification sounds (`ok`, `fail`, `warning`, `queue`), downloaded from GitHub if missing

## The Swiftpolis model

`SwiftpolisKit/Sources/SwiftpolisPersistence/LibrarySchema.swift` holds the versioned schema, now at
version 2: `CategoryRecord`, `DownloadRecord` and `VideoPairRecord`. Version 2 added the pair record and a
Download's engine, by lightweight migration, and a test opens a real version 1 store. Version 1's types stay in
the file, unchanged, because migration needs them. Torrent records arrive in the step that needs them. Views and ViewModels only ever see the plain summaries a repository
returns ([ADR 0005](adr/0005-repositories-behind-viewmodels.md)).

How it differs from the Persepolis schema:

- **Order is explicit.** `gid_list` becomes `categoryPosition` and `allDownloadsPosition`, because
  relationships have no order and a Download has one place in each list. Lists show the highest
  position first, matching Persepolis's newest-first table. Sorting All Downloads changes only the
  second.
- **All Downloads has no stored members.** It lists every Download.
- **A Video pair holds only its two GIDs and the Muxing status.** Whether a stream is finished comes from its own
  status, so `video_completed` and `audio_completed` have no column to disagree with it. `checking` becomes the
  coordinator's in-memory run. `video_finder_db_table2` isn't stored at all, because a snapshot does its job.
- **No display strings.** Sizes are stored in bytes, and an unknown size or name is `nil` rather
  than `***`.
- **Live rate, ETA and Connections aren't stored.** Persepolis polls five times a second and writes
  about once a second. Swiftpolis keeps these in memory.
- **No passwords or cookies.** Proxy and site user names are stored, and their secrets go in the
  Keychain.
- **Times are minutes since midnight**, not `H:M` text. Import has to convert them.
- **Dropped:** `limit_enable` and `limit_value` on Categories, which the Speed dial superseded.
