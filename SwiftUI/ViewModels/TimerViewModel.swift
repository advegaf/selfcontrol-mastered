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

    /// Zero-padded two-digit hours string.
    var hoursString: String {
        String(format: "%02d", hours)
    }

    /// Zero-padded two-digit minutes string.
    var minutesString: String {
        String(format: "%02d", minutes)
    }

    /// Zero-padded two-digit seconds string.
    var secondsString: String {
        String(format: "%02d", seconds)
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

    /// Human-readable countdown string in the same format as the setup view.
    /// Drops leading zeros: "2H 30M 15S" → "30M 15S" → "15S" → "0S".
    var countdownDescription: String {
        if timeRemaining <= 0 { return "0S" }
        let h = hours
        let m = minutes
        let s = seconds
        var parts: [String] = []
        if h > 0 { parts.append("\(h)H") }
        if m > 0 { parts.append("\(m)M") }
        if s > 0 || parts.isEmpty { parts.append("\(s)S") }
        return parts.joined(separator: " ")
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
