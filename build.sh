#!/bin/bash
cd ~/Desktop/selfcontrol
pkill -x SelfControl 2>/dev/null
xcodebuild -workspace SelfControl.xcworkspace -scheme SelfControl -configuration Debug build 2>&1 | tail -1
open ~/Library/Developer/Xcode/DerivedData/SelfControl-*/Build/Products/Debug/SelfControl.app
