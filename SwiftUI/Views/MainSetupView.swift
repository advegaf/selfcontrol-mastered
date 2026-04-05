import SwiftUI

// MARK: - MainSetupView

/// Primary setup screen for configuring and starting a SelfControl block.
///
/// Three-layer instrument-panel hierarchy on OLED black:
/// - Primary: duration display in Doto XL
/// - Secondary: segmented slider for duration
/// - Tertiary: action buttons
@available(macOS 16.0, *)
struct MainSetupView: View {

    @Environment(BlockStateViewModel.self) private var blockState
    @Environment(PreferencesViewModel.self) private var preferences

    var body: some View {
        @Bindable var blockState = blockState

        VStack(spacing: 0) {
            Spacer()
                .frame(minHeight: NothingTheme.space3XL, maxHeight: NothingTheme.space4XL)

            // MARK: Primary — Duration Display

            Text(blockState.durationDescription)
                .font(.nothingDisplayXL)
                .foregroundColor(NothingColors.textDisplay)
                .textCase(.uppercase)

            Spacer()
                .frame(minHeight: NothingTheme.spaceXL, maxHeight: NothingTheme.space2XL)

            // MARK: Secondary — Segmented Slider

            NothingSegmentedSlider(
                value: $blockState.blockDurationMinutes,
                maxValue: blockState.maxBlockLength
            )
            .padding(.horizontal, NothingTheme.spaceXL)

            Spacer()

            // MARK: Tertiary — Start Button

            NothingPillButton(
                title: "START BLOCK",
                variant: .secondary,
                action: { blockState.startBlock() },
                isEnabled: blockState.canStartBlock
            )
            .padding(.horizontal, NothingTheme.spaceXL)
            .padding(.bottom, NothingTheme.spaceXL)
        }
    }
}

// MARK: - Preview

@available(macOS 16.0, *)
#Preview {
    MainSetupView()
        .environment(BlockStateViewModel())
        .environment(PreferencesViewModel())
        .frame(width: 500, height: 400)
}
