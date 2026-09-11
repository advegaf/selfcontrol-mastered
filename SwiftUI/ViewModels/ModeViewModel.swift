import SwiftUI

// MARK: - ModeViewModel

/// Manages the two blocking profiles (A-mode and B-mode).
///
/// Each mode stores its own duration, domain list, and allow/block toggle.
/// On first launch, Mode A is seeded from the existing `Blocklist`,
/// `BlockDuration`, and `BlockAsWhitelist` UserDefaults to preserve
/// existing users' configurations. Mode B starts empty.
@available(macOS 16.0, *)
@Observable
final class ModeViewModel {

    // MARK: - State

    /// The currently selected mode.
    var selectedMode: ModeID = .a

    /// Mode A configuration.
    var modeA: BlockMode

    /// Mode B configuration.
    var modeB: BlockMode

    // MARK: - Computed Properties

    /// The active mode's configuration.
    var currentMode: BlockMode {
        get {
            switch selectedMode {
            case .a: return modeA
            case .b: return modeB
            }
        }
        set {
            switch selectedMode {
            case .a: modeA = newValue
            case .b: modeB = newValue
            }
            save(newValue)
        }
    }

    // MARK: - Init

    init() {
        let defaults = UserDefaults.standard

        if SCUIUtilities.demoIsActive() {
            // A curated pair of modes. Five sites that read as somebody's real
            // blocklist without being anybody's, and a second mode so the
            // selector has something to select. Nothing here is written back:
            // `save` returns early in a demo run.
            modeA = BlockMode(
                id: .a,
                durationMinutes: 45,
                domains: ["x.com", "reddit.com", "news.ycombinator.com", "youtube.com", "instagram.com"],
                isAllowlist: false
            )
            modeB = BlockMode(
                id: .b,
                durationMinutes: 90,
                domains: ["mail.google.com", "slack.com"],
                isAllowlist: false
            )
            return
        }

        if let dataA = defaults.data(forKey: BlockMode.keyA),
           let decoded = try? JSONDecoder().decode(BlockMode.self, from: dataA) {
            modeA = decoded
        } else {
            // Migration: seed Mode A from existing blocklist
            modeA = Self.migrateFromLegacy()
        }

        if let dataB = defaults.data(forKey: BlockMode.keyB),
           let decoded = try? JSONDecoder().decode(BlockMode.self, from: dataB) {
            modeB = decoded
        } else {
            modeB = BlockMode.defaultB()
        }

        // Persist migrated data if needed
        if defaults.data(forKey: BlockMode.keyA) == nil {
            save(modeA)
        }
        if defaults.data(forKey: BlockMode.keyB) == nil {
            save(modeB)
        }
    }

    // MARK: - Public Methods

    /// Updates the current mode's duration and persists.
    func updateDuration(_ minutes: Int) {
        var mode = currentMode
        mode.durationMinutes = minutes
        currentMode = mode
    }

    /// Returns the mode configuration for a given ID.
    func mode(for id: ModeID) -> BlockMode {
        switch id {
        case .a: return modeA
        case .b: return modeB
        }
    }

    /// Updates a specific mode and persists.
    func update(_ mode: BlockMode) {
        switch mode.id {
        case .a: modeA = mode
        case .b: modeB = mode
        }
        save(mode)
    }

    /// Writes the current mode's blocklist and settings into the standard
    /// UserDefaults keys that the Obj-C layer reads when starting a block.
    func writeCurrentModeToLegacyDefaults() {
        let defaults = UserDefaults.standard
        let mode = currentMode
        defaults.setUnlessDemo(mode.domains, forKey: "Blocklist")
        defaults.setUnlessDemo(mode.durationMinutes, forKey: "BlockDuration")
        defaults.setUnlessDemo(mode.isAllowlist, forKey: "BlockAsWhitelist")
    }

    // MARK: - Private

    private func save(_ mode: BlockMode) {
        // Every write of a mode lands here, from the seeding in `init` and from
        // `currentMode`'s didSet both, so this is the one place a demo run has
        // to be stopped from touching the real preferences domain.
        if SCUIUtilities.demoIsActive() { return }
        guard let data = try? JSONEncoder().encode(mode) else { return }
        UserDefaults.standard.set(data, forKey: BlockMode.key(for: mode.id))
    }

    /// Seeds Mode A from existing UserDefaults blocklist data.
    private static func migrateFromLegacy() -> BlockMode {
        let defaults = UserDefaults.standard
        let domains = (defaults.array(forKey: "Blocklist") as? [String]) ?? []
        let duration = defaults.integer(forKey: "BlockDuration")
        let isAllowlist = defaults.bool(forKey: "BlockAsWhitelist")
        return BlockMode(
            id: .a,
            durationMinutes: duration,
            domains: domains,
            isAllowlist: isAllowlist
        )
    }
}
