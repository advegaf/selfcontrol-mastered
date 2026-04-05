import SwiftUI

// MARK: - NothingSegmentedSlider

struct NothingSegmentedSlider: View {
    @Binding var value: Int
    let maxValue: Int
    var segmentCount: Int = 48
    var isInteractive: Bool = true

    var body: some View {
        GeometryReader { geometry in
            let segments = HStack(spacing: 2) {
                ForEach(0..<segmentCount, id: \.self) { index in
                    Rectangle()
                        .fill(segmentColor(for: index))
                        .animation(.easeOut(duration: 0.3), value: filledSegments)
                }
            }
            .contentShape(Rectangle())

            if isInteractive {
                segments
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { drag in
                                updateValue(at: drag.location.x, in: geometry.size.width)
                            }
                    )
                    .onTapGesture { location in
                        updateValue(at: location.x, in: geometry.size.width)
                    }
            } else {
                segments
            }
        }
        .frame(height: 24)
    }

    // MARK: - Helpers

    private var filledSegments: Int {
        guard maxValue > 0 else { return 0 }
        let proportion = Double(value) / Double(maxValue)
        return Int(round(proportion * Double(segmentCount)))
    }

    private func segmentColor(for index: Int) -> Color {
        index < filledSegments ? NothingColors.textDisplay : NothingColors.border
    }

    private func updateValue(at x: CGFloat, in totalWidth: CGFloat) {
        let clamped = min(max(x, 0), totalWidth)
        let proportion = clamped / totalWidth
        let newValue = Int(round(proportion * Double(maxValue)))
        value = min(max(newValue, 0), maxValue)
    }
}

// MARK: - Preview

#Preview {
    struct SliderPreview: View {
        @State private var minutes = 30

        var body: some View {
            VStack(spacing: 16) {
                Text("\(minutes) min")
                    .font(Font.spaceMono(.regular, size: 15))
                    .foregroundColor(NothingColors.textPrimary)
                NothingSegmentedSlider(value: $minutes, maxValue: 120)
            }
            .padding(40)
            .background(NothingColors.background)
        }
    }

    return SliderPreview()
}
