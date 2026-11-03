# Swiftpolis — Documentation

Swiftpolis is a native macOS rewrite of **Persepolis Download Manager** in Swift,
SwiftUI and SwiftData, using MVVM, with an added Safari extension. The goal is
feature parity with Persepolis, including its queue and schedule behaviour, on
macOS 28 and later, where Rosetta 2 is no longer available for general Intel apps. It also runs on iPhone and iPad,
within what [iOS allows](adr/0010-ios-downloads-belong-to-the-system.md).

- **Bundle ID:** `com.amirabravesh.Swiftpolis`
- **Source of truth for behaviour:** Persepolis `5.2.0`, branch `test`, commit `8940bcf`
  (`Side_Projects/persepolis`)
- **Parity rule:** same rules, with known defects fixed ([ADR 0001](adr/0001-parity-with-defects-fixed.md))
- **Distribution:** Developer ID, unsandboxed, GPLv3 ([ADR 0004](adr/0004-developer-id-gpl-unsandboxed.md))
- **Status:** step 6 of 8 ([roadmap.md](roadmap.md)). Single Downloads, Queues, schedules, browser links and
  Video Finder work. Torrents don't yet.

## Documentation index

| Doc | What's inside | Status |
| --- | --- | --- |
| [GLOSSARY.md](GLOSSARY.md) | The project's language: one word per concept | Living |
| [open-questions.md](open-questions.md) | Design decisions waiting on an answer | Living |
| [features.md](features.md) | Every Persepolis feature, the parity checklist | From source |
| [queue-and-schedule.md](queue-and-schedule.md) | Exact queue, schedule and shutdown rules | From source |
| [download-engine.md](download-engine.md) | Parts, resume, retries, control file, file placement | From source |
| [video-and-torrent.md](video-and-torrent.md) | Video Finder, yt-dlp, muxing, BitTorrent | From source |
| [data-model.md](data-model.md) | Persepolis tables and their lifecycle | From source |
| [settings.md](settings.md) | Every preference and its default | From source |
| [browser-integration.md](browser-integration.md) | Wire protocol, extension behaviour, Safari constraints | From source |
| [persepolis-observed.md](persepolis-observed.md) | What the real engine and Queues did when run; the reference for tests | Observed |
| [upstream-defects.md](upstream-defects.md) | Persepolis bugs Swiftpolis fixes | Mixed |
| [architecture.md](architecture.md) | Proposed MVVM structure | Draft |
| [project-structure.md](project-structure.md) | Where the code is, file by file | Living |
| [setup-and-build.md](setup-and-build.md) | Run the tests and the app; the project file format | Living |
| [roadmap.md](roadmap.md) | Build order and the early checks in each step | Living |
| [adr/](adr/) | Hard-to-reverse decisions, 0001 to 0011 | Living |

"From source" docs describe what Persepolis does, found by reading its code, and they
are not a Swiftpolis design. Where one disagrees with
[persepolis-observed.md](persepolis-observed.md), the observation wins.

## 30-second mental model of Persepolis

```
Browser extension ──native messaging──▶ second process ──▶ plugins DB + flag file
                                                                │ polled every 0.2 s
Add Link / Queue / Video Finder / Torrent windows ◀─────────────┘
        │
        ▼
Category (All / Single / Scheduled / user queues) ── Queue thread: one download at a time, 5 passes
        │
        ▼
Download session ── persepolis_lib_prime (HTTP, up to 64 workers over up to 64 parts)
                 ├─ ytdlp_downloader   (video and audio streams, then ffmpeg mux)
                 └─ libtorrent_wrapper (magnet and .torrent, `test` branch only)
        │  tellStatus() polled every 0.2 s
        ▼
Main table + progress windows; database written about once a second
```

## Correction to the starting assumption

**Persepolis no longer uses aria2.** Commit `93e4551` ("aria2 has been replaced with
persepolis_lib_prime") removed it. The remaining mentions are stale comments and
help text. The engine to port is `persepolis/scripts/persepolis_lib_prime.py`.
