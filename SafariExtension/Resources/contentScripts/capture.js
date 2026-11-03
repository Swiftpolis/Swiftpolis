/*
 * Decides whether a click on a link should go to Swiftpolis.
 *
 * Safari has no downloads API, so the extension can't see and cancel a download the way it does in
 * Chrome and Firefox. Catching clicks on links to known file types is the closest it can come, and it
 * misses downloads started by scripts or redirects. See docs/adr/0006-safari-capture-is-best-effort.md.
 *
 * This file touches nothing but its arguments, so the Swift tests can run it.
 */

const swiftpolisFileExtensions = new Set([
    // Archives
    "7z", "ace", "arj", "bz2", "cab", "gz", "iso", "lz", "lzma", "rar", "tar", "tbz2", "tgz", "xz", "z", "zip", "zipx",
    // Installers and disk images
    "apk", "appimage", "bin", "deb", "dmg", "exe", "ipa", "msi", "pkg", "rpm",
    // Video
    "3gp", "avi", "flv", "m4v", "mkv", "mov", "mp4", "mpeg", "mpg", "ts", "vob", "webm", "wmv",
    // Audio
    "aac", "flac", "m4a", "mp3", "ogg", "opus", "wav", "wma",
    // Torrents
    "torrent",
]);

function swiftpolisFileExtension(url) {
    const match = /^https?:\/\/[^/?#]*(\/[^?#]*)/i.exec(url);
    if (!match) return "";
    const name = match[1].split("/").pop();
    const dot = name.lastIndexOf(".");
    return dot === -1 ? "" : name.slice(dot + 1).toLowerCase();
}

/**
 * @param {string} url
 * @param {{enabled: boolean, keywords: string, hasDownloadAttribute: boolean}} options
 */
function swiftpolisShouldCapture(url, options) {
    if (!options.enabled || !/^https?:\/\//i.test(url)) return false;

    const isExcluded = (options.keywords || "")
        .split(/[\s,]+/)
        .some((keyword) => keyword !== "" && url.includes(keyword));
    if (isExcluded) return false;

    return options.hasDownloadAttribute || swiftpolisFileExtensions.has(swiftpolisFileExtension(url));
}
