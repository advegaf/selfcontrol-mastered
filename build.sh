#!/bin/bash
cd ~/Desktop/selfcontrol
pkill -x SelfControl 2>/dev/null
pkill -x org.eyebeam.selfcontrold 2>/dev/null
xcodebuild -workspace SelfControl.xcworkspace -scheme SelfControl -configuration Debug build 2>&1 | tail -1

# Find the most recently modified built app (avoids stale DerivedData dirs)
BUILT_APP=$(ls -dt ~/Library/Developer/Xcode/DerivedData/SelfControl-*/Build/Products/Debug/SelfControl.app 2>/dev/null | head -1)

# Install to /Applications so the daemon plist ProgramArguments path resolves
rm -rf /Applications/SelfControl.app 2>/dev/null
ditto "$BUILT_APP" /Applications/SelfControl.app
open /Applications/SelfControl.app
