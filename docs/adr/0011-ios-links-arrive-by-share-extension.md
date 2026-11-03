# On iOS, links arrive by share extension, and wait for the person

On iOS and iPadOS a share extension lets someone send a page, several links or selected text to Swiftpolis from any app. It parses the links with `LinkText`, and writes them to the same `BrowserInbox` the Mac's browsers use ([ADR 0007](0007-browser-requests-via-shared-inbox.md)), in an App Group with iOS's required `group.` prefix. The app drains the inbox and opens its Add Links sheet with the links, so nothing downloads until the person presses Start.

A share extension can't open its app on iOS, so the Mac's `swiftpolis://` wake-up doesn't carry over. Working around that with private API or a responder-chain trick was rejected, because it's unreliable and could fail App Review. Instead there are three ways the links get seen:

- **The extension says so.** It always confirms how many links were sent, and asks the person to open Swiftpolis.
- **A notification is the shortcut back.** Tapping it opens the app. It only shows if the person has already allowed notifications, which the app asks for at their first Start, because a permission prompt doesn't belong in the middle of sharing. Newer ones replace it, and the app removes it once the links are in.
- **The app checks when it comes to the front.** That's the only route that always works, so it's the one everything relies on.

On iPad the app can already be on screen beside Safari, so it never "comes to the front". For that case the extension also posts a Darwin notification, which carries no data, and a running app checks the inbox when it hears one.

## Consequences

- **Links wait longer than on the Mac.** A Mac request is thrown away after a day, because the app wakes at once and anything older is stale. On iOS the wait is on a person, so it's a week.
- **Links shared while the Add Links sheet is open join it**, and a link shared twice shows once.
- **Text outranks URLs.** When an app shares text holding links along with a page's URL, only the links in the text are taken. Safari sends just the text for a selection, but other apps may send both.
- **Cookies don't come along.** A share carries a link and nothing else, so a site that needs a login has to use the sheet's login fields.
- **The app and the extension both need the App Group** in their signing. So far this has only run on simulators, which don't check it, so the first device build will show whether automatic signing sets it up as expected.

## The Safari extension

The Mac's Safari extension also builds for iOS, and uses the same inbox. As the same limit applies, the page shows a message with an **Open** link to `swiftpolis://inbox`. That carries no data, and tapping it makes Safari ask before opening the app, which then checks its inbox as usual.

- **Safari doesn't reliably apply the manifest's stylesheet.** On iOS the same page could load with or without it, so the background script calls `scripting.insertCSS` before showing anything on a page.
- **The person turns it on themselves**, in Settings under Apps, Safari, Extensions, and has to allow it on websites.
- **Links keep what Safari sent with them**, such as the referrer. In testing, `cookies.getAll` returned nothing on iOS for a site that had set a cookie, so a site that needs a login may still need the sheet's login fields.

