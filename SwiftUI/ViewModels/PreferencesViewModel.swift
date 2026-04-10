import SwiftUI
import ServiceManagement

// MARK: - PreferencesViewModel

/// Exposes every user-configurable SelfControl preference as an `@Observable`
/// property with automatic persistence to `UserDefaults.standard`.
///
/// Each property's `didSet` writes the new value back to UserDefaults so that
/// the Objective-C backend picks up changes immediately.
@available(macOS 16.0, *)
@Observable
final class PreferencesViewModel {

    // MARK: - General

    /// Whether the app starts automatically at user login.
    var launchAtLogin: Bool = false {
        didSet {
            guard launchAtLogin != oldValue else { return }
            do {
                if launchAtLogin {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                print("[Preferences] Launch at login failed: \(error)")
                launchAtLogin = SMAppService.mainApp.status == .enabled
            }
        }
    }

    /// Whether Sparkle checks for updates automatically in the background.
    var automaticallyChecksForUpdates: Bool {
        get { SUUpdater.shared().automaticallyChecksForUpdates }
        set { SUUpdater.shared().automaticallyChecksForUpdates = newValue }
    }

    // MARK: - Timer & Badge

    /// Whether the timer window floats above other windows.
    var timerWindowFloats: Bool = false {
        didSet {
            guard timerWindowFloats != oldValue else { return }
            UserDefaults.standard.set(timerWindowFloats, forKey: "TimerWindowFloats")
        }
    }

    /// Show a floating timer pill on the desktop when the main window is closed
    /// during an active block.
    var showTimerPill: Bool = true {
        didSet {
            guard showTimerPill != oldValue else { return }
            UserDefaults.standard.set(showTimerPill, forKey: "ShowTimerPill")
        }
    }

    /// When true the pill floats above all windows; when false it sits at
    /// desktop level (behind all app windows, like a desktop widget).
    var timerPillFloatsOnTop: Bool = false {
        didSet {
            guard timerPillFloatsOnTop != oldValue else { return }
            UserDefaults.standard.set(timerPillFloatsOnTop, forKey: "TimerPillFloatsOnTop")
        }
    }

    // MARK: - Sound

    /// Whether a sound plays when the block ends.
    var blockSoundShouldPlay: Bool = false {
        didSet {
            guard blockSoundShouldPlay != oldValue else { return }
            UserDefaults.standard.set(blockSoundShouldPlay, forKey: "BlockSoundShouldPlay")
        }
    }

    /// Index into `systemSoundNames` for the chosen block-end sound.
    var blockSoundIndex: Int = 0 {
        didSet {
            guard blockSoundIndex != oldValue else { return }
            UserDefaults.standard.set(blockSoundIndex, forKey: "BlockSound")
        }
    }

    // MARK: - Error Reporting

    /// Whether Sentry / crash reporting is enabled.
    var enableErrorReporting: Bool = false {
        didSet {
            guard enableErrorReporting != oldValue else { return }
            UserDefaults.standard.set(enableErrorReporting, forKey: "EnableErrorReporting")
        }
    }

    // MARK: - Blocklist Behaviour

    /// Highlight entries in the blocklist that do not resolve.
    var highlightInvalidHosts: Bool = false {
        didSet {
            guard highlightInvalidHosts != oldValue else { return }
            UserDefaults.standard.set(highlightInvalidHosts, forKey: "HighlightInvalidHosts")
        }
    }

    /// Automatically include common subdomains (e.g. www) when blocking a domain.
    var evaluateCommonSubdomains: Bool = true {
        didSet {
            guard evaluateCommonSubdomains != oldValue else { return }
            UserDefaults.standard.set(evaluateCommonSubdomains, forKey: "EvaluateCommonSubdomains")
        }
    }

    /// Follow links on blocked pages and block linked domains as well.
    var includeLinkedDomains: Bool = true {
        didSet {
            guard includeLinkedDomains != oldValue else { return }
            UserDefaults.standard.set(includeLinkedDomains, forKey: "IncludeLinkedDomains")
        }
    }

    /// Allow connections to local-network addresses while a block is active.
    var allowLocalNetworks: Bool = true {
        didSet {
            guard allowLocalNetworks != oldValue else { return }
            UserDefaults.standard.set(allowLocalNetworks, forKey: "AllowLocalNetworks")
        }
    }

    /// Clear DNS and browser caches when the block starts.
    var clearCaches: Bool = true {
        didSet {
            guard clearCaches != oldValue else { return }
            UserDefaults.standard.set(clearCaches, forKey: "ClearCaches")
        }
    }

    /// Verify that the network is reachable before starting a block.
    var verifyInternetConnection: Bool = false {
        didSet {
            guard verifyInternetConnection != oldValue else { return }
            UserDefaults.standard.set(verifyInternetConnection, forKey: "VerifyInternetConnection")
        }
    }

    // MARK: - Appearance

    /// Background style for the Nothing-inspired UI.
    var backgroundStyle: NothingBackgroundStyle = .dotGrid {
        didSet {
            guard backgroundStyle != oldValue else { return }
            UserDefaults.standard.set(backgroundStyle.rawValue, forKey: "NothingBackgroundStyle")
        }
    }

    // MARK: - Computed

    /// Names of system sounds available for the block-end alert.
    var systemSoundNames: [String] {
        SCConstants.systemSoundNames
    }

    // MARK: - Init

    init() {
        let defaults = UserDefaults.standard

        launchAtLogin = SMAppService.mainApp.status == .enabled
        timerWindowFloats = defaults.bool(forKey: "TimerWindowFloats")
        showTimerPill = defaults.object(forKey: "ShowTimerPill") as? Bool ?? true
        timerPillFloatsOnTop = defaults.bool(forKey: "TimerPillFloatsOnTop")
        blockSoundShouldPlay = defaults.bool(forKey: "BlockSoundShouldPlay")
        blockSoundIndex = defaults.integer(forKey: "BlockSound")
        enableErrorReporting = defaults.bool(forKey: "EnableErrorReporting")
        highlightInvalidHosts = defaults.bool(forKey: "HighlightInvalidHosts")
        evaluateCommonSubdomains = defaults.bool(forKey: "EvaluateCommonSubdomains")
        includeLinkedDomains = defaults.bool(forKey: "IncludeLinkedDomains")
        allowLocalNetworks = defaults.bool(forKey: "AllowLocalNetworks")
        clearCaches = defaults.bool(forKey: "ClearCaches")
        verifyInternetConnection = defaults.bool(forKey: "VerifyInternetConnection")

        if let rawStyle = defaults.string(forKey: "NothingBackgroundStyle"),
           let style = NothingBackgroundStyle(rawValue: rawStyle) {
            backgroundStyle = style
        }
    }
}
