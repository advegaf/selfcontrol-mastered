import SwiftUI

// MARK: - BlocklistViewModel

/// Manages the domain blocklist for editing in SwiftUI views.
///
/// Reads and writes the `Blocklist` and `BlockAsWhitelist` keys in
/// `UserDefaults.standard` and posts `SCConfigurationChangedNotification`
/// on every mutation so the rest of the app stays in sync.
@available(macOS 16.0, *)
@Observable
final class BlocklistViewModel {

    // MARK: - State

    /// The current list of blocked domains / hosts / IPs / CIDRs.
    var domains: [String] = []

    /// Whether the list operates as an allowlist (block everything *except* these).
    var isAllowlist: Bool = false

    /// When `true`, the list should be presented as read-only (e.g. during an active block).
    var isReadOnly: Bool = false

    // MARK: - Init

    init() {
        refresh()
    }

    // MARK: - Public Methods

    /// Re-reads the domain list and allowlist flag from UserDefaults.
    func refresh() {
        let defaults = UserDefaults.standard
        domains = (defaults.array(forKey: "Blocklist") as? [String]) ?? []
        isAllowlist = defaults.bool(forKey: "BlockAsWhitelist")
    }
}
