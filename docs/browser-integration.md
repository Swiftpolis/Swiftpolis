# Browser integration

Sources: `Persepolis-WebExtension/WebExtension`, `persepolis/scripts/persepolis.py`,
`browser_integration.py`, `mainwindow.checkPluginCall`.

## How it works today

```
Extension ──connectNative("com.persepolis.pdmchromewrapper")──▶ browser launches the app
   (length-prefixed JSON on stdin and stdout)                          │
                                                 replies {"enable": true, "version": "1.85"}
                                                                       │
                                           writes links to plugins.db, touches a flag file
                                                                       │
                                   running app polls every 0.2 s and opens the right window
```

At each launch Persepolis writes a native-messaging manifest and a launcher shell script for
Chrome, Chromium, Opera, Vivaldi, Firefox and Brave.

## Message format

Native messaging uses a 4-byte native-endian length, then UTF-8 JSON.

```json
{
  "url_links": [
    {
      "url": "https://example.com/file.zip",
      "cookies": "a=1; b=2",
      "useragent": "Mozilla/5.0 ...",
      "referrer": "https://example.com/",
      "postdata": ""
    }
  ],
  "version": "4.0.0"
}
```

The host also reads optional `header`, `filename` and `load_cookies` keys.

**The extension's `cookies` value is ignored by the host.** It reads only `load_cookies`, and
the extension never sends that. See **Defect D8**.

## What the app does with a request

1. Links matching a Video Finder site open Video Finder, up to `video_finder/max_links`.
2. One remaining link opens Add Link, or starts in Single Downloads immediately if
   `dont-show-addlinkwindow` is `yes`.
3. Several remaining links open the batch window, where the user picks links and a Queue.

## Extension features

| Feature | Mechanism | Safari |
| --- | --- | --- |
| Capture browser downloads | `downloads.onCreated`, then cancel and erase | **Not available** |
| Skip files under 5 MiB when size is known | `downloadItem.fileSize` | Not available |
| Keyword and extension blocklist | Storage plus the capture above | Needs a new trigger |
| "Download with Persepolis" link menu | `contextMenus` | Available |
| "Download Selected links" menu | `contextMenus`, `scripting` | Available |
| "Download All Links" menu | `contextMenus`, `scripting` | Available |
| Toolbar popup: toggles and keywords | `action`, `storage` | Available |
| Keyboard toggle for capture | Content script | Available |
| Cookies, user agent, referrer | `cookies` | Available; `onChanged` is not, and isn't needed |
| Native messaging | `connectNative` to a host | Different; see below |

## Safari constraints

1. **No `downloads` API.** MDN's compatibility data lists `downloads`, its permission,
   `onCreated`, `cancel` and `erase` as unsupported in Safari. Blocking `webRequest` is also
   unsupported. So the extension cannot see and cancel a Safari download as it does in Chrome.
   Automatic capture has to be approximated, for example by intercepting clicks on links with
   known file extensions in the content script. That misses redirects, script-driven and
   `Content-Disposition` downloads. See [ADR 0006](adr/0006-safari-capture-is-best-effort.md).
2. **Native messaging goes to the extension's own handler.** Safari ignores the host name and
   sends messages to `SafariWebExtensionHandler` in the app extension, which is sandboxed
   separately from the main app. Getting a request from there to the app needs an App Group,
   a custom URL scheme or similar. Swiftpolis uses a shared inbox folder plus a `swiftpolis://`
   link ([ADR 0007](adr/0007-browser-requests-via-shared-inbox.md)).
3. **The current handler is the Xcode template.** It echoes messages back.
4. **`getBrowserApi()` treats Safari as Firefox**, because `browser` is defined. The rest of
   the script mixes `chrome.` and `BrowserNameSpace`, and needs checking under Safari.
5. **The existing wrapper project also has iOS targets.** They are out of scope for now.
6. **The user has to enable the extension** in Safari Settings, and grant website access. The
   app should guide them.

Sources: [MDN browser-compat-data](https://github.com/mdn/browser-compat-data/blob/main/webextensions/api/downloads.json),
[Apple: assessing browser compatibility](https://developer.apple.com/tutorials/data/documentation/safariservices/assessing-your-safari-web-extension-s-browser-compatibility.md).

## Swiftpolis decisions

- **Extension code** is forked into this repo, renamed to Swiftpolis, and macOS only
  ([Q23](open-questions.md)).
- **Chrome and Firefox** keep using the existing store extensions, through a bundled helper that
  speaks the same message format. Persepolis and Swiftpolis share the native host name
  `com.persepolis.pdmchromewrapper`, so if both are installed, whichever launched last receives
  those browsers' requests.
- **Cookies** are stored in the Keychain per Download and removed when it finishes or is removed
  ([Q21](open-questions.md)). This also fixes Defect D8.

## Other entry points

- **Command line:** `--link`, `--referer`, `--load-cookies`, `--agent`, `--headers`, `--name`,
  `--tray`, `--default`, `--clear`, `--version`.
- **Second launch:** a lock file stops a second instance, which instead signals the first to
  show its window. macOS handles this for app bundles.
