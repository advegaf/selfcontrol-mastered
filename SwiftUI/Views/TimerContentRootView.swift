import SwiftUI

// MARK: - TimerContentRootView

/// Root view for the timer window during an active block.
///
/// Manages a settings cog icon (top-right) that swaps between the
/// timer countdown and the settings sidebar in-place. A back arrow
/// returns to the timer view.
@available(macOS 16.0, *)
struct TimerContentRootView: View {

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
                } else {
                    TimerView()
                        .transition(.asymmetric(
                            insertion: .move(edge: .leading).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .onAppear {
            tryStartTimer()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { tryStartTimer() }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { tryStartTimer() }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { tryStartTimer() }
            DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) { tryStartTimer() }
        }
        .onReceive(configNotification) { _ in
            tryStartTimer()
        }
        .onReceive(distributedConfigNotification) { _ in
            tryStartTimer()
        }
    }

    private func tryStartTimer() {
        // Force reload settings from disk to get latest BlockEndDate
        SCSettings.shared().reload()
        blockState.refresh()
        if let endDate = blockState.blockEndDate {
            timer.start(endDate: endDate)
        }
    }
}

// MARK: - Preview

@available(macOS 16.0, *)
#Preview {
    TimerContentRootView()
        .environment(TimerViewModel())
        .environment(BlockStateViewModel())
        .environment(PreferencesViewModel())
        .environment(BlocklistViewModel())
        .frame(width: 620, height: 520)
}
