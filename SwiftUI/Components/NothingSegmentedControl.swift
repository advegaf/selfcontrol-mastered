import SwiftUI

// MARK: - NothingSegmentedControl

struct NothingSegmentedControl<T: Hashable>: View {
    let items: [(label: String, value: T)]
    @Binding var selected: T

    @Namespace private var segmentNamespace

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                segmentButton(for: item)
            }
        }
        .frame(height: 36)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(NothingColors.borderVisible, lineWidth: 1)
        )
    }

    // MARK: - Segment Button

    @ViewBuilder
    private func segmentButton(for item: (label: String, value: T)) -> some View {
        let isActive = selected == item.value

        Button {
            withAnimation(.easeOut(duration: 0.2)) {
                selected = item.value
            }
        } label: {
            Text(item.label)
                .font(Font.spaceMono(.regular, size: 11))
                .textCase(.uppercase)
                .tracking(0.88) // 0.08em at 11px
                .foregroundColor(isActive ? NothingColors.background : NothingColors.textSecondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    Group {
                        if isActive {
                            Capsule()
                                .fill(NothingColors.textDisplay)
                                .matchedGeometryEffect(id: "activeSegment", in: segmentNamespace)
                        }
                    }
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    struct SegmentedPreview: View {
        @State private var selected = "timer"

        var body: some View {
            NothingSegmentedControl(
                items: [
                    (label: "Timer", value: "timer"),
                    (label: "Blocklist", value: "blocklist"),
                    (label: "Settings", value: "settings")
                ],
                selected: $selected
            )
            .frame(width: 360)
            .padding(40)
            .background(NothingColors.background)
        }
    }

    return SegmentedPreview()
}
