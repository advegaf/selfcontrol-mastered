# Contributing

```sh
pod install     # once, and again whenever Podfile.lock moves
./build.sh      # build, install into /Applications, launch
```

Open `SelfControl.xcworkspace`, never `SelfControl.xcodeproj`. CocoaPods puts
the dependencies in the workspace and the project alone will not link.

`build.sh` installs into `/Applications` on purpose. The helper's launchd plist
names an absolute path in its `ProgramArguments`, so a copy running out of a
build directory can talk to a daemon but cannot be the app that daemon was
installed for.

There is no xcodegen here. `SelfControl.xcodeproj/project.pbxproj` is the source
of truth, so a new Swift file has to be added through Xcode rather than by
dropping it in a directory.

## Where the two halves meet

The blocking is Objective-C and it is upstream's: `AppController`, the daemon
under `Daemon/`, and the hosts file work in `Common/`. The interface is SwiftUI
under `SwiftUI/`, and it reaches the Objective-C side through
`SwiftUI/Bridge/SelfControlBridge.swift` and the `SCUIUtilities` class methods.

`SCUIUtilities.blockIsRunning` is the one question both halves ask, so it is the
one place a change to what "blocking" means belongs.

## Images

```sh
Tools/Screenshots/make-docs-images.sh
```

Builds nothing; run `./build.sh` first. It launches the app three times under
`SELFCONTROL_DEMO=curated`, photographs the panel and the floating pill through
the window server, and composites them onto a flat #101010 ground.

`SELFCONTROL_DEMO=curated` does four things, and none of them are optional:

- `blockIsRunning` answers from the environment rather than the daemon, so a
  picture of a running block needs no block and no password.
- The panel opens itself and stops hiding when the app deactivates, which is
  otherwise a second or two after launch.
- The modes come from a fixture in `ModeViewModel`, not from your blocklist.
- Every preference write goes through `UserDefaults.setUnlessDemo`, which does
  nothing in a demo run. The script also exports the real preferences domain
  before the run and imports it again afterwards, in a trap, so an interrupted
  run leaves nothing behind either.

Check that second guarantee rather than trusting it:

```sh
defaults export org.eyebeam.SelfControl before.plist
Tools/Screenshots/make-docs-images.sh
defaults export org.eyebeam.SelfControl after.plist
diff <(plutil -p before.plist) <(plutil -p after.plist)   # must be empty
```

## Releasing

```sh
./release.sh            # REBUILD=1 to force a fresh build
```

Clean Release build, every embedded binary re-signed with a hardened runtime
and a secure timestamp, notarized, stapled, then the disk image built, signed,
notarized and stapled in turn. It needs a Developer ID Application certificate
and a notarytool keychain profile named `selfcontrol-notary`.
