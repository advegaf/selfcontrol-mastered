import Foundation

// MARK: - Mode Identifier

enum ModeID: String, Codable, CaseIterable, Identifiable {
    case a
    case b

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .a: return "a-mode"
        case .b: return "b-mode"
        }
    }

    var label: String {
        switch self {
        case .a: return "A"
        case .b: return "B"
        }
    }
}

// MARK: - BlockMode

/// A blocking profile that stores an independent blocklist, duration, and
/// allow/block toggle. SelfControl supports exactly two modes: A and B.
struct BlockMode: Codable, Equatable {

    /// Which mode this is (a or b).
    var id: ModeID

    /// Block duration in minutes.
    var durationMinutes: Int

    /// The list of blocked (or allowed) domains.
    var domains: [String]

    /// Whether the domain list operates as an allowlist.
    var isAllowlist: Bool

    // MARK: - Defaults

    static func defaultB() -> BlockMode {
        BlockMode(id: .b, durationMinutes: 0, domains: [], isAllowlist: false)
    }

    // MARK: - Persistence Keys

    static let keyA = "BlockModeA"
    static let keyB = "BlockModeB"

    static func key(for id: ModeID) -> String {
        switch id {
        case .a: return keyA
        case .b: return keyB
        }
    }

    // MARK: - Short Duration Label

    /// Returns a compact label like "15m" or "1h 30m".
    var shortDurationLabel: String {
        let hours = durationMinutes / 60
        let mins = durationMinutes % 60
        if durationMinutes == 0 { return "0m" }
        if hours > 0 && mins > 0 { return "\(hours)h \(mins)m" }
        if hours > 0 { return "\(hours)h" }
        return "\(mins)m"
    }
}
