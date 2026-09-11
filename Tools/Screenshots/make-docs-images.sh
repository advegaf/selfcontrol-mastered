#!/usr/bin/env bash
# Regenerates every image in docs/images.
#
# Two steps. First the captures: the menu bar panel and the floating pill,
# photographed through the window server into a scratch directory. Then one
# pass of ArticleImages.swift, which draws the ground, composites the captures
# onto it and writes the files the README embeds.
#
# Every launch carries SELFCONTROL_DEMO=curated. That does three things: the
# app reports a fixed block rather than asking the daemon about a real one, it
# opens its panel itself instead of waiting for a click on the menu bar, and it
# keeps the panel from hiding when the app deactivates. No block is installed
# on the machine taking the picture and no password is asked for.
#
# The blocklist, the duration and the preferences come in through the argument
# domain, which macOS reads ahead of the persistent one. A preference the app
# writes back still lands in the real domain, so the domain is exported before
# the run and imported again after it, whatever happens.
set -Eeuo pipefail
cd "$(dirname "$0")/../.."

APP=$(/bin/ls -dt ~/Library/Developer/Xcode/DerivedData/SelfControl-*/Build/Products/Debug/SelfControl.app 2>/dev/null | head -1)
[[ -n "$APP" && -x "$APP/Contents/MacOS/SelfControl" ]] || {
    echo "build first: ./build.sh" >&2; exit 1; }
BIN="$APP/Contents/MacOS/SelfControl"

RAW="${SC_RAW_DIR:-$(mktemp -d)}"
BACKUP="$(mktemp -t selfcontrol-prefs).plist"
mkdir -p "$RAW" docs/images

defaults export org.eyebeam.SelfControl "$BACKUP"
restore() {
    pkill -x SelfControl || true
    defaults import org.eyebeam.SelfControl "$BACKUP"
}
trap restore EXIT

# A curated blocklist. Five sites that read as somebody's real blocklist
# without being anybody's.
BLOCKLIST='("x.com","reddit.com","news.ycombinator.com","youtube.com","instagram.com")'
DEFAULTS=(-Blocklist "$BLOCKLIST" -BlockDuration 45 -MaxBlockLength 1440
          -BlockAsWhitelist NO -ShowTimerPill YES -TimerPillFloatsOnTop YES
          -SUEnableAutomaticChecks NO)

launch() {                  # launch [extra env assignments...]
    pkill -x SelfControl || true
    sleep 1
    env SELFCONTROL_DEMO=curated "$@" "$BIN" "${DEFAULTS[@]}" >/dev/null 2>&1 &
    # The panel is opened from a delayed selector after the status item exists,
    # and the pill only appears once the panel's content view has run. Six is
    # the point where both were reliably up; four caught the panel mid-layout.
    sleep 6
}

panel_shot() {              # panel_shot <name>
    swift Scripts/window-shot.swift SelfControl "$RAW/$1.png" --shadow \
        --min-width 400 >/dev/null
}

launch SELFCONTROL_DEMO_BLOCK=1
panel_shot blocking
swift Scripts/window-shot.swift SelfControl "$RAW/pill.png" \
    --min-width 150 --max-width 320 >/dev/null

launch
panel_shot idle

launch SELFCONTROL_DEMO_PAGE=settings
panel_shot settings

pkill -x SelfControl || true

# The icon, at the size the hero draws it. Copied rather than re-exported:
# this is the file the app ships.
sips -s format png -Z 1024 SelfControlIcon.icns --out "$RAW/logo.png" >/dev/null
cp "$RAW/logo.png" docs/images/logo.png

swift Tools/Screenshots/ArticleImages.swift "$RAW" docs/images

echo "docs/images:"
/bin/ls -1 docs/images
