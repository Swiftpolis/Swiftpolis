# Open questions

Decisions still needed. Answers move into the relevant doc, and into `adr/` when they are hard
to reverse, surprising and a real trade-off.

None at the moment. New questions will appear here as the build raises them.

## Resolved

| # | Decision | Recorded in |
| --- | --- | --- |
| Q1 | Baseline is `test` at `8940bcf` | [README.md](README.md) |
| Q2 | Same rules, with listed defects fixed | [ADR 0001](adr/0001-parity-with-defects-fixed.md) |
| Q3 | Port Persepolis's engine to `URLSession`, one session per Connection, no aria2 | [ADR 0002](adr/0002-port-engine-to-urlsession.md) |
| Q4 | yt-dlp and ffmpeg stay as bundled Apple silicon programs | [ADR 0003](adr/0003-bundle-non-swift-helpers.md) |
| Q5 | Mac mechanisms: no root password, power assertion, login item, menu bar item, bundled sounds | [features.md](features.md) |
| Q6 | Same windows, actions and columns, in native Mac style, without Qt style settings | [settings.md](settings.md) |
| Q7 | Views own ViewModels; repositories behind ViewModels; no `@Query`; live progress in memory | [ADR 0005](adr/0005-repositories-behind-viewmodels.md) |
| Q8 | libtorrent static, built from source, behind an Objective-C++ wrapper | [ADR 0008](adr/0008-libtorrent-behind-objective-cpp-wrapper.md) |
| Q9 | Safari gets menus, popup, cookies and click capture; Chrome family and Firefox stay supported | [ADR 0006](adr/0006-safari-capture-is-best-effort.md) |
| Q10 | Developer ID, unsandboxed, GPLv3 | [ADR 0004](adr/0004-developer-id-gpl-unsandboxed.md) |
| Q11 | One-time Persepolis import; keep the control-file format | [data-model.md](data-model.md) |
| Q12 | macOS 27.0, Apple silicon only, Swift 6 mode | [architecture.md](architecture.md) |
| Q13 | Seeding comes after torrent downloading, off by default, following the Preferences design | [video-and-torrent.md](video-and-torrent.md) |
| Q14 | Bundle Deno | [ADR 0003](adr/0003-bundle-non-swift-helpers.md) |
| Q15 | yt-dlp in Application Support, self-updating at most daily, with bundled fallback | [ADR 0003](adr/0003-bundle-non-swift-helpers.md) |
| Q16 | Minimal remux-only ffmpeg from source | [ADR 0003](adr/0003-bundle-non-swift-helpers.md) |
| Q17 | Missed Start time: start on wake if End time hasn't passed, otherwise skip and notify | [queue-and-schedule.md](queue-and-schedule.md) |
| Q18 | Schedules still clear at launch, with a clear note in the UI | [queue-and-schedule.md](queue-and-schedule.md) |
| Q19 | Keep Awake applies while any session exists, including scheduled ones | [queue-and-schedule.md](queue-and-schedule.md) |
| Q20 | Clipboard monitoring off by default; detect link-like content before reading | [settings.md](settings.md) |
| Q21 | Browser cookies in the Keychain per Download, removed on completion or removal | [browser-integration.md](browser-integration.md) |
| Q22 | Shared App Group inbox plus a `swiftpolis://` wake-up | [ADR 0007](adr/0007-browser-requests-via-shared-inbox.md) |
| Q23 | Extension forked into this repo and renamed, first for macOS and later for iOS too; store extensions stay for other browsers | [browser-integration.md](browser-integration.md) |
| Q24 | Build order | [roadmap.md](roadmap.md) |
| Q25 | "New version" notice from a public GitHub repo; no Sparkle yet | [roadmap.md](roadmap.md) |
| Q26 | Non-UI code in a local Swift package; the app is a thin SwiftUI layer | [ADR 0009](adr/0009-domain-and-services-in-a-local-package.md) |
| Q27 | Tests first with Swift Testing for rules and engines; Views checked by running the app | [architecture.md](architecture.md) |
| Q28 | Record real Persepolis's behaviour for the riskiest scenarios before steps 2 and 4 | [roadmap.md](roadmap.md) |
| Q29 | Build steps 1 to 3, stopping for review after each | [roadmap.md](roadmap.md) |
| Q30 | Work on `main`, commit at the end of each step without asking, no pushing | [setup-and-build.md](setup-and-build.md) |
