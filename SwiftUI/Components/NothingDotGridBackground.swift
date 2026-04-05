import SwiftUI

// MARK: - Background Style

enum NothingBackgroundStyle: String, CaseIterable {
    case oledBlack
    case dotGrid
}

// MARK: - NothingDotGridBackground

struct NothingDotGridBackground: View {
    var style: NothingBackgroundStyle = .dotGrid

    var body: some View {
        switch style {
        case .oledBlack:
            Color.black.ignoresSafeArea()

        case .dotGrid:
            ZStack {
                Color.black.ignoresSafeArea()

                Canvas { context, size in
                    let spacing: CGFloat = 16
                    let dotSize: CGFloat = 2
                    let dotColor = NothingColors.borderVisible.opacity(0.35)

                    let cols = Int(size.width / spacing) + 1
                    let rows = Int(size.height / spacing) + 1

                    for row in 0...rows {
                        for col in 0...cols {
                            let x = CGFloat(col) * spacing
                            let y = CGFloat(row) * spacing
                            let rect = CGRect(
                                x: x - dotSize / 2,
                                y: y - dotSize / 2,
                                width: dotSize,
                                height: dotSize
                            )
                            context.fill(
                                Path(ellipseIn: rect),
                                with: .color(dotColor)
                            )
                        }
                    }
                }
                .ignoresSafeArea()
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        NothingDotGridBackground(style: .dotGrid)

        Text("Nothing Design System")
            .font(Font.spaceMono(.bold, size: 18))
            .foregroundColor(NothingColors.textDisplay)
    }
    .frame(width: 480, height: 320)
}
