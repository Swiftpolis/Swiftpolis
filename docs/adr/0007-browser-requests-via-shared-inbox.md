# Browser requests reach the app through a shared inbox

Every browser writes each Browser request as a file in a shared App Group folder, then opens a `swiftpolis://` link to launch or wake the app, which drains the folder. The sandboxed Safari handler and the Chrome and Firefox native-messaging helper therefore share one path, and requests wait safely if the app is closed. XPC was rejected because it needs a running or launchd-registered listener and would not give both browsers one route. This also replaces Persepolis's `plugins.db` and flag-file polling.
