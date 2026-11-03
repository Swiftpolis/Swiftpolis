# Preferences

Persepolis stores these with `QSettings` under `settings/`. Defaults are from
`returnDefaultSettings()` in `useful_tools.py`. The Mac column says what Swiftpolis does with
each one: native Mac behaviour, without the Qt style settings.

## Download options tab

| Key | Default | UI | Mac |
| --- | --- | --- | --- |
| `max-tries` | 5 | Number of tries | Keep |
| `retry-wait` | 5 | Wait between retries (s) | Keep |
| `timeout` | 10 | Timeout (s) | Keep |
| `connections` | 64 | Number of connections | Keep |
| `chunk-size` | 100 | Chunk size (KiB) | Keep |
| `wait-queue` | `[0, 0]` | Queue wait (h, m) | Keep, as separate hours and minutes |
| `dont-check-certificate` | `no` | Don't verify peers | Keep |

## Torrent tab (`test` branch)

| Key | Default | UI | Mac |
| --- | --- | --- | --- |
| `listen_interface` | `0.0.0.0:6890` | Listen interface | Keep |
| `magnet_timeout` | 30 | Magnet info timeout (s) | Keep |
| none yet | | Seed after download, seeding hours, upload limit | See [Q13](open-questions.md) |

## Save-as tab

| Key | Default | Mac |
| --- | --- | --- |
| `download_path` | `~/Downloads/Persepolis` | Keep |
| `subfolder` | `yes` | Keep |

## Notifications tab

| Key | Default | Mac |
| --- | --- | --- |
| `sound` | `yes` | Keep |
| `sound-volume` | 100 | Keep |
| `notification` | `QT notification` | Replace with system notifications |

## Style tab

| Key | Default | Mac |
| --- | --- | --- |
| `locale` | `en_US` | Keep; system language by default |
| `style`, `color-scheme`, `icons` | Qt values | Replace with light, dark, system |
| `custom-font`, `font`, `font-size` | `no`, `Ubuntu`, 9 | Drop |
| `toolbar_icon_size` | 32 | Drop |

## Behaviour (Style tab in Persepolis)

| Key | Default | UI | Mac |
| --- | --- | --- | --- |
| `after-dialog` | `yes` | Show dialog after download | Keep |
| `show-progress` | `yes` | Show progress window | Keep |
| `tray-icon` | `yes` | Show tray icon | Menu bar item |
| `hide-window` | `yes` | Hide window on close | Keep |
| `show-menubar` | `no` | Show menubar | Drop; Mac apps always have one |
| `show-sidepanel` | `yes` | Show side panel | Drop; the window's own sidebar button does this and remembers it |
| `startup` | `no` | Run at startup | Login item |
| `awake` | `no` | Keep system awake | Keep |
| `check-clipboard` | unset | Check clipboard for links | Keep, off by default; detect link-like content before reading |
| `dont-show-addlinkwindow` | unset | Start browser requests immediately | Keep |
| `browser-persepolis` | `yes` | Browser integration | Keep |
| `video_finder/max_links` | 3 | Max Video Finder windows per request | Keep |

## Columns tab

`column0` to `column7` and `column10` to `column12`, all `yes`: File Name, Status, Size,
Downloaded, Percentage, Connections, Transfer Rate, Estimated Time Left, First Try Date,
Last Try Date, Category.

Swiftpolis has no tab for these. Right-clicking the table's header shows and hides columns, and the
window remembers them.

## Shortcuts tab

| Action | Persepolis | Proposed |
| --- | --- | --- |
| Add new download | Ctrl+N | ⌘N |
| Import text | Ctrl+O | ⌘O |
| Video Finder | Ctrl+V | Needs a new key; ⌘V is Paste |
| Torrent | Ctrl+T | ⌘T |
| Remove from list | Ctrl+R | ⌘R |
| Delete files | Ctrl+D | ⌘D |
| Hide window | Ctrl+W | ⌘W |
| Quit | Ctrl+Q | ⌘Q |
| Move up, down | Ctrl+Up, Ctrl+Down | ⌘↑, ⌘↓ |

## Window state

`MainWindow/size`, `position`, `maximized`, column widths, `remove-queue-warning`, plus size
and position for other windows.

Supported locales in `resources/locales`: 18 translation files, with `fa_IR` and `ar`
right-to-left.
