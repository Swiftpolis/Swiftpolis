#!/bin/sh
# Copies the helpers into the app and signs them. Xcode runs this as a build phase.
set -eu

source="$SRCROOT/Helpers/bin"
destination="$TARGET_BUILD_DIR/$CONTENTS_FOLDER_PATH/Helpers"

if [ ! -x "$source/yt-dlp" ] || [ ! -x "$source/deno" ] || [ ! -x "$source/ffmpeg" ]; then
    echo "warning: The video helpers are missing, so Video Finder won't work. Run tools/fetch-helpers.sh."
    exit 0
fi

mkdir -p "$destination"
for helper in yt-dlp deno ffmpeg; do
    if [ "$source/$helper" -nt "$destination/$helper" ]; then
        cp -f "$source/$helper" "$destination/$helper"
        codesign --force --options runtime --timestamp=none \
            --entitlements "$SRCROOT/Helpers/$helper.entitlements" \
            --sign "$EXPANDED_CODE_SIGN_IDENTITY" "$destination/$helper"
    fi
done
