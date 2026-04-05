import SwiftUI

// MARK: - Button Variant

enum NothingButtonVariant {
    case primary
    case secondary
    case ghost
    case destructive
}

// MARK: - NothingPillButton

struct NothingPillButton: View {
    let title: String
    let variant: NothingButtonVariant
    let action: () -> Void
    var isEnabled: Bool = true

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Font.spaceMono(.regular, size: 13))
                .textCase(.uppercase)
                .tracking(0.78) // 0.06em at 13px
                .foregroundColor(foregroundColor)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .frame(minHeight: 44)
                .background(backgroundColor)
                .clipShape(Capsule())
                .overlay(borderOverlay)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1.0 : 0.4)
    }

    // MARK: - Styling

    private var foregroundColor: Color {
        switch variant {
        case .primary:
            return Color.black
        case .secondary:
            return NothingColors.textPrimary
        case .ghost:
            return NothingColors.textSecondary
        case .destructive:
            return NothingColors.accent
        }
    }

    private var backgroundColor: Color {
        switch variant {
        case .primary:
            return Color.white
        default:
            return Color.clear
        }
    }

    @ViewBuilder
    private var borderOverlay: some View {
        switch variant {
        case .secondary:
            Capsule()
                .stroke(NothingColors.borderVisible, lineWidth: 1)
        case .destructive:
            Capsule()
                .stroke(NothingColors.accent, lineWidth: 1)
        default:
            EmptyView()
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 16) {
        NothingPillButton(title: "Primary", variant: .primary) {}
        NothingPillButton(title: "Secondary", variant: .secondary) {}
        NothingPillButton(title: "Ghost", variant: .ghost) {}
        NothingPillButton(title: "Destructive", variant: .destructive) {}
        NothingPillButton(title: "Disabled", variant: .primary, action: {}, isEnabled: false)
    }
    .padding(40)
    .background(NothingColors.background)
}
