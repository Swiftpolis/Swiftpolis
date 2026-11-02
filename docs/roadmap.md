# Roadmap

The build order from [Q24](open-questions.md). Each step ends in something that can be tried. The
checklist of features is in [features.md](features.md).

| Step | Delivers | Done when |
| --- | --- | --- |
| 1. Foundation | Project settings, structure, domain types, `@Model` types, repositories, fake clock, test setup | Tests run, and the app launches with the Category list from the store |
| 2. HTTP engine | Parts, Connections, Control file, resume, retries, Speed dial, proxies, subfolders | Engine tests pass against a local server that misbehaves on purpose |
| 3. Main window and Single Downloads | Main table, Add Link, progress, properties, after-download dialog, Preferences basics, menu bar item, notifications | A real file can be added, paused, resumed, stopped, and resumed after quitting |
| 4. Queues and schedule | Every rule in [queue-and-schedule.md](queue-and-schedule.md) | Each rule has a test against the fake clock |
| 5. Browsers | Inbox, Safari extension, Chrome and Firefox helper, batch window | A link from each browser arrives in the app with its cookies |
| 6. Video | Helpers, Video Finder, Video pairs, Muxing, single-video links, yt-dlp updates | A YouTube pair downloads and muxes in a notarized build |
| 7. Torrents | libtorrent wrapper, magnet and file flows, file selection; then seeding | A torrent downloads with selected files, then seeds when enabled |
| 8. Release | Persepolis import, 18 languages, shortcuts, remaining windows, notarized DMG | Everything in features.md is ticked |

## Early checks

These could change the plan, so they happen at the start of the step that depends on them.

| Step | Check |
| --- | --- |
| 2 | One `URLSession` per Connection opens separate connections to an HTTP/2 server |
| 2 | SOCKS5 and authenticated proxies work through `ProxyConfiguration` |
| 3 | Shutting down through a system request works from an unsandboxed app |
| 5 | The Safari handler can write to the App Group and open a `swiftpolis://` link |
| 5 | Clipboard detection under macOS 27's privacy prompts |
| 6 | The PyInstaller-based `yt-dlp_macos` survives notarization, and can self-update from Application Support |
| 7 | libtorrent and Boost build statically for arm64 |
