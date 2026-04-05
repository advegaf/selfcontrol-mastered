import SwiftUI

// MARK: - TimerPillView

/// Floating pill that shows the block countdown on the desktop.
///
/// Matches the Dynamic Island / hardware display aesthetic: large Doto
/// dot-matrix digits on a pure black capsule. No shadows, no blur, no
/// border — flat surface per Nothing design.
@available(macOS 16.0, *)
struct TimerPillView: View {

    @Environment(TimerViewModel.self) private var timer

    /// Fixed-width countdown — always "HH:MM:SS" so the pill never resizes.
    private var fixedCountdown: String {
        String(format: "%02d:%02d:%02d", timer.hours, timer.minutes, timer.seconds)
    }

    var body: some View {
        Text(fixedCountdown)
            .font(.doto(.regular, size: 22))
            .monospacedDigit()
            .tracking(2.5)
            .foregroundColor(.white.opacity(0.9))
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.black)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .fixedSize()
            .contentTransition(.numericText(countsDown: true))
            .animation(.easeOut(duration: 0.15), value: fixedCountdown)
            .onTapGesture {
                NotificationCenter.default.post(
                    name: .selfControlReopenMainWindow,
                    object: nil
                )
            }
    }
}

// MARK: - Notification Name

extension Notification.Name {
    static let selfControlReopenMainWindow = Notification.Name("SelfControlReopenMainWindow")
    static let selfControlShowTimerPill = Notification.Name("SelfControlShowTimerPill")
    static let selfControlHideTimerPill = Notification.Name("SelfControlHideTimerPill")
}
