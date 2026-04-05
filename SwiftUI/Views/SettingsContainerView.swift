import SwiftUI

// MARK: - Settings Section

enum SettingsSection: String, CaseIterable, Identifiable {
    case blocklist = "BLOCKLIST"
    case preferences = "PREFERENCES"
    case about = "ABOUT"

    var id: String { rawValue }
}

// MARK: - SettingsContainerView

/// Sidebar + content layout for the settings area.
///
/// Three sidebar items (text-only, Space Mono uppercase) with a
/// vertical divider and content area that swaps per selection.
@available(macOS 16.0, *)
struct SettingsContainerView: View {

    @State private var selectedSection: SettingsSection = .blocklist

    var body: some View {
        HStack(spacing: 0) {
            // MARK: Sidebar

            VStack(alignment: .leading, spacing: 0) {
                ForEach(SettingsSection.allCases) { section in
                    sidebarItem(section)
                }
                Spacer()
            }
            .frame(width: 140)
            .padding(.top, NothingTheme.spaceSM)

            // MARK: Divider

            Rectangle()
                .fill(NothingColors.borderVisible)
                .frame(width: 1)

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

    // MARK: - Sidebar Item

    private func sidebarItem(_ section: SettingsSection) -> some View {
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
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, NothingTheme.spaceMD)
                .padding(.horizontal, NothingTheme.spaceLG)
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
        .frame(width: 500, height: 500)
        .background(NothingColors.background)
}
