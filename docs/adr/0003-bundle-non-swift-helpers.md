# Bundle yt-dlp and ffmpeg as separate programs

The app is written in Swift, but yt-dlp (Python) and ffmpeg (C) ship as separate Apple silicon executables that it runs and reads output from. Rewriting them is not realistic: yt-dlp's site support changes constantly, and Video Finder depends on both. "Fully Swift" therefore applies to Swiftpolis's own code and not to these helpers.

## Consequences

- **Deno is bundled too**, because yt-dlp needs a JavaScript runtime for full YouTube support and Deno is the one it recommends.
- **ffmpeg is a minimal build from source** that only remuxes, because that is all Persepolis uses it for.
- **yt-dlp updates itself.** It is copied to Application Support on first run and self-updates at most once a day, falling back to the bundled copy if that fails, because sites break it faster than app releases can follow.
