import SwiftUI

// MARK: - BlocklistSettingsView

/// Blocklist/Allowlist editor for the settings area.
///
/// Features:
/// - A | B mode tabs at top to switch between mode blocklists
/// - Per-mode blocklist/allowlist toggle
/// - Permanent text field for adding new entries
/// - Single-click inline editing of existing entries
/// - Import dropdown for preset lists
/// - Read-only mode during active blocks
@available(macOS 16.0, *)
struct BlocklistSettingsView: View {

    @Environment(ModeViewModel.self) private var modeVM
    @Environment(BlockStateViewModel.self) private var blockState

    @State private var editingModeID: ModeID = .a
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

    /// The domains for the currently selected mode tab.
    private var currentDomains: [String] {
        modeVM.mode(for: editingModeID).domains
    }

    /// Whether the current mode tab is in allowlist mode.
    private var currentIsAllowlist: Bool {
        modeVM.mode(for: editingModeID).isAllowlist
    }

    var body: some View {
        VStack(spacing: 0) {
            // MARK: Mode Tabs (A | B) + Allowlist Toggle

            HStack(spacing: NothingTheme.spaceXS) {
                ForEach(ModeID.allCases) { id in
                    modeTab(id)
                }

                Spacer()

                // Allowlist/Blocklist toggle
                Button {
                    guard !isReadOnly else { return }
                    var mode = modeVM.mode(for: editingModeID)
                    mode.isAllowlist.toggle()
                    modeVM.update(mode)
                } label: {
                    Text(currentIsAllowlist ? "ALLOWLIST" : "BLOCKLIST")
                        .font(.spaceMono(.regular, size: 10))
                        .textCase(.uppercase)
                        .tracking(NothingTheme.labelTracking * 10)
                        .foregroundColor(
                            currentIsAllowlist
                                ? NothingColors.interactive
                                : NothingColors.textSecondary
                        )
                }
                .buttonStyle(.plain)
                .disabled(isReadOnly)
            }
            .padding(.horizontal, NothingTheme.spaceMD)
            .padding(.top, NothingTheme.spaceSM)
            .padding(.bottom, NothingTheme.spaceSM)

            // MARK: Add Field

            if !isReadOnly {
                addField
                    .padding(.horizontal, NothingTheme.spaceMD)
            }

            // MARK: Domain List

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(currentDomains.enumerated()), id: \.offset) { index, domain in
                        domainRow(domain: domain, index: index)
                    }
                }
            }
            .padding(.horizontal, NothingTheme.spaceMD)

            // MARK: Read-Only Notice

            if isReadOnly {
                Text("LOCKED DURING ACTIVE BLOCK")
                    .font(.spaceMono(.regular, size: 10))
                    .textCase(.uppercase)
                    .tracking(NothingTheme.labelTracking * 10)
                    .foregroundColor(NothingColors.textDisabled)
                    .padding(.vertical, NothingTheme.spaceSM)
            }

            // MARK: Toolbar

            if !isReadOnly {
                toolbar
                    .padding(.horizontal, NothingTheme.spaceMD)
                    .padding(.vertical, NothingTheme.spaceSM)
            }
        }
        .onChange(of: editingModeID) { _, _ in
            cancelEdit()
            selectedIndex = nil
            newDomainText = ""
        }
        .onChange(of: isEditFieldFocused) { _, focused in
            if !focused, let index = editingIndex {
                commitEdit(at: index)
            }
        }
    }

    // MARK: - Mode Tab

    private func modeTab(_ id: ModeID) -> some View {
        Button {
            withAnimation(.easeOut(duration: NothingTheme.microDuration)) {
                editingModeID = id
            }
        } label: {
            Text(id.label)
                .font(.spaceMono(.bold, size: 12))
                .foregroundColor(
                    editingModeID == id
                        ? NothingColors.textDisplay
                        : NothingColors.textDisabled
                )
                .frame(width: 28, height: 26)
                .background(
                    editingModeID == id
                        ? NothingColors.surface
                        : Color.clear
                )
                .cornerRadius(NothingTheme.radiusTechnical)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Add Field

    private var addField: some View {
        VStack(spacing: 0) {
            TextField("example.com", text: $newDomainText)
                .font(.spaceMono(.regular, size: 13))
                .foregroundColor(NothingColors.textPrimary)
                .textFieldStyle(.plain)
                .focused($isAddFieldFocused)
                .onSubmit {
                    let trimmed = newDomainText.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    var mode = modeVM.mode(for: editingModeID)
                    mode.domains.append(trimmed)
                    modeVM.update(mode)
                    newDomainText = ""
                }
                .padding(.vertical, NothingTheme.spaceSM)

            Rectangle()
                .fill(isAddFieldFocused ? NothingColors.textPrimary : NothingColors.borderVisible)
                .frame(height: 1)
        }
        .padding(.bottom, NothingTheme.spaceXS)
    }

    // MARK: - Domain Row

    private func domainRow(domain: String, index: Int) -> some View {
        VStack(spacing: 0) {
            HStack {
                if editingIndex == index && !isReadOnly {
                    TextField("", text: $editingText)
                        .font(.spaceMono(.regular, size: 13))
                        .foregroundColor(NothingColors.textPrimary)
                        .textFieldStyle(.plain)
                        .focused($isEditFieldFocused)
                        .onSubmit { commitEdit(at: index) }
                        .onExitCommand { cancelEdit() }
                } else {
                    Text(domain.isEmpty ? " " : domain)
                        .font(.spaceMono(.regular, size: 13))
                        .foregroundColor(NothingColors.textPrimary)
                        .lineLimit(1)
                        .truncationMode(.middle)
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
                if editingIndex == index { return }
                if let existingIndex = editingIndex {
                    commitEdit(at: existingIndex)
                }
                startEditing(index)
            }

            Rectangle()
                .fill(NothingColors.border)
                .frame(height: 1)
        }
    }

    // MARK: - Editing

    private func startEditing(_ index: Int) {
        editingIndex = index
        editingText = currentDomains[index]
        selectedIndex = index
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            isEditFieldFocused = true
        }
    }

    private func commitEdit(at index: Int) {
        guard editingIndex == index else { return }
        let trimmed = editingText.trimmingCharacters(in: .whitespacesAndNewlines)
        var mode = modeVM.mode(for: editingModeID)
        if trimmed.isEmpty {
            mode.domains.remove(at: index)
            selectedIndex = nil
        } else {
            mode.domains[index] = trimmed
        }
        modeVM.update(mode)
        editingIndex = nil
        editingText = ""
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
                    var mode = modeVM.mode(for: editingModeID)
                    guard mode.domains.indices.contains(index) else { return }
                    mode.domains.remove(at: index)
                    modeVM.update(mode)
                    if mode.domains.isEmpty {
                        selectedIndex = nil
                    } else {
                        selectedIndex = min(index, mode.domains.count - 1)
                    }
                }
            } label: {
                Image(systemName: "minus")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(NothingColors.textSecondary)
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(selectedIndex == nil && editingIndex == nil)
            .opacity((selectedIndex == nil && editingIndex == nil) ? 0.4 : 1.0)

            Spacer()

            // Import dropdown
            NothingDropdown(
                label: "",
                options: ["Common Distractions", "News & Publications", "NSFW"],
                selected: $importSelection,
                onSelect: { option in
                    handleImport(option)
                    importSelection = "IMPORT"
                }
            )
        }
    }

    // MARK: - Actions

    private func handleImport(_ option: String) {
        var mode = modeVM.mode(for: editingModeID)
        let existingSet = Set(mode.domains)

        let newEntries: [String]
        switch option {
        case "Common Distractions":
            newEntries = (HostImporter.commonDistractingWebsites() as? [String]) ?? []
        case "News & Publications":
            newEntries = (HostImporter.newsAndPublications() as? [String]) ?? []
        case "NSFW":
            newEntries = (HostImporter.nsfwWebsites() as? [String]) ?? []
        default:
            return
        }

        let unique = newEntries.filter { !existingSet.contains($0) }
        guard !unique.isEmpty else { return }
        mode.domains.append(contentsOf: unique)
        modeVM.update(mode)
    }
}

// MARK: - Preview

@available(macOS 16.0, *)
#Preview {
    BlocklistSettingsView()
        .environment(ModeViewModel())
        .environment(BlockStateViewModel())
        .environment(PreferencesViewModel())
        .frame(width: 450, height: 340)
        .background(NothingColors.background)
}
