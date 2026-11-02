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
│   └── SwiftpolisTestSupport/
│       └── ManualClock.swift          A clock tests move by hand
└── Tests/
    ├── SwiftpolisDomainTests/
    └── SwiftpolisPersistenceTests/

docs/                              This documentation
```
