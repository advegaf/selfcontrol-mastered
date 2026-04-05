import SwiftUI

// MARK: - ModeSelector

/// Horizontal A/B mode toggle for the menu bar popover.
///
/// Selected mode: filled white capsule with dark text (primary button).
/// Unselected mode: outlined capsule with secondary text.
/// Shows mode letter and short duration: "A  15m"
@available(macOS 16.0, *)
struct ModeSelector: View {

    @Environment(ModeViewModel.self) private var modeVM

    var body: some View {
        HStack(spacing: NothingTheme.spaceSM) {
            ForEach(ModeID.allCases) { modeID in
                modeButton(modeID)
            }
        }
    }

    // MARK: - Mode Button

    private func modeButton(_ id: ModeID) -> some View {
        let mode = modeVM.mode(for: id)
        let isSelected = modeVM.selectedMode == id

        return Button {
            withAnimation(.easeOut(duration: NothingTheme.microDuration)) {
                modeVM.selectedMode = id
            }
        } label: {
            HStack(spacing: NothingTheme.spaceXS) {
                // Mode letter in a small bordered square
                Text(id.label)
                    .font(.spaceMono(.bold, size: 11))
                    .foregroundColor(isSelected ? .black : NothingColors.interactive)
                    .frame(width: 18, height: 18)
                    .background(
                        RoundedRectangle(cornerRadius: 3)
                            .stroke(isSelected ? Color.clear : NothingColors.interactive, lineWidth: 1)
                    )

                // Mode name + duration
                Text("\(id.displayName) \(mode.shortDurationLabel)")
                    .font(.spaceMono(.regular, size: 11))
                    .textCase(.uppercase)
                    .tracking(NothingTheme.labelTracking * 11)
                    .foregroundColor(
                        isSelected ? .black : NothingColors.textSecondary
                    )
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                isSelected
                    ? AnyShapeStyle(Color.white)
                    : AnyShapeStyle(Color.clear)
            )
            .clipShape(Capsule())
            .overlay(
                isSelected
                    ? nil
                    : Capsule().stroke(NothingColors.borderVisible, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

@available(macOS 16.0, *)
#Preview {
    ModeSelector()
        .environment(ModeViewModel())
        .padding(40)
        .background(NothingColors.background)
}
