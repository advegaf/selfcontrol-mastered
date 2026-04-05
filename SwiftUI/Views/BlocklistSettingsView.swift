import SwiftUI

// MARK: - BlocklistSettingsView

/// Blocklist/Allowlist editor for the settings sidebar.
///
/// Features:
/// - Permanent text field at top for adding new entries
/// - Single-click inline editing of existing entries
/// - Blocklist/Allowlist mode toggle via segmented control
/// - Remove button and import dropdown in bottom toolbar
/// - Read-only mode during active blocks
@available(macOS 16.0, *)
struct BlocklistSettingsView: View {

    @Environment(BlocklistViewModel.self) private var blocklistVM
    @Environment(BlockStateViewModel.self) private var blockState
    @Environment(PreferencesViewModel.self) private var preferences

    @State private var newDomainText: String = ""
    @State private var editingIndex: Int? = nil
    @State private var editingText: String = ""
    @State private var selectedIndex: Int? = nil
    @State private var importSelection = "IMPORT"

    @FocusState private var isAddFieldFocused: Bool
    @FocusState private var isEditFieldFocused: Bool

    private var isReadOnly: Bool {
        blockState.blockIsActive
    }

    var body: some View {
        @Bindable var blocklistVM = blocklistVM

        VStack(spacing: 0) {
            // MARK: Mode Toggle

            NothingSegmentedControl(
                items: [
                    (label: "BLOCKLIST", value: false),
                    (label: "ALLOWLIST", value: true)
                ],
                selected: $blocklistVM.isAllowlist
            )
            .padding(.horizontal, NothingTheme.spaceMD)
            .padding(.top, NothingTheme.spaceMD)
            .padding(.bottom, NothingTheme.spaceMD)
            .disabled(isReadOnly)

            // MARK: Add Field

            if !isReadOnly {
                addField
                    .padding(.horizontal, NothingTheme.spaceMD)
            }

            // MARK: Domain List

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(blocklistVM.domains.enumerated()), id: \.offset) { index, domain in
                        domainRow(domain: domain, index: index)
                    }
                }
            }
            .padding(.horizontal, NothingTheme.spaceMD)

            // MARK: Read-Only Notice

            if isReadOnly {
                Text("BLOCKLIST LOCKED DURING ACTIVE BLOCK")
                    .font(.spaceMono(.regular, size: 11))
                    .textCase(.uppercase)
                    .tracking(NothingTheme.labelTracking * 11)
                    .foregroundColor(NothingColors.textDisabled)
                    .padding(.vertical, NothingTheme.spaceMD)
            }

            // MARK: Toolbar

            if !isReadOnly {
                toolbar
                    .padding(.horizontal, NothingTheme.spaceMD)
                    .padding(.vertical, NothingTheme.spaceSM)
            }
        }
        .onChange(of: isEditFieldFocused) { _, focused in
            if !focused, let index = editingIndex {
                commitEdit(at: index)
            }
        }
    }

    // MARK: - Add Field

    private var addField: some View {
        VStack(spacing: 0) {
            TextField("example.com", text: $newDomainText)
                .font(.spaceMono(.regular, size: 15))
                .foregroundColor(NothingColors.textPrimary)
                .textFieldStyle(.plain)
                .focused($isAddFieldFocused)
                .onSubmit {
                    let trimmed = newDomainText.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    blocklistVM.addDomain(trimmed)
                    newDomainText = ""
                }
                .padding(.vertical, NothingTheme.spaceSM)

            Rectangle()
                .fill(isAddFieldFocused ? NothingColors.textPrimary : NothingColors.borderVisible)
                .frame(height: 1)
        }
        .padding(.bottom, NothingTheme.spaceSM)
    }

    // MARK: - Domain Row

    private func domainRow(domain: String, index: Int) -> some View {
        VStack(spacing: 0) {
            HStack {
                if editingIndex == index && !isReadOnly {
                    // Inline editing TextField
                    TextField("", text: $editingText)
                        .font(.spaceMono(.regular, size: 15))
                        .foregroundColor(NothingColors.textPrimary)
                        .textFieldStyle(.plain)
                        .focused($isEditFieldFocused)
                        .onSubmit { commitEdit(at: index) }
                        .onExitCommand { cancelEdit() }
                } else {
                    // Display text
                    Text(domain.isEmpty ? " " : domain)
                        .font(.spaceMono(.regular, size: 15))
                        .foregroundColor(domainColor(for: domain))
                }
                Spacer()
            }
            .padding(.vertical, NothingTheme.spaceSM)
            .contentShape(Rectangle())
            .background(
                editingIndex == index || selectedIndex == index
                    ? NothingColors.surface
                    : Color.clear
            )
            .onTapGesture {
                guard !isReadOnly else { return }
                if editingIndex == index {
                    return // already editing this row
                }
                // Commit any existing edit first
                if let existingIndex = editingIndex {
                    commitEdit(at: existingIndex)
                }
                startEditing(index)
            }

            Divider()
                .frame(height: 1)
                .background(NothingColors.border)
        }
    }

    private func domainColor(for domain: String) -> Color {
        if domain.isEmpty {
            return NothingColors.textDisabled
        }
        if !blocklistVM.isValidDomain(domain) {
            return NothingColors.accent
        }
        return NothingColors.textPrimary
    }

    // MARK: - Editing

    private func startEditing(_ index: Int) {
        editingIndex = index
        editingText = blocklistVM.domains[index]
        selectedIndex = index
        // Delay focus to allow view update
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            isEditFieldFocused = true
        }
    }

    private func commitEdit(at index: Int) {
        guard editingIndex == index else { return }
        blocklistVM.updateDomain(at: index, newValue: editingText)
        editingIndex = nil
        editingText = ""
        // Adjust selectedIndex if domain was removed (empty edit)
        let trimmed = editingText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            selectedIndex = nil
        }
    }

    private func cancelEdit() {
        editingIndex = nil
        editingText = ""
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: NothingTheme.spaceSM) {
            // Remove button
            Button {
                if let index = selectedIndex ?? editingIndex {
                    if editingIndex != nil { cancelEdit() }
                    blocklistVM.removeDomain(at: index)
                    if blocklistVM.domains.isEmpty {
                        selectedIndex = nil
                    } else {
                        selectedIndex = min(index, blocklistVM.domains.count - 1)
                    }
                }
            } label: {
                Image(systemName: "minus")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(NothingColors.textSecondary)
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(selectedIndex == nil && editingIndex == nil)
            .opacity((selectedIndex == nil && editingIndex == nil) ? 0.4 : 1.0)

            Spacer()

            // Import dropdown
            NothingDropdown(
                label: "IMPORT",
                options: ["Common Distractions", "News & Publications", "NSFW"],
                selected: $importSelection,
                onSelect: { option in
                    handleImport(option)
                    importSelection = "IMPORT"
                }
            )
            .frame(width: 220)
        }
    }

    // MARK: - Actions

    private func handleImport(_ option: String) {
        switch option {
        case "Common Distractions":
            blocklistVM.importCommonDistractions()
        case "News & Publications":
            blocklistVM.importNews()
        case "NSFW":
            blocklistVM.importNSFW()
        default:
            break
        }
    }
}

// MARK: - Preview

@available(macOS 16.0, *)
#Preview {
    BlocklistSettingsView()
        .environment(BlocklistViewModel())
        .environment(BlockStateViewModel())
        .environment(PreferencesViewModel())
        .frame(width: 440, height: 500)
        .background(NothingColors.background)
}
