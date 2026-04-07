import SwiftUI

// MARK: - UnifiedRootView

/// Single root view for the entire app window. State-driven content swap
/// inside one NSWindow.
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
        .blockTimerCoordination()
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
