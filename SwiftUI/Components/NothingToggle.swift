import SwiftUI

// MARK: - NothingToggleStyle

struct NothingToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label
                .font(Font.spaceGrotesk(.regular, size: 15))
                .foregroundColor(NothingColors.textPrimary)

            Spacer()

            toggleTrack(isOn: configuration.isOn)
                .onTapGesture {
                    withAnimation(.easeOut(duration: 0.15)) {
                        configuration.isOn.toggle()
                    }
                }
        }
    }

    @ViewBuilder
    private func toggleTrack(isOn: Bool) -> some View {
        ZStack(alignment: isOn ? .trailing : .leading) {
            // Track
            Capsule()
                .fill(isOn ? NothingColors.textDisplay : Color.clear)
                .overlay(
                    Capsule()
                        .stroke(
                            isOn ? Color.clear : NothingColors.borderVisible,
                            lineWidth: 1
                        )
                )
                .frame(width: 44, height: 24)

            // Thumb
            Circle()
                .fill(isOn ? NothingColors.background : NothingColors.textDisabled)
                .frame(width: 20, height: 20)
                .padding(.horizontal, 2)
        }
        .frame(width: 44, height: 24)
    }
}

