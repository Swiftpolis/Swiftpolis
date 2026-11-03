/*
 * Forked from Persepolis's WebExtension, itself forked from uget-chrome-wrapper.
 *
 * Modified copyright (C) 2017  Jafar Akhondali
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
const VERSION = "1.0.0";

async function cookieHeader(url) {
    try {
        const cookies = await api.cookies.getAll({ url });
        return cookies.map((cookie) => `${cookie.name}=${cookie.value}`).join("; ");
    } catch (error) {
        // Someone may have refused this site's access. The download can still be tried without them.
        console.log("Couldn't read cookies", error);
        return "";
    }
}

async function makeLink(url, referrer) {
    return {
        url,
        cookies: await cookieHeader(url),
        useragent: navigator.userAgent,
        referrer: referrer || "",
        postdata: "",
    };
}

function sendToApp(links) {
    // Safari ignores the name, and always talks to this extension's own handler.
    return api.runtime
        .sendNativeMessage("com.amirabravesh.Swiftpolis", { url_links: links, version: VERSION })
        .catch((error) => console.error("Couldn't reach Swiftpolis", error));
}

async function sendLinks(urls, referrer) {
    const usable = urls.filter((url) => url !== "");
    if (usable.length > 0) {
        sendToApp(await Promise.all(usable.map((url) => makeLink(url, referrer))));
    }
}

async function config() {
    const stored = await api.storage.local.get(["pdmInterrupt", "contextMenu", "keywords"]);
    return {
        pdmInterrupt: stored.pdmInterrupt !== false,
        contextMenu: stored.contextMenu !== false,
        keywords: stored.keywords || "",
    };
}

async function setCatchesLinks(isOn) {
    await api.storage.local.set({ pdmInterrupt: isOn });
    api.action.setIcon({ path: isOn ? "icons/icon_32.png" : "icons/icon_disabled_32.png" });
}

function setContextMenu(isOn) {
    api.contextMenus.removeAll(() => {
        if (!isOn) return;
        api.contextMenus.create({ title: "Download with Swiftpolis", id: "download_with_pdm", contexts: ["link"] });
        api.contextMenus.create({ title: "Download Selected Links with Swiftpolis", id: "download_links_with_pdm", contexts: ["selection"] });
        api.contextMenus.create({ title: "Download All Links with Swiftpolis", id: "download_all_links_with_pdm", contexts: ["page"] });
    });
}

async function applyConfig() {
    const { pdmInterrupt, contextMenu } = await config();
    await setCatchesLinks(pdmInterrupt);
    setContextMenu(contextMenu);
}

api.runtime.onInstalled.addListener(applyConfig);
api.runtime.onStartup.addListener(applyConfig);

api.runtime.onMessage.addListener((request, sender, sendResponse) => {
    switch (request.type) {
    case "captureLink":
        sendLinks([request.url], sender.url);
        break;

    case "getAll":
    case "getSelected":
        sendLinks(request.message, sender.url);
        break;

    case "keyPress":
        if (request.message === "enable") {
            setCatchesLinks(true);
        } else if (request.message === "disable") {
            setCatchesLinks(false);
        } else {
            config().then(({ pdmInterrupt }) => setCatchesLinks(!pdmInterrupt));
        }
        break;

    case "getExtensionConfig":
        config().then(sendResponse);
        return true;

    case "setExtensionConfig": {
        const { pdmInterrupt, contextMenu, keywords } = request.data;
        setCatchesLinks(pdmInterrupt);
        api.storage.local.set({ contextMenu, keywords });
        setContextMenu(contextMenu);
        break;
    }
    }
    return false;
});

async function injectLinkPicker(tabId, script) {
    await api.scripting.executeScript({ target: { tabId }, files: ["scripts/injector.js"] });
    await api.scripting.executeScript({ target: { tabId }, files: [script] });
}

api.contextMenus.onClicked.addListener((info, tab) => {
    switch (info.menuItemId) {
    case "download_with_pdm":
        sendLinks([info.linkUrl], info.pageUrl);
        break;
    case "download_links_with_pdm":
        injectLinkPicker(tab.id, "scripts/getselected.js");
        break;
    case "download_all_links_with_pdm":
        injectLinkPicker(tab.id, "scripts/getall.js");
        break;
    }
});
