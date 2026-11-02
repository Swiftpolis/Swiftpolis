# Setup and build

Needs Xcode 27.2 or later on an Apple silicon Mac running macOS 27.

## Run the tests

```bash
cd SwiftpolisKit && swift test
```

Tests cover the package. Views are checked by running the app.

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
