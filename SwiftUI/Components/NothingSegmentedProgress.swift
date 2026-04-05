import SwiftUI

// MARK: - NothingSegmentedProgress

struct NothingSegmentedProgress: View {
    let progress: Double
    var isPulsing: Bool = false
    var segmentCount: Int = 40
    var height: CGFloat = 8

    @State private var pulseOpacity: Double = 1.0

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<segmentCount, id: \.self) { index in
                Rectangle()
                    .fill(segmentColor(for: index))
                    .opacity(segmentOpacity(for: index))
            }
        }
        .frame(height: height)
        .onChange(of: isPulsing, initial: true) { _, newValue in
            if newValue {
                startPulsing()
            } else {
                pulseOpacity = 1.0
            }
        }
    }

    // MARK: - Helpers

    private var filledSegments: Int {
        let clamped = min(max(progress, 0.0), 1.0)
        return Int(round(clamped * Double(segmentCount)))
    }

    private func segmentColor(for index: Int) -> Color {
        index < filledSegments ? NothingColors.textDisplay : NothingColors.border
    }

    private func segmentOpacity(for index: Int) -> Double {
        if isPulsing && index < filledSegments {
            return pulseOpacity
        }
        return 1.0
    }

    private func startPulsing() {
        pulseOpacity = 1.0
        withAnimation(
            .easeInOut(duration: 0.8)
                .repeatForever(autoreverses: true)
        ) {
            pulseOpacity = 0.3
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 24) {
        NothingSegmentedProgress(progress: 0.6)
        NothingSegmentedProgress(progress: 0.4, isPulsing: true)
        NothingSegmentedProgress(progress: 1.0, segmentCount: 20, height: 12)
    }
    .padding(40)
    .background(NothingColors.background)
}
