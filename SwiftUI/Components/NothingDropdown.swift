import SwiftUI

// MARK: - NothingDropdown

struct NothingDropdown: View {
    let label: String
    let options: [String]
    @Binding var selected: String
    var onSelect: ((String) -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: NothingTheme.spaceSM) {
            // Label (hidden when empty)
            if !label.isEmpty {
                Text(label)
                    .font(Font.spaceMono(.regular, size: 11))
                    .textCase(.uppercase)
                    .tracking(0.88) // 0.08em at 11px
                    .foregroundColor(NothingColors.textSecondary)
            }

            // Menu Trigger
            Menu {
                ForEach(options, id: \.self) { option in
                    Button {
                        selected = option
                        onSelect?(option)
                    } label: {
                        Text(option)
                    }
                }
            } label: {
                HStack {
                    Text(selected)
                        .font(Font.spaceMono(.regular, size: 13))
                        .foregroundColor(NothingColors.textPrimary)

                    Spacer()

                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(NothingColors.textSecondary)
                }
                .padding(.horizontal, 12)
                .frame(height: 44)
                .background(NothingColors.surfaceRaised)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(NothingColors.borderVisible, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Preview

#Preview {
    struct DropdownPreview: View {
        @State private var selected = "30 minutes"

        var body: some View {
            NothingDropdown(
                label: "Duration",
                options: ["15 minutes", "30 minutes", "1 hour", "2 hours"],
                selected: $selected
            )
            .frame(width: 280)
            .padding(40)
            .background(NothingColors.background)
        }
    }

    return DropdownPreview()
}
