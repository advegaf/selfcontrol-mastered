import SwiftUI

// MARK: - TimerPillView

/// Floating pill that shows the block countdown on the desktop.
///
/// Ndot 57 dot-matrix digits with contextual dimming, mode badge (A/B),
/// and extend button (+) for adding time to the block.
/// Flat black capsule, no shadows, no blur — Nothing design.
///
/// Tapping the pill toggles the menu bar popover.
@available(macOS 16.0, *)
struct TimerPillView: View {

    @Environment(TimerViewModel.self) private var timer
    @Environment(ModeViewModel.self) private var modeVM

    // MARK: - Dimming Logic

    /// Hours dim when no hours remain.
    private var hoursDimmed: Bool { timer.hours == 0 }

    /// Minutes dim when no hours AND no minutes remain (under 1 min).
    private var minutesDimmed: Bool { timer.hours == 0 && timer.minutes == 0 }

    private let brightColor = Color.white.opacity(0.9)
    private let dimColor = Color.white.opacity(0.35)

    // MARK: - Body

    var body: some View {
        HStack(spacing: 0) {
            timerDisplay
            Spacer()
            HStack(spacing: 6) {
                modeBadge
                extendButton
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(width: 220)
        .background(Capsule().fill(Color.black))
        .clipShape(Capsule())
        .contentTransition(.numericText(countsDown: true))
        .animation(.easeOut(duration: 0.15), value: timer.hours)
        .animation(.easeOut(duration: 0.15), value: timer.minutes)
        .animation(.easeOut(duration: 0.15), value: timer.seconds)
        .onTapGesture {
            NotificationCenter.default.post(
                name: .selfControlTogglePopover,
                object: nil
            )
        }
    }

    // MARK: - Mode Badge

    private var modeBadge: some View {
        Text(modeVM.selectedMode.label)
            .font(.spaceMono(.bold, size: 9))
            .foregroundColor(.black)
            .frame(width: 20, height: 20)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(NothingColors.interactive)
            )
    }

    // MARK: - Extend Button

    private var extendButton: some View {
        Menu {
            Button("+5 MIN") { extendBlock(minutes: 5) }
            Button("+15 MIN") { extendBlock(minutes: 15) }
            Button("+30 MIN") { extendBlock(minutes: 30) }
            Button("+1 HR") { extendBlock(minutes: 60) }
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
                .frame(width: 20, height: 20)
                .background(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(Color.white.opacity(0.1))
                )
        }
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
    }

    // MARK: - Timer Display

    private var timerDisplay: some View {
        let h = String(format: "%02d", timer.hours)
        let m = String(format: "%02d", timer.minutes)
        let s = String(format: "%02d", timer.seconds)

        let hourColor = hoursDimmed ? dimColor : brightColor
        let minuteColor = minutesDimmed ? dimColor : brightColor

        return (
            Text(h).foregroundColor(hourColor)
            + Text(":").foregroundColor(hourColor)
            + Text(m).foregroundColor(minuteColor)
            + Text(":").foregroundColor(minuteColor)
            + Text(s).foregroundColor(brightColor)
        )
        .baselineOffset(-2)
        .font(.doto(size: 26))
        .tracking(26 * 0.04)
    }

    // MARK: - Extend Block

    private func extendBlock(minutes: Int) {
        // Instant UI update
        timer.extend(by: TimeInterval(minutes * 60))
        // Persist via daemon XPC
        guard let appController = NSApp.delegate as? AppController else { return }
        appController.extendBlockTime(minutes, lock: nil)
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let selfControlTogglePopover = Notification.Name("SelfControlTogglePopover")
    static let selfControlShowTimerPill = Notification.Name("SelfControlShowTimerPill")
    static let selfControlHideTimerPill = Notification.Name("SelfControlHideTimerPill")
}
