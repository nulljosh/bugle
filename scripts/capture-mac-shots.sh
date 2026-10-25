#!/usr/bin/env bash
# Regenerate the Mac App Store screenshot set.
#
# Builds the Debug macOS app and runs its `--capture` mode once per state. The app is
# sandboxed, so it writes each PNG into its own container temp directory and prints the path;
# this script copies them into ios/.asc/screenshots/mac/.
#
# Frames come out 1280x800 with no alpha, which is what ASC accepts. Nothing is uploaded here —
# `asc screenshots upload` is a separate, deliberate step.
set -euo pipefail

cd "$(dirname "$0")/.."
DEST="ios/.asc/screenshots/mac"

(cd ios && xcodegen generate >/dev/null)
xcodebuild -project ios/journal.xcodeproj -scheme Bugle-macOS -configuration Debug build >/dev/null

APP="$(xcodebuild -project ios/journal.xcodeproj -scheme Bugle-macOS -configuration Debug \
  -showBuildSettings 2>/dev/null |
  awk -F' = ' '/ BUILT_PRODUCTS_DIR/{d=$2} / FULL_PRODUCT_NAME/{n=$2} END{print d"/"n}')"
BIN="$APP/Contents/MacOS/Bugle"
[ -x "$BIN" ] || { echo "no binary at $BIN" >&2; exit 1; }

mkdir -p "$DEST"
i=0
for state in list article feeds; do
  i=$((i + 1))
  # The app fetches live feeds, so a frame can legitimately fail (no network). Let it stop the
  # run rather than silently leaving a stale PNG in place.
  src="$("$BIN" --capture "$state" | tail -1)"
  [ -f "$src" ] || { echo "capture $state produced nothing" >&2; exit 1; }
  out="$DEST/$(printf '%02d' $i)-$state.png"
  cp "$src" "$out"
  echo "$out  $(sips -g pixelWidth -g pixelHeight -g hasAlpha "$out" | tail -3 | tr -s ' \n' ' ')"
done
