//
//  LockMode.swift
//  SelfControl
//

import Foundation

/// How a block ends. Orthogonal to `ModeID` (which picks a blocklist profile).
/// Persisted to `UserDefaults["LockMode"]` when idle; mirrored into
/// `SCSettings["ActiveBlockEndCondition"]` while a block is active so the daemon sees it.
enum LockMode: String, Codable, CaseIterable, Identifiable {
    case time
    case qr

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .time: return "Time"
        case .qr:   return "QR"
        }
    }

    static let userDefaultsKey = "LockMode"

    static var current: LockMode {
        get {
            let raw = UserDefaults.standard.string(forKey: userDefaultsKey) ?? "time"
            return LockMode(rawValue: raw) ?? .time
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: userDefaultsKey)
        }
    }
}
