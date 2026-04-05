import SwiftUI

// MARK: - TimerView

/// Instrument-panel countdown display for an active SelfControl block.
///
/// Layout mirrors MainSetupView exactly: same spacers, same font, same
/// component positions. The segmented slider shows elapsed progress
/// (non-interactive), and the DONE button is always in the layout at
/// opacity 0, fading in when the block completes. No layout shift.
@available(macOS 16.0, *)
struct TimerView: View {

    @Environment(TimerViewModel.self) private var timer
    @Environment(BlockStateViewModel.self) private var blockState
    @Environment(PreferencesViewModel.self) private var preferences

    @State private var pulseOpacity: Double = 1.0

    /// Number of segments filled based on elapsed progress.
    private var filledCount: Int {
        Int(round(timer.progress * 48))
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
                .frame(minHeight: NothingTheme.space3XL, maxHeight: NothingTheme.space4XL)

            // MARK: Primary — Countdown Display

            Text(timer.countdownDescription)
                .font(.nothingDisplayXL)
                .foregroundColor(
                    timer.isFinishing
                        ? NothingColors.textSecondary
                        : NothingColors.textDisplay
                )
                .textCase(.uppercase)
                .opacity(timer.shouldPulse ? pulseOpacity : 1.0)

            Spacer()
                .frame(minHeight: NothingTheme.spaceXL, maxHeight: NothingTheme.space2XL)

            // MARK: Secondary — Segmented Progress (slider in display mode)

            NothingSegmentedSlider(
                value: .constant(filledCount),
                maxValue: 48,
                isInteractive: false
            )
            .animation(.easeInOut(duration: 0.6), value: filledCount)
            .padding(.horizontal, NothingTheme.spaceXL)

            Spacer()

            // MARK: Tertiary — DONE Button (hidden until block completes)

            NothingPillButton(title: "DONE", variant: .secondary) {
                timer.stop()
                // Force fresh state so next START BLOCK works immediately
                SCSettings.shared().reload()
                blockState.refresh()
            }
            .opacity(timer.isFinishing ? 1.0 : 0.0)
            .allowsHitTesting(timer.isFinishing)
            .animation(.easeOut(duration: 0.3), value: timer.isFinishing)
            .padding(.horizontal, NothingTheme.spaceXL)
            .padding(.bottom, NothingTheme.spaceXL)
        }
        .onChange(of: timer.shouldPulse) { _, pulsing in
            if pulsing {
                withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                    pulseOpacity = 0.3
                }
            } else {
                withAnimation(.easeOut(duration: 0.2)) {
                    pulseOpacity = 1.0
                }
            }
        }
    }
}

// MARK: - Preview

@available(macOS 16.0, *)
#Preview {
    TimerView()
        .environment(TimerViewModel())
        .environment(BlockStateViewModel())
        .environment(PreferencesViewModel())
        .frame(width: 620, height: 520)
}
