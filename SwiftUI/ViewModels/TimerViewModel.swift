import SwiftUI

// MARK: - TimerViewModel

/// Drives the countdown timer UI during an active SelfControl block.
///
/// Call `start(endDate:)` to begin the countdown. The view model fires a
/// one-second `Timer` that updates `timeRemaining` and the derived display
/// properties. Call `stop()` or let `deinit` clean up the timer.
@available(macOS 16.0, *)
@Observable
final class TimerViewModel {

    // MARK: - State

    /// Whether `start(endDate:)` has been called at least once.
    var hasStarted: Bool = false

    /// Seconds remaining until the block expires.
    var timeRemaining: TimeInterval = 0

    /// Total duration of the block in seconds (set once when the timer starts).
    var totalDuration: TimeInterval = 1

    // MARK: - Computed — Progress

    /// Normalised progress from 0 (just started) to 1 (complete).
    var progress: Double {
        guard totalDuration > 0 else { return 0 }
        return max(0, min(1, 1.0 - timeRemaining / totalDuration))
    }

    // MARK: - Computed — Time Components

    var hours: Int {
        max(0, Int(timeRemaining) / 3600)
    }

    var minutes: Int {
        max(0, (Int(timeRemaining) % 3600) / 60)
    }

    var seconds: Int {
        max(0, Int(timeRemaining) % 60)
    }

    // MARK: - Computed — Status

    /// `true` during the final 30 seconds of the countdown AND after completion.
    var shouldPulse: Bool {
        hasStarted && timeRemaining <= 30
    }

    /// `true` when the countdown has reached or passed zero (and was actually started).
    var isFinishing: Bool {
        hasStarted && timeRemaining <= 0
    }

    // MARK: - Private

    private var timer: Timer?
    private var endDate: Date?

    // MARK: - Lifecycle

    deinit {
        timer?.invalidate()
    }

    // MARK: - Public Methods

    /// Begin counting down toward `endDate`.
    ///
    /// - Parameter endDate: The `Date` at which the block expires.
    func start(endDate: Date) {
        self.endDate = endDate
        hasStarted = true
        totalDuration = max(1, endDate.timeIntervalSinceNow)
        updateTimeRemaining()

        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateTimeRemaining()
        }
        // Ensure the timer fires during tracking (e.g. scroll) run-loop modes.
        if let timer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    /// Optimistically extend the countdown by adding seconds to the end date.
    /// Updates the UI immediately without waiting for daemon confirmation.
    /// `reconcile(to:)` will overwrite this with the daemon's authoritative value
    /// once `SCConfigurationChangedNotification` fires.
    func extend(by seconds: TimeInterval) {
        guard let currentEnd = endDate else { return }
        let newEnd = currentEnd.addingTimeInterval(seconds)
        self.endDate = newEnd
        totalDuration += seconds
        updateTimeRemaining()
    }

    /// Reconcile the running countdown against the persistent `BlockEndDate` from
    /// `SCSettings`. Called by `BlockTimerCoordinator` whenever
    /// `BlockStateViewModel.blockEndDate` changes. Returns `true` when the new
    /// authoritative value is meaningfully *earlier* than what was being displayed
    /// (i.e. an optimistic extension was clamped, rejected, or otherwise reversed),
    /// so the caller can trigger a shake on the pill.
    @discardableResult
    func reconcile(to newEndDate: Date) -> Bool {
        let previous = self.endDate ?? newEndDate
        let delta = newEndDate.timeIntervalSince(previous)
        self.endDate = newEndDate
        // Keep totalDuration aligned with whatever the new authoritative end date
        // implies, so progress stays sane after a reconciliation.
        totalDuration = max(1, totalDuration + delta)
        updateTimeRemaining()
        return delta < -1.0
    }

    /// Stop the countdown and reset the timer.
    func stop() {
        timer?.invalidate()
        timer = nil
        endDate = nil
        hasStarted = false
    }

    // MARK: - Private Helpers

    private func updateTimeRemaining() {
        guard let endDate else {
            timeRemaining = 0
            return
        }
        timeRemaining = max(0, endDate.timeIntervalSinceNow)
    }
}
