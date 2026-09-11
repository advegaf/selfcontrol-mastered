import SwiftUI

// MARK: - SelfControlBridge

/// Singleton bridge that owns the SwiftUI view models and vends
/// `NSHostingView`-backed views to the Objective-C layer.
///
/// Usage from Obj-C:
/// ```objc
/// NSView *menuBarView = [[SelfControlBridge shared] makeMenuBarContentView];
/// ```
@available(macOS 16.0, *)
@objc
final class SelfControlBridge: NSObject {

    // MARK: - Singleton

    @objc static let shared = SelfControlBridge()

    // MARK: - View Models

    let blockState: BlockStateViewModel
    let timerVM: TimerViewModel
    let blocklistVM: BlocklistViewModel
    let preferencesVM: PreferencesViewModel
    let modeVM: ModeViewModel

    // MARK: - Init

    override init() {
        NothingFontRegistration.registerFonts()

        blockState = BlockStateViewModel()
        timerVM = TimerViewModel()
        blocklistVM = BlocklistViewModel()
        preferencesVM = PreferencesViewModel()
        modeVM = ModeViewModel()

        super.init()
    }

    // MARK: - View Factories

    /// Returns the menu bar popover content view wrapped in an `NSHostingView`.
    /// All view models are injected as environment objects.
    @objc func makeMenuBarContentView() -> NSView {
        let view = MenuBarContentView()
            .environment(blockState)
            .environment(timerVM)
            .environment(blocklistVM)
            .environment(preferencesVM)
            .environment(modeVM)
        return NSHostingView(rootView: view)
    }
}

// MARK: - Demo-safe preference writes

extension UserDefaults {

    /// Writes a preference, unless this is a demo run.
    ///
    /// Every view model persists the same way: a `didSet` that writes the new
    /// value straight back to `UserDefaults.standard`. Under
    /// `SELFCONTROL_DEMO=curated` the values being set come from the argument
    /// domain, which is where the screenshot pipeline puts its fixture, and
    /// writing one of those back copies the fixture into the real preferences
    /// of whoever ran the script. Routing the writes through here stops that in
    /// one place rather than in each of the twenty-odd `didSet`s.
    func setUnlessDemo(_ value: Any?, forKey key: String) {
        if SCUIUtilities.demoIsActive() { return }
        set(value, forKey: key)
    }
}
