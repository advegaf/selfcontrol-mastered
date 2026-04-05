import SwiftUI
import Combine

// MARK: - BlockStateViewModel

/// Bridges SelfControl's Objective-C block state into SwiftUI via the @Observable macro.
///
/// Reads from `UserDefaults.standard`, `SCSettings.shared()`, and `SCUIUtilities`
/// to surface block configuration and runtime state. Listens for
/// `SCConfigurationChangedNotification` on both the default and distributed notification
/// centers so the UI stays in sync with helper-tool and preference changes.
@available(macOS 16.0, *)
@Observable
final class BlockStateViewModel {

    // MARK: - Published State

    /// Whether a SelfControl block is currently active on the system.
    var blockIsActive: Bool = false

    /// The date at which the active block will expire, or `nil` when no block is running.
    var blockEndDate: Date?

    /// Desired block duration in minutes. Writing this value persists it to UserDefaults.
    var blockDurationMinutes: Int = 0 {
        didSet {
            guard blockDurationMinutes != oldValue else { return }
            UserDefaults.standard.set(blockDurationMinutes, forKey: "BlockDuration")
        }
    }

    /// Maximum allowed block length in minutes, as configured by the user.
    var maxBlockLength: Int = 0

    /// The current blocklist (domains / hosts / IPs).
    var blocklist: [String] = []

    /// Whether the blocklist operates as an allowlist instead.
    var isAllowlist: Bool = false

    /// `true` while `AppController` is in the process of installing a block.
    var addingBlock: Bool = false

    /// Short human-readable summary of the blocklist contents.
    var blocklistTeaser: String = ""

    // MARK: - Computed Properties

    /// Human-readable description of the current block duration
    /// (e.g. "1 hour 30 minutes"), powered by `SCDurationSlider`.
    var durationDescription: String {
        let hours = blockDurationMinutes / 60
        let mins = blockDurationMinutes % 60
        if blockDurationMinutes == 0 { return "0 MIN" }
        if hours > 0 && mins > 0 { return "\(hours)H \(mins)M" }
        if hours > 0 { return "\(hours) HOUR\(hours > 1 ? "S" : "")" }
        return "\(mins) MIN"
    }

    /// Whether the user can currently initiate a new block.
    var canStartBlock: Bool {
        blockDurationMinutes > 0
            && (blocklist.count > 0 || isAllowlist)
            && !addingBlock
    }

    // MARK: - Private

    private var notificationObservers: [NSObjectProtocol] = []

    // MARK: - Init

    init() {
        refresh()
        registerNotifications()
    }

    deinit {
        for observer in notificationObservers {
            NotificationCenter.default.removeObserver(observer)
            DistributedNotificationCenter.default().removeObserver(observer)
        }
    }

    // MARK: - Public Methods

    /// Re-reads all block state from the Objective-C backend.
    func refresh() {
        let defaults = UserDefaults.standard
        let settings = SCSettings.shared()
        settings.reload()

        blockIsActive = SCUIUtilities.blockIsRunning()

        if let endDate = settings.value(forKey: "BlockEndDate") as? Date,
           endDate.timeIntervalSinceNow > 0 {
            blockEndDate = endDate
        } else if blockIsActive {
            // Block is running but we don't have an end date yet —
            // daemon hasn't synced. Keep existing endDate if we have one.
            // Don't nil it out.
        } else {
            blockEndDate = nil
        }

        blockDurationMinutes = defaults.integer(forKey: "BlockDuration")
        maxBlockLength = defaults.integer(forKey: "MaxBlockLength")
        blocklist = (defaults.array(forKey: "Blocklist") as? [String]) ?? []
        isAllowlist = defaults.bool(forKey: "BlockAsWhitelist")
        blocklistTeaser = SCUIUtilities.blockTeaserString(withMaxLength: 50)

        if let appController = NSApp.delegate as? AppController {
            addingBlock = appController.addingBlock
        }
    }

    /// Asks `AppController` to start a new block with the current configuration.
    /// Forces a settings reload first to avoid stale `blockIsRunning` checks.
    func startBlock() {
        guard let appController = NSApp.delegate as? AppController else { return }
        SCSettings.shared().reload()
        refresh()
        appController.addBlock(nil)
    }

    // MARK: - Private Helpers

    private func registerNotifications() {
        let notificationName = NSNotification.Name("SCConfigurationChangedNotification")

        let localObserver = NotificationCenter.default.addObserver(
            forName: notificationName,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.refresh()
        }
        notificationObservers.append(localObserver)

        let distributedObserver = DistributedNotificationCenter.default().addObserver(
            forName: notificationName,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.refresh()
        }
        notificationObservers.append(distributedObserver)
    }
}
