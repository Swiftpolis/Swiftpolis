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

## Modelling issues for SwiftData

To handle in the Swift model ([ADR 0005](adr/0005-repositories-behind-viewmodels.md)):

- **Order matters and to-many relationships are unordered.** `gid_list` needs an explicit
  position, and a Download has one position in its Category and one in All Downloads. Sorting
  All Downloads changes only the second.
- **Display strings should not be persisted.** Store bytes and derive labels.
- **Live progress should not go through the store** at UI rate. Persepolis polls five times a
  second and writes about once a second.
- **Credentials belong in the Keychain**, not model fields.
