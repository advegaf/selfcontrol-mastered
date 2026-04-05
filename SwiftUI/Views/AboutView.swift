import SwiftUI

// MARK: - AboutView

/// About section for the settings sidebar.
///
/// Displays app name, version, links to website/FAQ/support,
/// and credits. Nothing design: centered content, Space Mono labels,
/// ghost pill buttons for links.
@available(macOS 16.0, *)
struct AboutView: View {

    private var versionString: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "\(version) (\(build))"
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // MARK: App Title

            Text("SELFCONTROL\nMASTERED")
                .font(.nothingDisplayMD)
                .foregroundColor(NothingColors.textDisplay)
                .multilineTextAlignment(.center)

            Spacer()
                .frame(height: NothingTheme.spaceMD)

            // MARK: Version

            Text("VERSION \(versionString)")
                .font(.spaceMono(.regular, size: 11))
                .textCase(.uppercase)
                .tracking(NothingTheme.labelTracking * 11)
                .foregroundColor(NothingColors.textSecondary)

            Spacer()
                .frame(height: NothingTheme.space2XL)

            // MARK: Links

            VStack(spacing: NothingTheme.spaceMD) {
                linkButton("WEBSITE", urlString: "https://advegaf.com")
                linkButton("SUPPORT", urlString: "mailto:advegaf@tamu.edu")
            }

            Spacer()

            // MARK: Credits

            Text("REMODELED BY ANGEL VEGA\nFORKED FROM CHARLIE STIGLER & STEVE LAMBERT")
                .font(.spaceMono(.regular, size: 10))
                .textCase(.uppercase)
                .tracking(NothingTheme.labelTracking * 10)
                .foregroundColor(NothingColors.textDisabled)
                .multilineTextAlignment(.center)
                .padding(.bottom, NothingTheme.spaceXL)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, NothingTheme.spaceXL)
    }

    // MARK: - Link Button

    private func linkButton(_ title: String, urlString: String) -> some View {
        NothingPillButton(title: title, variant: .ghost) {
            if let url = URL(string: urlString) {
                NSWorkspace.shared.open(url)
            }
        }
        .frame(width: 200)
    }
}

// MARK: - Preview

@available(macOS 16.0, *)
#Preview {
    AboutView()
        .frame(width: 400, height: 500)
        .background(NothingColors.background)
}
