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
    @Environment(BlockStateViewModel.self) private var blockState

    // MARK: - Shake State

    /// Horizontal offset applied to the pill capsule for the failure-shake animation.
    /// Driven by `.selfControlPillShake` notification posted by `BlockTimerCoordinator`
    /// when an optimistic extension got clamped or rejected by the daemon.
    @State private var shakeOffset: CGFloat = 0

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
        .offset(x: shakeOffset)
        .onTapGesture {
            NotificationCenter.default.post(
                name: .selfControlTogglePopover,
                object: nil
            )
        }
        .onReceive(NotificationCenter.default.publisher(for: .selfControlPillShake)) { _ in
            playShake()
        }
    }

    // MARK: - Shake Animation

    /// Three-oscillation horizontal shake (~6pt amplitude) used to signal that an
    /// optimistic extension got clamped or rejected by the daemon. Total duration ~240ms.
    private func playShake() {
        let amplitude: CGFloat = 6
        let step: TimeInterval = 0.04
        let offsets: [CGFloat] = [-amplitude, amplitude, -amplitude, amplitude, -amplitude / 2, 0]
        for (i, value) in offsets.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + step * Double(i)) {
                withAnimation(.easeOut(duration: step)) {
                    shakeOffset = value
                }
            }
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

    /// Optimistically bumps the displayed countdown and asks `AppController` to
    /// persist the new block end date via the daemon XPC. The minutes are clamped
    /// to the user's configured `MaxBlockLength` so the optimistic display matches
    /// what the daemon will actually write — preventing a surprise pull-back.
    /// If the daemon rejects or clamps further, `BlockTimerCoordinator` reconciles
    /// the running timer and shakes the pill (see `playShake()`).
    private func extendBlock(minutes: Int) {
        let cap = blockState.maxBlockLength
        let clamped = (cap > 0) ? min(minutes, cap) : minutes
        guard clamped > 0 else { return }
        timer.extend(by: TimeInterval(clamped * 60))
        guard let appController = NSApp.delegate as? AppController else { return }
        appController.extendBlockTime(clamped, lock: nil)
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let selfControlTogglePopover = Notification.Name("SelfControlTogglePopover")
    static let selfControlHideTimerPill = Notification.Name("SelfControlHideTimerPill")
    /// Posted by `BlockTimerCoordinator` when an optimistic extend was clamped or
    /// rejected by the daemon and the pill should shake to surface the failure.
    static let selfControlPillShake = Notification.Name("SelfControlPillShake")
}
