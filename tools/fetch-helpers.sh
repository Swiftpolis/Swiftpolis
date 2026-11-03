#!/bin/bash
# Fetches yt-dlp and Deno, and builds a minimal ffmpeg, into Helpers/bin. See docs/adr/0003-bundle-non-swift-helpers.md.
#
# Versions are pinned, and every download's checksum is checked before it's used. To update one, change
# its version and checksum here. The yt-dlp and Deno checksums are the ones their GitHub releases publish.
# ffmpeg publishes a signature rather than a checksum, so its checksum was recorded when it was added.
set -euo pipefail

YT_DLP_VERSION=2026.10.26
YT_DLP_SHA256=0f922c15ccc0b83eefa1c8bc9104e434318c4bf16e408e1ee93b7745a6efe0aa
DENO_VERSION=v2.9.8
DENO_SHA256=9f0bf660393da2eaff044cdc7444cb08c73f235849b61d224d825a194ce7c98e
FFMPEG_VERSION=9.0.2
FFMPEG_SHA256=8c3850283eb25fa026482078a04051e0be17347b09ef81a0849bec15a96e002e

root="$(cd "$(dirname "$0")/.." && pwd)"
bin="$root/Helpers/bin"
work="$root/Helpers/work"
mkdir -p "$bin" "$work"

fetch() { # url sha256 destination
    if [ -f "$3" ] && echo "$2  $3" | shasum -a 256 --check --status; then return; fi
    curl --fail --location --silent --show-error --output "$3.partial" "$1"
    echo "$2  $3.partial" | shasum -a 256 --check --status || { echo "Checksum mismatch for $1" >&2; exit 1; }
    mv "$3.partial" "$3"
}

fetch "https://github.com/yt-dlp/yt-dlp/releases/download/$YT_DLP_VERSION/yt-dlp_macos" "$YT_DLP_SHA256" "$work/yt-dlp_macos"
install -m 755 "$work/yt-dlp_macos" "$bin/yt-dlp"

fetch "https://github.com/denoland/deno/releases/download/$DENO_VERSION/deno-aarch64-apple-darwin.zip" "$DENO_SHA256" "$work/deno.zip"
unzip -o -q "$work/deno.zip" -d "$work/deno"
install -m 755 "$work/deno/deno" "$bin/deno"

fetch "https://ffmpeg.org/releases/ffmpeg-$FFMPEG_VERSION.tar.xz" "$FFMPEG_SHA256" "$work/ffmpeg.tar.xz"
if [ ! -x "$bin/ffmpeg" ] || [ "$("$bin/ffmpeg" -version | head -1 | cut -d' ' -f3)" != "$FFMPEG_VERSION" ]; then
    rm -rf "$work/ffmpeg"
    mkdir -p "$work/ffmpeg"
    tar -xf "$work/ffmpeg.tar.xz" -C "$work/ffmpeg" --strip-components 1
    cd "$work/ffmpeg"
    # Only what `ffmpeg -c copy` needs to combine a video and an audio stream: no encoders, no network,
    # and no GPL code, so this build is LGPL. Decoders stay only for reading streams' parameters.
    ./configure \
        --prefix="$work/ffmpeg-install" \
        --arch=arm64 --cc=clang \
        --disable-everything --disable-autodetect --disable-network --disable-doc --disable-debug \
        --disable-ffplay --disable-ffprobe --disable-avdevice --disable-swresample --disable-swscale \
        --enable-small \
        --enable-protocol=file,pipe \
        --enable-demuxer=mov,matroska,ogg,mp3,aac,flac,wav,mpegts,flv \
        --enable-muxer=mp4,mov,matroska,webm,ipod,mp3,ogg \
        --enable-parser=aac,h264,hevc,vp8,vp9,av1,opus,vorbis,mpegaudio,flac \
        --enable-decoder=aac,mp3,opus,vorbis,flac,h264,hevc,vp8,vp9,av1 \
        --enable-bsf=aac_adtstoasc,h264_mp4toannexb,hevc_mp4toannexb,vp9_superframe,vp9_superframe_split,extract_extradata,mp3_header_decompress \
        > "$work/ffmpeg-configure.log"
    make -j"$(sysctl -n hw.ncpu)" > "$work/ffmpeg-build.log" 2>&1
    install -m 755 ffmpeg "$bin/ffmpeg"
fi

echo "Helpers are in $bin"
