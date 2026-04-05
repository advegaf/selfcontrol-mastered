import SwiftUI

// MARK: - UnifiedRootView

/// Single root view for the entire app window. Replaces the two-window
/// architecture (ContentRootView + TimerContentRootView) with a state-driven
/// content swap inside one NSWindow.
///
/// Content is selected by `timer.hasStarted`:
/// - `false` → MainSetupView (configure and start a block)
/// - `true`  → TimerView (countdown, then DONE to return)
///
/// Settings cog (top-right) toggles SettingsContainerView in both modes.
@available(macOS 16.0, *)
struct UnifiedRootView: View {

    @Environment(TimerViewModel.self) private var timer
    @Environment(BlockStateViewModel.self) private var blockState
    @Environment(PreferencesViewModel.self) private var preferences

    @State private var showSettings: Bool = false

    private let configNotification = NotificationCenter.default.publisher(
        for: NSNotification.Name("SCConfigurationChangedNotification")
    )
    private let distributedConfigNotification = DistributedNotificationCenter.default().publisher(
        for: NSNotification.Name("SCConfigurationChangedNotification")
    )

    var body: some View {
        ZStack {
            NothingDotGridBackground(style: preferences.backgroundStyle)

            VStack(spacing: 0) {
                // MARK: Top Bar

                HStack {
                    if showSettings {
                        Button {
                            withAnimation(.easeOut(duration: NothingTheme.transitionDuration)) {
                                showSettings = false
                            }
                        } label: {
                            Image(systemName: "arrow.left")
                                .font(.system(size: 16, weight: .regular))
                                .foregroundColor(NothingColors.textSecondary)
                                .frame(width: 32, height: 32)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }

                    Spacer()

                    Button {
                        withAnimation(.easeOut(duration: NothingTheme.transitionDuration)) {
                            showSettings.toggle()
                        }
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(
                                showSettings
                                    ? NothingColors.textDisplay
                                    : NothingColors.textSecondary
                            )
                            .frame(width: 32, height: 32)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, NothingTheme.spaceSM)
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
                    TimerView()
                        .transition(.opacity)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    MainSetupView()
                        .transition(.opacity)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .animation(.easeOut(duration: NothingTheme.transitionDuration), value: timer.hasStarted)
        }
        .onAppear {
            tryStartTimerIfNeeded()
            // Retry with increasing delays — on app launch during an active block,
            // settings may not be loaded yet and daemon won't fire a new notification.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { tryStartTimerIfNeeded() }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { tryStartTimerIfNeeded() }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { tryStartTimerIfNeeded() }
            DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) { tryStartTimerIfNeeded() }
        }
        .onReceive(configNotification) { _ in
            tryStartTimerIfNeeded()
        }
        .onReceive(distributedConfigNotification) { _ in
            tryStartTimerIfNeeded()
        }
        .onChange(of: timer.hasStarted) { _, started in
            // Floating window preference: float during active block
            if let window = NSApp.windows.first {
                if started && preferences.timerWindowFloats {
                    window.level = .floating
                } else {
                    window.level = .normal
                }
            }
            // Close settings when transitioning back to setup
            if !started && showSettings {
                showSettings = false
            }
        }
        .onChange(of: blockState.addingBlock) { _, adding in
            if adding {
                // Safety timeout: if addingBlock stays true for 30s, the XPC
                // chain probably failed. Reset so the user can try again.
                DispatchQueue.main.asyncAfter(deadline: .now() + 30) {
                    if blockState.addingBlock {
                        if let appController = NSApp.delegate as? AppController {
                            appController.addingBlock = false
                        }
                        blockState.refresh()
                    }
                }
            }
        }
    }

    // MARK: - Timer Start

    /// Checks if a block is active and starts the countdown if possible.
    /// Called on appear, with retries, and on every configuration-changed
    /// notification.
    private func tryStartTimerIfNeeded() {
        SCSettings.shared().reload()
        blockState.refresh()
        if !timer.hasStarted, blockState.blockIsActive, let endDate = blockState.blockEndDate {
            timer.start(endDate: endDate)
        }
    }
}

// MARK: - Preview

@available(macOS 16.0, *)
#Preview {
    UnifiedRootView()
        .environment(BlockStateViewModel())
        .environment(TimerViewModel())
        .environment(BlocklistViewModel())
        .environment(PreferencesViewModel())
        .frame(width: 620, height: 520)
}
