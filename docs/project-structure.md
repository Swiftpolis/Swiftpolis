# Project structure

What exists today. [architecture.md](architecture.md) describes how the layers fit together.

```
Swiftpolis/                        App target: SwiftUI only
├── App/
│   ├── SwiftpolisApp.swift        Entry point and main window
│   └── AppDependencies.swift      Builds shared objects; knows where the store lives
└── Features/
    └── MainWindow/
        ├── MainWindowView.swift       Side panel and placeholder detail
        └── MainWindowViewModel.swift  Loads the library and holds UI state

SwiftpolisKit/                     Local Swift package
├── Sources/
│   ├── SwiftpolisDomain/          Plain types, with no storage or UI
│   │   ├── GID.swift
│   │   ├── DownloadStatus.swift
│   │   ├── ClockTime.swift            Times of day and their next occurrence
│   │   ├── CategoryKind.swift         Built-in Categories and Queue naming rules
│   │   ├── LibraryValues.swift        Requests, options and summaries
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
│   │   └── RequestRules.swift         Header and cookie text, retry and Speed dial rules
│   └── SwiftpolisTestSupport/
│       ├── ManualClock.swift          A clock tests move by hand
│       └── MisbehavingServer.swift    A local HTTP server that fails on request
└── Tests/
    ├── SwiftpolisDomainTests/
    ├── SwiftpolisPersistenceTests/
    └── SwiftpolisEnginesTests/

tools/
└── persepolis-characterization/   Runs real Persepolis against a test server
docs/                              This documentation
```
