#!/bin/bash
# Debug build, installed into /Applications and launched.
#
# It has to land in /Applications: the daemon's plist names an absolute path
# for ProgramArguments, so a copy running out of DerivedData cannot start a
# block.
set -euo pipefail
cd "$(dirname "$0")"

pkill -x SelfControl 2>/dev/null || true
pkill -x org.eyebeam.selfcontrold 2>/dev/null || true

xcodebuild -workspace SelfControl.xcworkspace -scheme SelfControl \
    -configuration Debug DEVELOPMENT_TEAM=DV483F72N3 build

# Most recently modified, because a renamed checkout leaves stale DerivedData
# directories behind and the oldest one is not the one that was just built.
BUILT_APP=$(ls -dt ~/Library/Developer/Xcode/DerivedData/SelfControl-*/Build/Products/Debug/SelfControl.app 2>/dev/null | head -1)
[ -n "$BUILT_APP" ] || { echo "no built SelfControl.app under DerivedData" >&2; exit 1; }

# Checked before the delete, not after. An earlier version of this script ran
# the rm unconditionally and with no `set -e` above it, so a failed build
# uninstalled the working copy and installed nothing.
rm -rf /Applications/SelfControl.app
ditto "$BUILT_APP" /Applications/SelfControl.app
open /Applications/SelfControl.app
