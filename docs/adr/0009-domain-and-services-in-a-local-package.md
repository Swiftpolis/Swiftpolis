# Domain, persistence, services and engines live in a local Swift package

Everything except SwiftUI code goes in the local `SwiftpolisKit` package, and the app target is a thin layer on top. Tests run with `swift test` without launching the app, the Safari handler and the browser helper can share code, and the code avoids the app target's default of `MainActor` isolation, which suits Views but not download engines. ViewModels stay in the app target, next to their Views.
