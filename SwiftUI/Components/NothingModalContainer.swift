import SwiftUI

// MARK: - NothingModalContainer

struct NothingModalContainer<Content: View>: View {
    @Binding var isPresented: Bool
    @ViewBuilder let content: () -> Content

    var body: some View {
        ZStack {
            if isPresented {
                // Backdrop
                Color.black.opacity(0.8)
                    .ignoresSafeArea()
                    .onTapGesture {
                        isPresented = false
                    }
                    .transition(.opacity)

                // Dialog
                VStack(spacing: 0) {
                    // Close button row
                    HStack {
                        Spacer()
                        Button {
                            isPresented = false
                        } label: {
                            Text("\u{2715}")
                                .font(.system(size: 16, weight: .regular))
                                .foregroundColor(NothingColors.textSecondary)
                                .frame(width: 32, height: 32)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }

                    // Content
                    content()
                }
                .padding(24)
                .frame(maxWidth: .infinity)
                .background(NothingColors.surface)
                .clipShape(RoundedRectangle(cornerRadius: NothingTheme.radiusTechnical))
                .overlay(
                    RoundedRectangle(cornerRadius: NothingTheme.radiusTechnical)
                        .stroke(NothingColors.borderVisible, lineWidth: 1)
                )
                .padding(.horizontal, NothingTheme.spaceMD)
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isPresented)
    }
}

// MARK: - View Extension

extension View {
    func nothingModal<Content: View>(
        isPresented: Binding<Bool>,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        ZStack {
            self
            NothingModalContainer(isPresented: isPresented, content: content)
        }
    }
}

// MARK: - Preview

#Preview {
    struct ModalPreview: View {
        @State private var showModal = true

        var body: some View {
            ZStack {
                NothingColors.background.ignoresSafeArea()

                NothingPillButton(title: "Show Modal", variant: .secondary) {
                    showModal = true
                }
            }
            .nothingModal(isPresented: $showModal) {
                VStack(spacing: 16) {
                    Text("Block Active")
                        .font(Font.spaceMono(.bold, size: 18))
                        .foregroundColor(NothingColors.textDisplay)

                    Text("Your block session is currently running.")
                        .font(Font.spaceGrotesk(.regular, size: 15))
                        .foregroundColor(NothingColors.textSecondary)
                        .multilineTextAlignment(.center)

                    NothingPillButton(title: "Dismiss", variant: .primary) {
                        showModal = false
                    }
                }
            }
        }
    }

    return ModalPreview()
}
