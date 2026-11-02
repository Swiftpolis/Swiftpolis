# Safari download capture is best-effort

Safari has no `downloads` API and no blocking `webRequest`, so the extension cannot see and cancel downloads as it does in Chrome and Firefox. On Safari it offers the context menus, the popup and cookies, and catches clicks on links with known file types. It will miss downloads started by scripts, redirects or `Content-Disposition`. This is the one place where parity is not technically possible, so the gap is deliberate and not a bug to fix later.
