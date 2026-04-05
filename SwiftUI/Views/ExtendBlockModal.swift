import SwiftUI

// MARK: - ExtendBlockModal

/// Modal overlay for extending the duration of an active block.
///
/// Presents a segmented slider to choose the extension amount,
/// with a Doto display showing the selected duration.
@available(macOS 16.0, *)
struct ExtendBlockModal: View {

    @Binding var isPresented: Bool

    @Environment(BlockStateViewModel.self) private var blockState

    @State private var extensionMinutes: Int = 15

    var body: some View {
        VStack(spacing: NothingTheme.spaceLG) {
            // MARK: Header

            VStack(spacing: NothingTheme.spaceSM) {
                Text("EXTEND BLOCK")
                    .font(.spaceMono(.regular, size: 11))
                    .textCase(.uppercase)
                    .tracking(NothingTheme.labelTracking * 11)
                    .foregroundColor(NothingColors.textSecondary)

                Text("BY HOW MUCH TIME?")
                    .font(.nothingCaption)
                    .textCase(.uppercase)
                    .tracking(NothingTheme.labelTracking * 12)
                    .foregroundColor(NothingColors.textDisabled)
            }

            // MARK: Duration Display

            Text(extensionDescription)
                .nothingDisplayLG()
                .foregroundColor(NothingColors.textDisplay)

            // MARK: Slider

            NothingSegmentedSlider(
                value: $extensionMinutes,
                maxValue: blockState.maxBlockLength
            )

            // MARK: Actions

            HStack(spacing: NothingTheme.spaceMD) {
                Spacer()

                NothingPillButton(title: "CANCEL", variant: .ghost) {
                    isPresented = false
                }

                NothingPillButton(
                    title: "EXTEND",
                    variant: .secondary,
                    action: extendBlock,
                    isEnabled: extensionMinutes > 0
                )
            }
        }
    }

    // MARK: - Computed Properties

    private var extensionDescription: String {
        let hours = extensionMinutes / 60
        let minutes = extensionMinutes % 60

        if hours > 0 && minutes > 0 {
            return "\(hours)H \(minutes)M"
        } else if hours > 0 {
            return "\(hours)H"
        } else {
            return "\(minutes) MIN"
        }
    }

    // MARK: - Actions

    private func extendBlock() {
        guard extensionMinutes > 0 else { return }
        (NSApp.delegate as? AppController)?.extendBlockTime(extensionMinutes, lock: nil)
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
        ExtendBlockModal(isPresented: .constant(true))
            .environment(BlockStateViewModel())
    }
    .frame(width: 500, height: 400)
}
