import SwiftUI

// MARK: - Settings Section

enum SettingsSection: String, CaseIterable, Identifiable {
    case blocklist = "BLOCKLIST"
    case preferences = "PREFERENCES"
    case about = "ABOUT"

    var id: String { rawValue }
}

// MARK: - SettingsContainerView

/// Compact settings layout for the menu bar popover.
///
/// Uses a horizontal tab bar (Space Mono ALL CAPS) at the top instead
/// of a sidebar, fitting within the 320px popover width.
@available(macOS 16.0, *)
struct SettingsContainerView: View {

    @State private var selectedSection: SettingsSection = .blocklist

    var body: some View {
        VStack(spacing: 0) {
            // MARK: Tab Bar

            HStack(spacing: NothingTheme.spaceXS) {
                ForEach(SettingsSection.allCases) { section in
                    tabItem(section)
                }
                Spacer()
            }
            .padding(.horizontal, NothingTheme.spaceMD)
            .padding(.top, NothingTheme.spaceSM)

            // MARK: Divider

            Rectangle()
                .fill(NothingColors.borderVisible)
                .frame(height: 1)
                .padding(.top, NothingTheme.spaceXS)

            // MARK: Content

            Group {
                switch selectedSection {
                case .blocklist:
                    BlocklistSettingsView()
                case .preferences:
                    PreferencesSettingsView()
                case .about:
                    AboutView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Tab Item

    private func tabItem(_ section: SettingsSection) -> some View {
        Button {
            withAnimation(.easeOut(duration: NothingTheme.microDuration)) {
                selectedSection = section
            }
        } label: {
            Text(section.rawValue)
                .font(.spaceMono(.regular, size: 11))
                .textCase(.uppercase)
                .tracking(NothingTheme.labelTracking * 11)
                .foregroundColor(
                    selectedSection == section
                        ? NothingColors.textDisplay
                        : NothingColors.textSecondary
                )
                .padding(.vertical, NothingTheme.spaceSM)
                .padding(.horizontal, NothingTheme.spaceSM)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

@available(macOS 16.0, *)
#Preview {
    SettingsContainerView()
        .environment(BlocklistViewModel())
        .environment(BlockStateViewModel())
        .environment(PreferencesViewModel())
        .environment(ModeViewModel())
        .frame(width: 320, height: 340)
        .background(NothingColors.background)
}
