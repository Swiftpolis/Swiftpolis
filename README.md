# Swiftpolis

A native download manager for macOS, written in Swift and SwiftUI. It's a rewrite of
[Persepolis Download Manager](https://github.com/persepolisdm/persepolis) that keeps its queues and
schedules, and adds a Safari extension.

> **Early days.** There's no notarized release yet, so for now you build it yourself. Torrents, translations
> and importing from Persepolis aren't done. See [what's left](docs/roadmap.md).

## What it does

- **Fast downloads:** up to 64 connections per file, with pause, resume, retries and a live speed dial
- **Queues and schedules:** start and end times, one download at a time, and shutting down the Mac afterwards
- **Whole seasons at once:** paste a list of links, pick the ones you want, and add them to a queue
- **Browsers:** a Safari extension, plus the Persepolis extension for Chrome, Firefox and others
- **Video Finder:** finds the formats on video sites with [yt-dlp](https://github.com/yt-dlp/yt-dlp), and
  combines separate video and audio with [FFmpeg](https://ffmpeg.org)
- **Stays out of the way:** runs from the menu bar with no windows open
- **Keeps secrets safe:** passwords and cookies stay in the Keychain

The full list, with what's finished and what isn't, is in [docs/features.md](docs/features.md).

## Build it

You need an Apple silicon Mac running macOS 27, and Xcode 27.2 or later.

```bash
git clone --recurse-submodules https://github.com/OWNER/Swiftpolis.git
```

```bash
cd Swiftpolis
```

Video Finder needs its helper programs. This fetches them and builds FFmpeg, which takes a few minutes. Without
them everything else still works.

```bash
tools/fetch-helpers.sh
```

Then open `Swiftpolis.xcodeproj`, choose your own team under Signing & Capabilities, and run the `Swiftpolis`
scheme. More detail is in [docs/setup-and-build.md](docs/setup-and-build.md).

## How it's put together

| Part | What it is |
| --- | --- |
| `Swiftpolis/` | The app: SwiftUI views and view models |
| [`SwiftpolisKit/`](https://github.com/OWNER/SwiftpolisKit) | The package with the engines, storage and rules, as a Git submodule |
| `SafariExtension/` | The Safari extension |
| `NativeHost/` | The helper that Chrome, Firefox and others talk to |
| `docs/` | Architecture, decisions, and how behaviour matches Persepolis |

Start with [docs/README.md](docs/README.md) to find your way around.

## Tests

```bash
cd SwiftpolisKit && swift test
```

## Credits and license

Swiftpolis is based on Persepolis Download Manager and its WebExtension, by their developers and contributors.

It's free software under the [GNU General Public License, version 3](LICENSE). The programs it bundles are
listed in [THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md).
