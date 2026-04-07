import SwiftUI

// MARK: - MenuBarContentView

/// Root view for the NSPopover menu bar interface.
///
/// State machine with four visual states:
/// - Idle: mode selector, timer display, duration slider, START BLOCK
/// - Active: simplified countdown only + cog
/// - Completed: countdown at 00:00:00 + DONE button
/// - Settings: back arrow + settings content (blocklist editor, prefs, about)
///
/// The cog icon is available in all non-settings states.
/// Fixed frame: 320 x 380. Content adapts between states.
@available(macOS 16.0, *)
struct MenuBarContentView: View {

    @Environment(TimerViewModel.self) private var timer
    @Environment(BlockStateViewModel.self) private var blockState
    @Environment(ModeViewModel.self) private var modeVM
    @Environment(PreferencesViewModel.self) private var preferences

    @State private var showSettings: Bool = false
    @State private var errorMessage: String? = nil

    var body: some View {
        ZStack {
            NothingDotGridBackground(style: preferences.backgroundStyle)

            VStack(spacing: 0) {
                // MARK: Top Bar

                topBar
                    .padding(.horizontal, NothingTheme.spaceMD)
                    .padding(.top, NothingTheme.spaceSM)

                // MARK: Content

                if showSettings {
                    SettingsContainerView()
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .trailing).combined(with: .opacity)
                        ))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if timer.hasStarted {
                    activeTimerContent
                        .transition(.opacity)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    idleContent
                        .transition(.opacity)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .animation(.easeOut(duration: NothingTheme.transitionDuration), value: timer.hasStarted)
        }
        .frame(width: 450, height: 380)
        .blockTimerCoordination()
        .onChange(of: timer.hasStarted) { _, started in
            // Close settings when transitioning back to idle
            if !started && showSettings {
                showSettings = false
            }
            // Show floating pill when block starts
            if started {
                TimerPillWindowController.shared.show()
            }
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            if showSettings {
                // Back arrow
                Button {
                    withAnimation(.easeOut(duration: NothingTheme.transitionDuration)) {
                        showSettings = false
                    }
                } label: {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(NothingColors.textSecondary)
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            } else if !timer.hasStarted {
                // Mode selector (idle state only)
                ModeSelector()
            }

            Spacer()

            // Cog button (always visible except in settings)
            if !showSettings {
                Button {
                    withAnimation(.easeOut(duration: NothingTheme.transitionDuration)) {
                        showSettings.toggle()
                    }
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(NothingColors.textSecondary)
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Idle Content

    private var idleContent: some View {
        @Bindable var modeVM = modeVM

        let totalMins = modeVM.currentMode.durationMinutes
        let h = totalMins / 60
        let m = totalMins % 60

        return VStack(spacing: 0) {
            Spacer()

            // Primary: Duration Display — separated HH MM SS with labels
            timerDigitsView(
                hours: h, minutes: m, seconds: 0,
                color: NothingColors.textDisplay
            )

            Spacer()
                .frame(height: NothingTheme.spaceLG)

            // Secondary: Segmented Slider
            NothingSegmentedSlider(
                value: Binding(
                    get: { modeVM.currentMode.durationMinutes },
                    set: { modeVM.updateDuration($0) }
                ),
                maxValue: blockState.maxBlockLength
            )
            .padding(.horizontal, NothingTheme.spaceMD)

            Spacer()

            // Error message (if any)
            if let error = errorMessage {
                Text(error)
                    .font(.spaceMono(.regular, size: 11))
                    .textCase(.uppercase)
                    .tracking(NothingTheme.labelTracking * 11)
                    .foregroundColor(NothingColors.accent)
                    .padding(.bottom, NothingTheme.spaceSM)
            }

            // Tertiary: Start Button
            NothingPillButton(
                title: "START BLOCK",
                variant: .secondary,
                action: { startBlock() },
                isEnabled: canStartBlock
            )
            .padding(.horizontal, NothingTheme.spaceMD)
            .padding(.bottom, NothingTheme.spaceMD)
        }
    }

    // MARK: - Active Timer Content

    @State private var pulseOpacity: Double = 1.0

    private var filledCount: Int {
        Int(round(timer.progress * 48))
    }

    private var activeTimerContent: some View {
        VStack(spacing: 0) {
            Spacer()

            // Primary: Countdown Display — separated HH MM SS with labels
            timerDigitsView(
                hours: timer.hours,
                minutes: timer.minutes,
                seconds: timer.seconds,
                color: timer.isFinishing
                    ? NothingColors.textSecondary
                    : NothingColors.textDisplay
            )
            .opacity(timer.shouldPulse ? pulseOpacity : 1.0)

            Spacer()
                .frame(height: NothingTheme.spaceLG)

            // Secondary: Segmented Progress (elapsed time indicator)
            NothingSegmentedSlider(
                value: .constant(filledCount),
                maxValue: 48,
                isInteractive: false
            )
            .animation(.easeInOut(duration: 0.6), value: filledCount)
            .padding(.horizontal, NothingTheme.spaceLG)

            Spacer()

            // DONE Button (fades in when block completes)
            NothingPillButton(title: "DONE", variant: .secondary) {
                timer.stop()
                SCSettings.shared().reload()
                blockState.refresh()
                TimerPillWindowController.shared.hide()
            }
            .opacity(timer.isFinishing ? 1.0 : 0.0)
            .allowsHitTesting(timer.isFinishing)
            .animation(.easeOut(duration: 0.3), value: timer.isFinishing)
            .padding(.horizontal, NothingTheme.spaceLG)
            .padding(.bottom, NothingTheme.spaceMD)
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

    // MARK: - Timer Digits View

    /// Separated HH MM SS display with unit labels underneath.
    /// Matches the instrument-panel aesthetic from the original full-window design.
    private func timerDigitsView(hours: Int, minutes: Int, seconds: Int, color: Color) -> some View {
        HStack(spacing: NothingTheme.spaceLG) {
            digitGroup(value: hours, label: "HRS", color: color, dimmed: hours == 0)
            digitGroup(value: minutes, label: "MIN", color: color, dimmed: hours == 0 && minutes == 0)
            digitGroup(value: seconds, label: "SEC", color: color, dimmed: false)
        }
    }

    private func digitGroup(value: Int, label: String, color: Color, dimmed: Bool) -> some View {
        VStack(spacing: NothingTheme.spaceXS) {
            Text(String(format: "%02d", value))
                .font(.doto(size: 64))
                .tracking(64 * 0.04)
                .foregroundColor(color.opacity(dimmed ? 0.35 : 1.0))
                .contentTransition(.numericText(countsDown: true))
                .animation(.easeOut(duration: 0.15), value: value)

            Text(label)
                .font(.spaceMono(.regular, size: 11))
                .tracking(NothingTheme.labelTracking * 11)
                .foregroundColor(NothingColors.textSecondary)
        }
    }

    // MARK: - Actions

    private var canStartBlock: Bool {
        let mode = modeVM.currentMode
        return mode.durationMinutes > 0
            && (mode.domains.count > 0 || mode.isAllowlist)
            && !blockState.addingBlock
    }

    private func startBlock() {
        // Write mode config to legacy UserDefaults keys
        modeVM.writeCurrentModeToLegacyDefaults()
        // Refresh block state to pick up the new values
        blockState.refresh()
        // Start the block through the existing Obj-C flow
        blockState.startBlock()
    }

}

// MARK: - Preview

@available(macOS 16.0, *)
#Preview {
    MenuBarContentView()
        .environment(BlockStateViewModel())
        .environment(TimerViewModel())
        .environment(ModeViewModel())
        .environment(PreferencesViewModel())
}
