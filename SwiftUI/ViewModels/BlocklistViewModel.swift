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

    /// Appends a domain to the list, persists, and notifies.
    func addDomain(_ domain: String) {
        let trimmed = domain.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        domains.append(trimmed)
        persist()
    }

    /// Removes the domain at the given index, persists, and notifies.
    func removeDomain(at index: Int) {
        guard domains.indices.contains(index) else { return }
        domains.remove(at: index)
        persist()
    }

    /// Updates the domain at the given index with a new value.
    /// If the new value is empty after trimming, the entry is removed.
    func updateDomain(at index: Int, newValue: String) {
        let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard domains.indices.contains(index) else { return }
        if trimmed.isEmpty {
            domains.remove(at: index)
        } else {
            domains[index] = trimmed
        }
        persist()
    }

    /// Basic validation: the string must be non-empty and resemble a hostname,
    /// IPv4/IPv6 address, or CIDR block.
    func isValidDomain(_ domain: String) -> Bool {
        let trimmed = domain.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        // Hostname pattern: labels separated by dots, optional trailing dot.
        // Also accepts bare labels (e.g. "localhost").
        let hostnamePattern = #"^(\*\.)?[a-zA-Z0-9]([a-zA-Z0-9\-]*[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9\-]*[a-zA-Z0-9])?)*\.?$"#

        // IPv4 with optional CIDR prefix length.
        let ipv4Pattern = #"^(\d{1,3}\.){3}\d{1,3}(/\d{1,2})?$"#

        // Simplified IPv6 (colon-hex groups, optional CIDR suffix).
        let ipv6Pattern = #"^[0-9a-fA-F:]+(/\d{1,3})?$"#

        let patterns = [hostnamePattern, ipv4Pattern, ipv6Pattern]
        return patterns.contains { pattern in
            trimmed.range(of: pattern, options: .regularExpression) != nil
        }
    }

    /// Imports a curated list of commonly distracting websites.
    func importCommonDistractions() {
        let distractingSites = HostImporter.commonDistractingWebsites() as? [String] ?? []
        mergeAndPersist(distractingSites)
    }

    /// Imports a curated list of major news and publication sites.
    func importNews() {
        let newsSites = HostImporter.newsAndPublications() as? [String] ?? []
        mergeAndPersist(newsSites)
    }

    /// Imports a curated list of NSFW/adult sites.
    func importNSFW() {
        let nsfwSites = HostImporter.nsfwWebsites() as? [String] ?? []
        mergeAndPersist(nsfwSites)
    }

    // MARK: - Private Helpers

    /// Merges new entries that are not already present, then persists.
    private func mergeAndPersist(_ newEntries: [String]) {
        let existingSet = Set(domains)
        let unique = newEntries.filter { !existingSet.contains($0) }
        guard !unique.isEmpty else { return }
        domains.append(contentsOf: unique)
        persist()
    }

    /// Writes the current domain list to UserDefaults and posts the configuration
    /// change notification on both the default and distributed centres.
    private func persist() {
        UserDefaults.standard.set(domains, forKey: "Blocklist")
        UserDefaults.standard.set(isAllowlist, forKey: "BlockAsWhitelist")
        postConfigurationChangedNotification()
    }

    private func postConfigurationChangedNotification() {
        let name = NSNotification.Name("SCConfigurationChangedNotification")
        NotificationCenter.default.post(name: name, object: self)
        DistributedNotificationCenter.default().postNotificationName(
            name,
            object: nil,
            userInfo: nil,
            deliverImmediately: true
        )
    }
}
