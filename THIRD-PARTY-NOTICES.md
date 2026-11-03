# Third-party notices

Swiftpolis is free software under the GNU General Public License, version 3. See `LICENSE`.

## Work it's based on

- **Persepolis Download Manager**, GNU General Public License, version 3 or later.
  Swiftpolis rewrites its behaviour in Swift.
  <https://github.com/persepolisdm/persepolis>
- **Persepolis WebExtension**, GNU General Public License, version 3. The Safari extension and browser
  helper are based on it.
  <https://github.com/persepolisdm/Persepolis-WebExtension>

## Programs included in the app

These run as separate programs for Video Finder. `tools/fetch-helpers.sh` pins their versions.

- **yt-dlp**, the Unlicense. Its standalone macOS build also bundles Python and other components under
  their own licenses, some of them GPLv3+.
  <https://github.com/yt-dlp/yt-dlp>
- **Deno**, MIT License.
  <https://github.com/denoland/deno>
- **FFmpeg**, GNU Lesser General Public License, version 2.1 or later. Built without GPL or non-free parts.
  The exact source and build options are in `tools/fetch-helpers.sh`.
  <https://ffmpeg.org/releases/>
