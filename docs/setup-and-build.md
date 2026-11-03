# Setup and build

Needs Xcode 27.2 or later on an Apple silicon Mac running macOS 27.

## Run the tests

```bash
cd SwiftpolisKit && swift test
```

Tests cover the package. Views are checked by running the app. Engine tests run against a server on
loopback and take about 15 seconds. One test writes a throwaway item to your login Keychain and removes it.

The first real download into `~/Downloads` may make macOS ask for permission to use that folder.

## Debug automation

Debug builds can run without anyone at the keyboard, using a throwaway folder in place of your real
library, preferences and Keychain. Clipboard reading is off in this mode. Release builds don't contain
this. The variables are described in `Swiftpolis/Support/DebugAutomation.swift`.

## Record Persepolis's behaviour

This runs the real engine from a Persepolis checkout against a misbehaving local server, and prints
JSON. `HOME` must be a temporary folder, or Persepolis writes its logs into your real config folder.
Replace `<persepolis>` with the path to your checkout.

```bash
HOME=$(mktemp -d) PYTHONPATH=<persepolis> <persepolis>/venv/bin/python tools/persepolis-characterization/observe_http_engine.py
```

[persepolis-observed.md](persepolis-observed.md) records what the results meant.

## Run the app

Open `Swiftpolis.xcodeproj` in Xcode and press Run, or build from the repo root:

```bash
xcodebuild -project Swiftpolis.xcodeproj -scheme Swiftpolis -configuration Debug build
```

The app keeps its data in `~/Library/Application Support/Swiftpolis/`.

## Project file

`Swiftpolis.xcodeproj/project.xcproj` is Xcode 27's plain-text project format, not a `.pbxproj`.

- **App sources:** anything in the `Swiftpolis/` folder is compiled automatically, so new files need
  no project edit.
- **Package products:** listed under the target's `package-product-members`.
- **Converting:** `xcodebuild -convert-project "Xcode 26.3"` produces a classic `.pbxproj`, and
  `"Xcode Project"` converts back.

## Git

Work happens on `main`. Each roadmap step ends with a commit, and nothing is pushed until a public
repo exists. `xcuserdata/` is ignored because it holds personal Xcode state.
