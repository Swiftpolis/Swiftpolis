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
│   ├── MainWindow/  AddLink/  Progress/  Properties/
│   ├── AfterDownload/  Preferences/  MenuBar/
│   └── Shared/DownloadOptionsForm.swift   The options Add Link and Properties share
├── Support/
│   ├── Notifier.swift             Notifications and sounds
│   ├── SystemProxy.swift          The Add Link window's proxy detection
│   └── DebugAutomation.swift      Debug builds only; see setup-and-build.md
└── Resources/Sounds/              Persepolis's notification sounds

SwiftpolisKit/                     Local Swift package
├── Sources/
│   ├── SwiftpolisDomain/          Plain types, with no storage or UI
│   │   ├── GID.swift
│   │   ├── DownloadStatus.swift
│   │   ├── ClockTime.swift            Times of day and their next occurrence
│   │   ├── CategoryKind.swift         Built-in Categories and Queue naming rules
│   │   ├── LibraryValues.swift        Requests, options and summaries
│   │   ├── DownloadActions.swift      What each status allows, and sort orders
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
│   │   └── RequestRules.swift         Header and cookie text, retry and Speed dial rules
│   ├── SwiftpolisServices/
│   │   ├── DownloadCoordinator.swift  Runs Downloads and applies who-may-do-what rules
│   │   ├── DownloadDraft.swift        What Add Link and Properties edit
│   │   ├── Preferences.swift          Preferences and where they're stored
│   │   └── SecretStore.swift          Passwords, in the Keychain
│   └── SwiftpolisTestSupport/
│       ├── ManualClock.swift          A clock tests move by hand
│       ├── FakeEngine.swift           An engine tests drive by hand
│       └── MisbehavingServer.swift    A local HTTP server that fails on request
└── Tests/
    ├── SwiftpolisDomainTests/
    ├── SwiftpolisPersistenceTests/
    ├── SwiftpolisEnginesTests/
    └── SwiftpolisServicesTests/

tools/
└── persepolis-characterization/   Runs real Persepolis against a test server
docs/                              This documentation
```
