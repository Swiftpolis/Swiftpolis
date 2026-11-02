# Architecture

**Draft.** Records the agreed direction (Swift, SwiftUI, SwiftData, MVVM, macOS first). Details
that depend on [open questions](open-questions.md) are marked.

**Build targets:** macOS 27.0, Apple silicon only, Swift 6 language mode, App Sandbox off for the
main app.

**Testing:** tests are written first, with Swift Testing, for rules and engines. Views are checked by
running the app. Before steps 2 and 4, the riskiest scenarios are run against real Persepolis and
recorded, and those results become the reference for the Swift tests.

## Layers

```
View (SwiftUI)                 renders state, sends user intents; no business rules
   │ owns
ViewModel (@Observable)        UI state, maps domain values to labels, @MainActor
   │ calls
Services (actors)              Download, Queue, Schedule, Shutdown, Browser, Video, Torrent
   │ uses
Repositories (@ModelActor)     all SwiftData reads and writes
Engines                        HTTP, yt-dlp, torrent, behind one DownloadEngine protocol
   │
SwiftData store · control files · Keychain · helper executables
```

## Rules

- **A View owns its ViewModel**, the same shape as zaakii.
- **ViewModels never touch `ModelContext` or an engine directly, and Views don't use `@Query`.**
  ([ADR 0005](adr/0005-repositories-behind-viewmodels.md))
- **Persepolis's rules live in Services**, free of UI, so they can be tested with a fake clock
  and fake engine. In Persepolis they are spread through a 5,800-line window class.
- **Live progress stays in memory.** Engines publish snapshots, Services throttle them, and only
  status changes and periodic progress reach SwiftData.
- **Time comes from an injected clock**, so schedule tests don't wait for real minutes.

## Persepolis to Swiftpolis

| Persepolis | Swiftpolis |
| --- | --- |
| `mainwindow.py` | `MainWindowViewModel`, `QueueService`, `DownloadService` |
| `QThread` and polling loops | Actors, `Task`, `AsyncStream` |
| `queue.py` | `QueueRunner` |
| `persepolis_lib_prime.py` | `HTTPDownloadEngine` |
| `ytdlp_downloader.py`, `video_finder.py` | `YtDlpEngine`, `VideoPairCoordinator` |
| `libtorrent_wrapper.py` | `TorrentEngine` ([Q8](open-questions.md)) |
| `data_base.py` | `@Model` types and repositories |
| `QSettings` | `SettingsStore` |
| `shutdown.py` | `ShutdownService`, using a system shutdown request and no root password |
| `KeepAwakeThread` | Power assertion ([Q19](open-questions.md)) |
| `browser_integration.py`, `plugins.db` | Extension target and `BrowserRequestInbox` |

## Where code goes

Non-UI code lives in a local package ([ADR 0009](adr/0009-domain-and-services-in-a-local-package.md)).
This is the intended shape; [project-structure.md](project-structure.md) lists what exists today.

```
Swiftpolis/                 App target
├── App/                    entry point, scenes, menu bar item, dependency setup
└── Features/               one folder per screen, each with View and ViewModel
    ├── MainWindow/  AddLink/  BatchAdd/  Progress/  Properties/
    └── AfterDownload/  VideoFinder/  Torrent/  Preferences/  Log/  About/
SwiftpolisKit/              Local package
├── SwiftpolisDomain        plain types: status, schedule times, GID, file classification
├── SwiftpolisPersistence   @Model types, repositories, Persepolis import
├── SwiftpolisEngines       HTTP, yt-dlp, torrent
├── SwiftpolisServices      queue, schedule, shutdown, browser, video, torrent
└── SwiftpolisTestSupport   fake clock and fake engine
SafariExtension/            extension target with its web resources
```

## Testing

Queue and schedule rules are the highest risk for "exactly the same". Each rule in
[queue-and-schedule.md](queue-and-schedule.md) should become a test against a fake clock and
engine. The HTTP engine should run against a local test server that can drop connections, omit
`Accept-Ranges`, omit `Content-Length` and change `ETag`.
