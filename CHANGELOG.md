# Changelog

## 1.0.3

- **`build.sh` no longer uninstalls the app when the build fails.** It changed
  directory to a path that has not existed for some time, carried no `set -e`,
  and then ran `rm -rf /Applications/SelfControl.app` whatever had happened
  above it. A failed build deleted the working copy and installed nothing in its
  place. It now resolves its own directory, stops at the first error, and checks
  it has something to install before it deletes anything.
- **The menu bar panel cannot land off every display.** Its position came
  straight from the status item's frame with no clamp, so an item near the right
  edge pushed the panel half off it, and a button whose window frame was not
  ready yet reported a midpoint thousands of points to the left. The window
  server has nothing to draw into out there, so the panel was created and never
  appeared. It is clamped to the visible frame of whichever screen the button is
  on.
- Issue templates sent anyone reporting a bug to upstream's wiki and discussion
  board, and blank issues were switched off, so there was no way to report a bug
  in this fork to this fork.
- `Tools/Screenshots/make-docs-images.sh` regenerates every image in the README.
  It photographs the panel and the floating pill through the window server and
  composites them onto a flat ground, running against a fixture rather than your
  blocklist, so no real block is installed and no password is asked for.

## 1.0.2

- **Launch at login.** A toggle in Preferences, General, registered through
  `SMAppService.mainApp` rather than a plist somebody has to maintain.
- **The update toggle does something.** "Automatically check for updates" was a
  switch wired to nothing. It now drives Sparkle's background schedule.
- **The pill toggle takes effect now.** Turning "Show floating pill when window
  closes" on or off during a running block used to need a restart before it
  meant anything.

## 1.0.1

A dead code sweep, which is less a feature than an admission of how much of the
fork was scaffolding.

- Removed the Objective-C preference controllers the SwiftUI settings replaced,
  their orphaned xib files, a disabled telemetry block, and a legacy header
  nothing included.
- Removed five views nothing could reach, three unused components, and a long
  tail of design tokens and view model methods that existed for a design that
  had moved on. [Periphery](https://github.com/peripheryapp/periphery) found
  them; `.periphery.yml` is checked in so the next sweep is one command.
- Closing the timer window stopped quitting the app. It is a menu bar app; the
  window is a view onto the block, not the block.

## 1.0.0

The first release of the fork.

Upstream's blocking is untouched: the hosts file, the helper, and the rule that
a block cannot be taken back. What changed is everything above it.

- **A Nothing-shaped interface.** OLED black, Ndot 57 for the dot-matrix
  digits, Space Grotesk and Space Mono elsewhere.
- **A floating pill.** Close the window and the countdown stays on screen, with
  the running mode and a button that adds time. It sits at the desktop level
  unless you ask it to float.
- **Digits that dim as they empty.** Under an hour the hours fade, under a
  minute the minutes go with them, so the number still moving is the one you
  read.
- **Two modes.** A and B each hold their own list, length and allow/block
  choice. Switching is a click.
- **A menu bar app.** The interface is a popover under the status item rather
  than a window to go and find.
