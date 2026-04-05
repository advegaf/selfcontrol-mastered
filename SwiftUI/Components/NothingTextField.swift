import SwiftUI

// MARK: - NothingTextField

struct NothingTextField: View {
    let label: String
    @Binding var text: String
    var placeholder: String = ""
    var isError: Bool = false
    var errorMessage: String? = nil

    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: NothingTheme.spaceSM) {
            // Label
            Text(label)
                .font(Font.spaceMono(.regular, size: 11))
                .textCase(.uppercase)
                .tracking(0.88) // 0.08em at 11px
                .foregroundColor(NothingColors.textSecondary)

            // Input field
            VStack(spacing: 0) {
                TextField(placeholder, text: $text)
                    .font(Font.spaceMono(.regular, size: 15))
                    .foregroundColor(NothingColors.textPrimary)
                    .textFieldStyle(.plain)
                    .focused($isFocused)
                    .padding(.bottom, 8)

                // Underline
                Rectangle()
                    .fill(underlineColor)
                    .frame(height: 1)
            }

            // Error message
            if isError, let errorMessage, !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(Font.spaceMono(.regular, size: 11))
                    .foregroundColor(NothingColors.accent)
            }
        }
    }

    // MARK: - Helpers

    private var underlineColor: Color {
        if isError {
            return NothingColors.accent
        }
        return isFocused ? NothingColors.textPrimary : NothingColors.borderVisible
    }
}

// MARK: - Preview

#Preview {
    struct TextFieldPreview: View {
        @State private var url = ""
        @State private var errorUrl = "invalid-url"

        var body: some View {
            VStack(spacing: 32) {
                NothingTextField(
                    label: "Website URL",
                    text: $url,
                    placeholder: "example.com"
                )
                NothingTextField(
                    label: "Website URL",
                    text: $errorUrl,
                    placeholder: "example.com",
                    isError: true,
                    errorMessage: "Please enter a valid URL"
                )
            }
            .frame(width: 320)
            .padding(40)
            .background(NothingColors.background)
        }
    }

    return TextFieldPreview()
}
