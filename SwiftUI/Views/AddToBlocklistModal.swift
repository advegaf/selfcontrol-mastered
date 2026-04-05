import SwiftUI

// MARK: - AddToBlocklistModal

/// Modal overlay for adding a new domain to the active blocklist.
///
/// Presents a text field for domain entry with Cancel / Add actions.
/// Designed to be shown inside a `NothingModalContainer` via the
/// `.nothingModal(isPresented:content:)` modifier.
@available(macOS 16.0, *)
struct AddToBlocklistModal: View {

    @Binding var isPresented: Bool

    @Environment(BlockStateViewModel.self) private var blockState

    @State private var domainText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: NothingTheme.spaceLG) {
            // MARK: Title

            Text("ADD TO BLOCKLIST")
                .font(.spaceMono(.regular, size: 11))
                .textCase(.uppercase)
                .tracking(NothingTheme.labelTracking * 11)
                .foregroundColor(NothingColors.textSecondary)

            // MARK: Domain Input

            NothingTextField(
                label: "DOMAIN",
                text: $domainText,
                placeholder: "example.com"
            )

            // MARK: Actions

            HStack(spacing: NothingTheme.spaceMD) {
                Spacer()

                NothingPillButton(title: "CANCEL", variant: .ghost) {
                    domainText = ""
                    isPresented = false
                }

                NothingPillButton(
                    title: "ADD",
                    variant: .secondary,
                    action: addDomain,
                    isEnabled: !domainText.trimmingCharacters(in: .whitespaces).isEmpty
                )
            }
        }
    }

    // MARK: - Actions

    private func addDomain() {
        let trimmed = domainText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        if let appController = NSApp.delegate as? AppController {
            appController.add(toBlockList: trimmed, lock: nil)
        }

        domainText = ""
        isPresented = false
    }
}

// MARK: - Preview

@available(macOS 16.0, *)
#Preview {
    ZStack {
        NothingColors.background.ignoresSafeArea()
    }
    .nothingModal(isPresented: .constant(true)) {
        AddToBlocklistModal(isPresented: .constant(true))
            .environment(BlockStateViewModel())
    }
    .frame(width: 500, height: 400)
}
