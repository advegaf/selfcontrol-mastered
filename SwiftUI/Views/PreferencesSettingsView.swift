import SwiftUI

// MARK: - PreferencesSettingsView

/// Flattened preferences view for the settings sidebar.
///
/// Combines all General and Advanced preferences into a single
/// scrollable list. Padding is inside the ScrollView to prevent
/// the scrollbar from overlapping toggle controls.
@available(macOS 16.0, *)
struct PreferencesSettingsView: View {

    @Environment(PreferencesViewModel.self) private var preferences

    var body: some View {
        @Bindable var preferences = preferences

        ScrollView {
            VStack(alignment: .leading, spacing: NothingTheme.spaceXL) {

                // MARK: General Section

                preferencesSection("GENERAL") {
                    Toggle("Launch at login", isOn: $preferences.launchAtLogin)
                        .toggleStyle(NothingToggleStyle())
                }

                // MARK: Timer Section

                preferencesSection("TIMER") {
                    VStack(alignment: .leading, spacing: NothingTheme.spaceMD) {
                        Toggle("Show floating pill when window closes", isOn: $preferences.showTimerPill)
                            .toggleStyle(NothingToggleStyle())

                        if preferences.showTimerPill {
                            Toggle("Keep pill above all windows", isOn: $preferences.timerPillFloatsOnTop)
                                .toggleStyle(NothingToggleStyle())
                        }
                    }
                }

                // MARK: Notifications Section

                preferencesSection("NOTIFICATIONS") {
                    VStack(alignment: .leading, spacing: NothingTheme.spaceMD) {
                        Toggle("Play sound on completion", isOn: $preferences.blockSoundShouldPlay)
                            .toggleStyle(NothingToggleStyle())

                        if preferences.blockSoundShouldPlay {
                            soundDropdown
                        }
                    }
                }

                // MARK: Updates Section

                preferencesSection("UPDATES") {
                    VStack(alignment: .leading, spacing: NothingTheme.spaceMD) {
                        Toggle("Automatically check for updates", isOn: $preferences.automaticallyChecksForUpdates)
                            .toggleStyle(NothingToggleStyle())

                        Toggle("Send anonymized error reports", isOn: $preferences.enableErrorReporting)
                            .toggleStyle(NothingToggleStyle())
                    }
                }

                // MARK: Appearance Section

                preferencesSection("APPEARANCE") {
                    NothingSegmentedControl(
                        items: [
                            (label: "OLED BLACK", value: NothingBackgroundStyle.oledBlack),
                            (label: "DOT GRID", value: NothingBackgroundStyle.dotGrid)
                        ],
                        selected: $preferences.backgroundStyle
                    )
                }

                // MARK: Blocking Section

                preferencesSection("BLOCKING") {
                    VStack(alignment: .leading, spacing: NothingTheme.spaceMD) {
                        Toggle("Include linked sites (slow)", isOn: $preferences.includeLinkedDomains)
                            .toggleStyle(NothingToggleStyle())

                        Toggle("Block common subdomains", isOn: $preferences.evaluateCommonSubdomains)
                            .toggleStyle(NothingToggleStyle())

                        Toggle("Allow local networks", isOn: $preferences.allowLocalNetworks)
                            .toggleStyle(NothingToggleStyle())

                        Toggle("Clear browser cache", isOn: $preferences.clearCaches)
                            .toggleStyle(NothingToggleStyle())

                        Toggle("Verify internet connection", isOn: $preferences.verifyInternetConnection)
                            .toggleStyle(NothingToggleStyle())
                    }
                }

                // MARK: Validation Section

                preferencesSection("VALIDATION") {
                    Toggle("Highlight invalid hosts", isOn: $preferences.highlightInvalidHosts)
                        .toggleStyle(NothingToggleStyle())
                }
            }
            .padding(.horizontal, NothingTheme.spaceMD)
            .padding(.vertical, NothingTheme.spaceLG)
        }
    }

    // MARK: - Sound Dropdown

    private var soundDropdown: some View {
        let soundNames = preferences.systemSoundNames
        let selectedName = preferences.blockSoundIndex < soundNames.count
            ? soundNames[preferences.blockSoundIndex]
            : (soundNames.first ?? "")

        return NothingDropdown(
            label: "COMPLETION SOUND",
            options: soundNames,
            selected: .init(
                get: { selectedName },
                set: { newValue in
                    if let index = soundNames.firstIndex(of: newValue) {
                        preferences.blockSoundIndex = index
                    }
                }
            )
        )
    }

    // MARK: - Section Builder

    private func preferencesSection<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: NothingTheme.spaceLG) {
            Text(title)
                .font(.spaceMono(.regular, size: 11))
                .textCase(.uppercase)
                .tracking(NothingTheme.labelTracking * 11)
                .foregroundColor(NothingColors.textSecondary)

            content()
        }
    }
}

// MARK: - Preview

@available(macOS 16.0, *)
#Preview {
    PreferencesSettingsView()
        .environment(PreferencesViewModel())
        .frame(width: 400, height: 600)
        .background(NothingColors.background)
}
