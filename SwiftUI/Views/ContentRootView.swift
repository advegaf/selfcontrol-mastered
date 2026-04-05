import SwiftUI

// MARK: - ContentRootView

/// Root view for the main app window.
///
/// Manages a settings cog icon (top-right) and content swap between
/// the home view (MainSetupView) and the settings view (SettingsContainerView).
/// A back arrow (top-left) returns from settings to home.
@available(macOS 16.0, *)
struct ContentRootView: View {

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
                } else {
                    MainSetupView()
                        .transition(.asymmetric(
                            insertion: .move(edge: .leading).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
    }
}

// MARK: - Preview

@available(macOS 16.0, *)
#Preview {
    ContentRootView()
        .environment(BlockStateViewModel())
        .environment(TimerViewModel())
        .environment(BlocklistViewModel())
        .environment(PreferencesViewModel())
        .frame(width: 620, height: 520)
}
