# Setup and build

Needs Xcode 27.2 or later on an Apple silicon Mac running macOS 27.

## Get the code

SwiftpolisKit is a separate repository, included as a Git submodule, so clone with it:

```bash
git clone --recurse-submodules https://github.com/OWNER/Swiftpolis.git
```

In a copy cloned without it, this fetches it:

```bash
git submodule update --init
```

To change the kit, commit inside `SwiftpolisKit/` and push it first. Then commit the new `SwiftpolisKit`
pointer in this repository, so nobody clones a pointer to a commit that isn't on GitHub.

## Get the helpers

Video Finder needs yt-dlp, Deno and ffmpeg, and they aren't in the repository. This puts them in `Helpers/bin/`:

```bash
tools/fetch-helpers.sh
```

It takes a few minutes, because it builds ffmpeg from source, which only needs Xcode's command-line tools.
Without it the app still builds, with a warning, and everything but Video Finder works.

## Run the tests

```bash
cd SwiftpolisKit && swift test
```

Tests cover the package. Views are checked by running the app. Engine tests run against a server on
loopback and take about 15 seconds. Three of them run the real yt-dlp, if the helpers are there. One test writes a throwaway item to your login Keychain and removes it.

The first real download into `~/Downloads` may make macOS ask for permission to use that folder.

## Run on iPhone and iPad

Run the `SwiftpolisMobile` scheme. It doesn't use the helpers. To install it on a device, choose a team under
Signing & Capabilities. A free personal team's install lasts 7 days, and a paid one's lasts as long as its
profile, on devices registered with it.

The tests can't cover what the system does with the app gone. To check that on a simulator, start some downloads
from a slow server, and end the app with `kill -9`. Don't swipe it away, as iOS takes that as the person quitting
it, and cancels its downloads. The files should still arrive, and the app should wake by itself to collect them.

The share extension builds along with the app, as `SwiftpolisShare`. To try it, open a page in Safari on the
simulator and share it to Swiftpolis, then open the app. On a device, both targets need the App Group
`group.com.amirabravesh.Swiftpolis` in their signing, which automatic signing should set up on the first build.

## Publish a release

The update check reads the latest release on GitHub. Set `ProjectLinks.owner` in
`Swiftpolis/App/ProjectLinks.swift` to the account that hosts the project, because until then the check
says it isn't set up. Raise `MARKETING_VERSION` in the project, then publish a GitHub release tagged with
that version, such as `v1.1.0`. Its description becomes the notes people see.

## Debug automation

Debug builds can run without anyone at the keyboard, using a throwaway folder in place of your real
library, preferences and Keychain. Clipboard reading is off in this mode. Release builds don't contain
this. It also never really shuts the Mac down. The variables are described in
`Swiftpolis/Support/DebugAutomation.swift`.

## Record Persepolis's behaviour

This runs the real engine from a Persepolis checkout against a misbehaving local server, and prints
JSON. `HOME` must be a temporary folder, or Persepolis writes its logs into your real config folder.
Replace `<persepolis>` with the path to your checkout.

```bash
HOME=$(mktemp -d) PYTHONPATH=<persepolis> <persepolis>/venv/bin/python tools/persepolis-characterization/observe_http_engine.py
```

The Queue scenarios work the same way, and wait for real minutes, so they take several minutes:

```bash
HOME=$(mktemp -d) PYTHONPATH=<persepolis>:tools/persepolis-characterization <persepolis>/venv/bin/python tools/persepolis-characterization/observe_queue.py
```

The native-messaging check makes its own temporary home:

```bash
PYTHONPATH=<persepolis> <persepolis>/venv/bin/python tools/persepolis-characterization/observe_native_host.py
```

[persepolis-observed.md](persepolis-observed.md) records what the results meant.

## Run the app

Open `Swiftpolis.xcodeproj` in Xcode and press Run, or build from the repo root:

```bash
xcodebuild -project Swiftpolis.xcodeproj -scheme Swiftpolis -configuration Debug build
```

The app keeps its data in `~/Library/Application Support/Swiftpolis/`.

## Testing browsers

**Safari:** run the app from Xcode. In Safari, turn on Settings > Advanced > Show features for web developers,
then Settings > Developer > Allow unsigned extensions, which resets when Safari quits. Then enable Swiftpolis
under Settings > Extensions and allow it on websites.

**The helper, without a browser:** `tools/send-native-message.py` sends the helper the same bytes a browser
would. Replace `<app>` with the built app's path:

```bash
python3 tools/send-native-message.py https://example.com/a.zip | <app>/Contents/MacOS/swiftpolis-native-host
```

macOS doesn't accept `swiftpolis://` from apps in temporary folders, so a build in `/tmp` can't be woken.

**Chrome and Firefox's manifests:** Debug builds don't install these unless `SWIFTPOLIS_INSTALL_BROWSER_HELPERS`
is set, because that would take those browsers away from Persepolis and point them at a build folder. Release
builds always install them. If a test wake-up arrives when the app isn't running, macOS launches the app without
any debug settings, so close it again afterwards.

## Project file

`Swiftpolis.xcodeproj/project.xcproj` is Xcode 27's plain-text project format, not a `.pbxproj`.

- **App sources:** anything in the `Swiftpolis/` folder is compiled automatically, so new files need
  no project edit.
- **Package products:** listed under the target's `package-product-members`.
- **Embedding:** the extension and helper are `target-membership` entries on their product, naming a `copy`
  build phase.
- **Converting:** `xcodebuild -convert-project "Xcode 26.3"` produces a classic `.pbxproj`, and
  `"Xcode Project"` converts back.

## Git

Work happens on `main`. Each roadmap step ends with a commit, and nothing is pushed until a public
repo exists. `xcuserdata/` is ignored because it holds personal Xcode state.
