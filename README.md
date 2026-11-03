# Swiftpolis

A native download manager for macOS, iPhone and iPad, written in Swift and SwiftUI. It's a rewrite of
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

### On iPhone and iPad

The same app core, built around what iOS allows:

- **Keeps going when you leave:** the system runs the downloads, even if the iPad is locked or the app is closed
- **Whole lists at once:** paste them, press Start, and the files appear in the Files app
- **Send links from any app:** share a page or selected text from Safari to Swiftpolis
- **Safari extension:** tap a file link, or pick from all the links on a page
- **Queues:** with retries and a rough start time

There's no Video Finder, speed limit, proxy or end time, and no multi-connection downloading. iOS doesn't allow
them, or the app isn't around to do them. [Here's why](docs/adr/0010-ios-downloads-belong-to-the-system.md).
It needs iOS 18 or later.

## Build it

You need an Apple silicon Mac running macOS 27, and Xcode 27.2 or later. The Mac app needs macOS 27 too.

```bash
git clone --recurse-submodules https://github.com/Swiftpolis/Swiftpolis.git
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
scheme for the Mac, or `SwiftpolisMobile` for iPhone and iPad, which doesn't need the helpers. More detail is in
[docs/setup-and-build.md](docs/setup-and-build.md).

## How it's put together

| Part | What it is |
| --- | --- |
| `Swiftpolis/` | The Mac app: SwiftUI views and view models |
| `SwiftpolisMobile/` | The iPhone and iPad app |
| `ShareExtension/` | Sends links from other apps to the iPhone and iPad app |
| [`SwiftpolisKit/`](https://github.com/Swiftpolis/SwiftpolisKit) | The package with the engines, storage and rules, as a Git submodule |
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
