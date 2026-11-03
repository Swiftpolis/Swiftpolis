/*
 * Forked from Persepolis's WebExtension, itself forked from uget-chrome-wrapper.
 *
 * Copyright (C) 2016  Gobinath
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

var BrowserNameSpace = typeof browser !== "undefined" ? browser : chrome;

// A missing value means it's never been switched off.
let catchesLinks = true;
let excludedKeywords = "";

BrowserNameSpace.storage.local.get(["pdmInterrupt", "keywords"]).then((stored) => {
    catchesLinks = stored.pdmInterrupt !== false;
    excludedKeywords = stored.keywords || "";
});

BrowserNameSpace.storage.onChanged.addListener((changes) => {
    if (changes.pdmInterrupt) catchesLinks = changes.pdmInterrupt.newValue !== false;
    if (changes.keywords) excludedKeywords = changes.keywords.newValue || "";
});

// In the capture phase, so that the page's own handlers don't see a click that's been dealt with.
document.addEventListener("click", (event) => {
    const isPlainClick = event.button === 0 && !event.metaKey && !event.ctrlKey && !event.shiftKey && !event.altKey;
    if (!isPlainClick || event.defaultPrevented) return;

    const link = event.target.closest && event.target.closest("a[href]");
    if (!link) return;

    const shouldCapture = swiftpolisShouldCapture(link.href, {
        enabled: catchesLinks,
        keywords: excludedKeywords,
        hasDownloadAttribute: link.hasAttribute("download"),
    });
    if (!shouldCapture) return;

    event.preventDefault();
    event.stopPropagation();
    BrowserNameSpace.runtime.sendMessage({ type: "captureLink", url: link.href });
}, true);

function sendToExtension(message) {
    BrowserNameSpace.runtime.sendMessage({ type: "keyPress", message });
}

const temporaryDisableKeys = ["Insert", "Backquote"];

window.addEventListener("keydown", (event) => {
    if (temporaryDisableKeys.includes(event.code)) sendToExtension("disable");
});

window.addEventListener("keyup", (event) => {
    if (temporaryDisableKeys.includes(event.code)) {
        sendToExtension("enable");
    } else if (event.code === "KeyU" && event.ctrlKey && event.shiftKey) {
        sendToExtension("toggle");
    }
});
