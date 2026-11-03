/*
 * The toolbar popup. Forked from Persepolis's WebExtension, itself forked from uget-chrome-wrapper.
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

const api = typeof browser !== "undefined" ? browser : chrome;

// An iPad can describe itself as a Mac, but no Mac has a touch screen. These have no right-click menu to add
// to, and no use for keyboard shortcuts.
document.documentElement.classList.toggle("is-touch", navigator.maxTouchPoints > 1);

const catchesLinks = document.getElementById("catches-links");
const contextMenu = document.getElementById("context-menu");
const keywords = document.getElementById("keywords");

function showCatching() {
    document.body.classList.toggle("is-off", !catchesLinks.checked);
    document.getElementById("status-text").textContent = catchesLinks.checked
        ? "Catching file links"
        : "Safari keeps its downloads";
}

function save() {
    showCatching();
    api.runtime.sendMessage({
        type: "setExtensionConfig",
        data: {
            pdmInterrupt: catchesLinks.checked,
            contextMenu: contextMenu.checked,
            keywords: keywords.value,
        },
    });
}

async function pickLinks(script) {
    const [tab] = await api.tabs.query({ active: true, currentWindow: true });
    if (!tab) return;
    await api.runtime.sendMessage({ type: "pickLinks", tabId: tab.id, script });
    window.close();
}

api.runtime.sendMessage({ type: "getExtensionConfig" }).then((config) => {
    catchesLinks.checked = config.pdmInterrupt;
    contextMenu.checked = config.contextMenu;
    keywords.value = config.keywords;
    showCatching();

    catchesLinks.addEventListener("change", save);
    contextMenu.addEventListener("change", save);
    keywords.addEventListener("input", save);
});

document.getElementById("all-links").addEventListener("click", () => pickLinks("scripts/getall.js"));
document.getElementById("selected-links").addEventListener("click", () => pickLinks("scripts/getselected.js"));
