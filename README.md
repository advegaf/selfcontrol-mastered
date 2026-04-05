# SelfControl Mastered

<p align="center">
    <img src="./.github/docs/screenshot.png" />
</p>

## About

SelfControl Mastered is a redesigned fork of SelfControl for macOS with a Nothing-inspired design system. Block your own access to distracting websites, mail servers, or anything else on the Internet. Set a duration, add sites to your blocklist, and start a block. Until the timer expires, you will be unable to access those sites — even if you restart your computer or delete the application.

### What's New

- **Nothing design system** — OLED black UI, Ndot 57 dot-matrix typography, Space Grotesk/Mono type stack
- **Floating timer pill** — capsule overlay with contextual digit dimming (faded zeros), mode badge, and extend button
- **Faded-zero countdown** — inactive time units dim automatically (hours fade when 0, minutes fade when under 1 min)
- **Block modes** — switch between different blocking configurations
- **Menu bar integration** — quick access popover from the menu bar

## Credits

Remodeled by [Angel Vega](https://advegaf.com). Forked from [Charlie Stigler](http://charliestigler.com), [Steve Lambert](http://visitsteve.com), and [others](https://github.com/SelfControlApp/selfcontrol/graphs/contributors).

## License

SelfControl is free software under the GPL. See [this file](./COPYING) for more details.

## Building

Requires macOS 16.0+, Xcode, and CocoaPods.

```bash
git clone https://github.com/advegaf/selfcontrol-mastered.git
cd selfcontrol-mastered
pod install
./build.sh
```

Or manually:

1. `pod install`
2. Open `SelfControl.xcworkspace` (not `.xcodeproj`)
3. Build and run
