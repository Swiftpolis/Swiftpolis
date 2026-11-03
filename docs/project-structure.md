# Project structure

What exists today. [architecture.md](architecture.md) describes how the layers fit together.

```
Swiftpolis/                        App target: SwiftUI only
├── App/
│   ├── SwiftpolisApp.swift        Scenes and menu commands
│   ├── AppDelegate.swift          Launch and quit rules
│   ├── AppModel.swift             Shared state; reacts to Downloads starting and finishing
│   └── AppDependencies.swift      Knows where things are stored
├── Features/                      Each screen's View and ViewModel
│   ├── MainWindow/  AddLink/  BatchAdd/  Progress/  Properties/
│   ├── AfterDownload/  Preferences/  MenuBar/
│   └── Shared/DownloadOptionsForm.swift   The options Add Link and Properties share
├── Support/
│   ├── Notifier.swift             Notifications and sounds
│   ├── SystemProxy.swift          The Add Link window's proxy detection
│   ├── SystemShutdown.swift       Asks macOS to shut down
│   └── DebugAutomation.swift      Debug builds only; see setup-and-build.md
└── Resources/Sounds/              Persepolis's notification sounds

NativeHost/                        The helper Chrome and Firefox start
SafariExtension/                   Safari's handler, and the extension's scripts in Resources/
Helpers/                           The helpers' entitlements, and bin/, which fetch-helpers.sh fills

SwiftpolisKit/                     Local Swift package
├── Sources/
│   ├── SwiftpolisBridge/          Shared with the helper and extension, so it stays small
│   │   ├── BrowserMessage.swift       The browsers' messages and native messaging's framing
│   │   └── BrowserInbox.swift         The shared folder of requests, and the wake-up link
│   ├── SwiftpolisDomain/          Plain types, with no storage or UI
│   │   ├── GID.swift
│   │   ├── DownloadStatus.swift
│   │   ├── ClockTime.swift            Times of day and their next occurrence
│   │   ├── CategoryKind.swift         Built-in Categories and Queue naming rules
│   │   ├── LibraryValues.swift        Requests, options and summaries
│   │   ├── Video.swift                Engine kinds, Video pairs, Video Finder's sites
│   │   ├── DownloadActions.swift      What each status allows, and sort orders
│   │   ├── Schedule.swift             Schedule windows and the Queue wait
│   │   ├── Formatting.swift           Sizes, speeds and times as text
│   │   └── WallClock.swift            Clock protocol and the real clock
│   ├── SwiftpolisPersistence/
│   │   ├── LibrarySchema.swift        @Model types and the versioned schema
│   │   └── LibraryRepository.swift    All library reads and writes
│   ├── SwiftpolisEngines/
│   │   ├── DownloadEngine.swift       The shape all engines share, and its value types
│   │   ├── HTTPDownloadEngine.swift   Runs one HTTP download from start to finish
│   │   ├── PartWorker.swift           One Connection: fetches Parts, writes and paces
│   │   ├── RequestFactory.swift       Sessions, requests, proxies, cookies, redirects
│   │   ├── PartPlan.swift             How a file splits into Parts
│   │   ├── ControlFile.swift          The .persepolis format and the resume decision
│   │   ├── FileNaming.swift           File names, unique names and subfolders
│   │   ├── HeaderProbe.swift          The HEAD request, and the Spider
│   │   ├── RequestRules.swift         Header and cookie text, retry and Speed dial rules
│   │   ├── HelperProcess.swift        Runs a bundled program, and stops it
│   │   ├── YtDlpEngine.swift          The yt-dlp engine, finding formats, and Muxing
│   │   ├── YtDlpRules.swift           Progress lines, options, partial files, muxed names
│   │   └── VideoFormats.swift         What yt-dlp found, as Video Finder's lists
│   ├── SwiftpolisServices/
│   │   ├── DownloadCoordinator.swift  Runs Downloads and Queues, and applies who-may-do-what rules
│   │   ├── ScheduledDownload.swift    Adds a Start time and End time to any engine
│   │   ├── DownloadDraft.swift        What the add windows edit; browser routing; helper manifests
│   │   ├── VideoFinderDraft.swift     What Video Finder edits; browser requests' routing
│   │   ├── HelperInstallation.swift   Where the helpers are; keeping yt-dlp current
│   │   ├── Preferences.swift          Preferences and where they're stored
│   │   └── SecretStore.swift          Passwords, in the Keychain
│   └── SwiftpolisTestSupport/
│       ├── ManualClock.swift          A clock tests move by hand
│       ├── FakeEngine.swift           An engine tests drive by hand
│       └── MisbehavingServer.swift    A local HTTP server that fails on request
└── Tests/
    ├── SwiftpolisDomainTests/
    ├── SwiftpolisPersistenceTests/
    ├── SwiftpolisBridgeTests/
    ├── SwiftpolisEnginesTests/
    └── SwiftpolisServicesTests/

Swiftpolis.entitlements            System Events, and the App Group
Swiftpolis-Info.plist              The swiftpolis:// link
tools/
├── fetch-helpers.sh               Downloads yt-dlp and Deno, and builds ffmpeg
├── embed-helpers.sh               The build phase that puts them in the app
└── persepolis-characterization/   Runs real Persepolis against a test server
docs/                              This documentation
```
