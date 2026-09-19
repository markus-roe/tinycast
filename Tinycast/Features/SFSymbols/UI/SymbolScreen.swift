import SwiftUI

/// Searchable SF Symbols grid; ↑/↓ move by visual row, the same contract as the emoji picker.
struct SymbolScreen: PaletteScreen {
    let index: SymbolIndex
    let frequent: FrequentSymbolStore
    let core: AppCore
    let vm: PaletteState
    let openActions: () -> Void

    private var columns: EmojiGridColumns { .eight }

    private var sections: [SymbolGridSection] {
        SymbolGrid.sections(
            query: vm.query, index: index, frequent: frequent, filter: vm.sfSymbolCategoryFilter)
    }

    var rows: [SymbolEntry] { sections.flatMap(\.entries) }

    var primaryActionTitle: String { vm.pasteTarget?.pasteTitle ?? "Paste" }

    private func entry(at selection: Int) -> SymbolEntry? {
        let rows = rows
        return rows.indices.contains(selection) ? rows[selection] : nil
    }

    func actions(at selection: Int) -> PopoverMenuContent? {
        guard let entry = entry(at: selection) else { return nil }
        return SymbolActionsMenu.content(entry: entry, core: core, target: vm.pasteTarget)
    }

    func activate(at selection: Int) {
        guard let entry = entry(at: selection) else { return }
        core.symbolCoordinator.paste(entry)
    }

    func secondary(at selection: Int) -> Bool {
        guard let entry = entry(at: selection) else { return false }
        core.symbolCoordinator.copy(entry)
        return true
    }

    func pasteKeepingWindowOpen(at selection: Int) -> Bool {
        guard let entry = entry(at: selection) else { return false }
        core.symbolCoordinator.pasteKeepingWindowOpen(entry)
        return true
    }

    func move(_ delta: Int, axis: PaletteAxis, from selection: Int) -> Int? {
        let sections = sections
        let count = sections.reduce(0) { $0 + $1.entries.count }
        guard count > 0 else { return selection }
        switch axis {
        case .vertical:
            let geometry = EmojiGridGeometry(
                counts: sections.map(\.entries.count), columns: columns.rawValue)
            return delta > 0 ? geometry.down(from: selection) : geometry.up(from: selection)
        case .horizontal:
            return min(max(selection + delta, 0), count - 1)
        }
    }

    func body(selection: Int, scroll: ScrollIntent) -> AnyView {
        AnyView(content(selection: selection, scroll: scroll))
    }

    @ViewBuilder
    private func content(selection: Int, scroll: ScrollIntent) -> some View {
        let sections = sections
        if !index.isLoaded {
            EmptyResults(text: "Loading SF Symbols…")
        } else if sections.isEmpty {
            EmptyResults(text: "No symbols found")
        } else {
            SymbolGridView(
                sections: sections, selection: selection, columns: columns, scroll: scroll,
                onSelect: { vm.selection = $0 },
                onActivate: { activate(at: vm.selection) },
                onActions: { flat in
                    vm.selection = flat
                    openActions()
                })
        }
    }
}

@MainActor
enum SymbolActionsMenu {
    static func content(entry: SymbolEntry, core: AppCore, target: PasteTarget?)
        -> PopoverMenuContent
    {
        PopoverMenuContent(
            header: entry.name,
            items: [
                PopoverMenuItem(
                    title: target?.pasteTitle ?? "Paste Name",
                    icon: .paste(target, fallback: "doc.on.clipboard"), shortcut: "↵"
                ) {
                    core.symbolCoordinator.paste(entry)
                },
                PopoverMenuItem(
                    title: "Copy Name", systemImage: "doc.on.doc", shortcut: "⌘↵"
                ) {
                    core.symbolCoordinator.copy(entry)
                },
                PopoverMenuItem(
                    title: "Paste and Keep Window Open",
                    icon: .paste(target, fallback: "macwindow"), shortcut: "⌥↵"
                ) {
                    core.symbolCoordinator.pasteKeepingWindowOpen(entry)
                },
                PopoverMenuItem(
                    title: "Copy Swift Image", icon: .symbol("swift"), startsSection: true,
                    detail: SymbolCopyFormat.swiftImage.string(for: entry.name)
                ) {
                    core.symbolCoordinator.copy(entry, as: .swiftImage)
                },
                PopoverMenuItem(
                    title: "Copy Swift Label", icon: .symbol("swift"),
                    detail: SymbolCopyFormat.swiftLabel.string(for: entry.name)
                ) {
                    core.symbolCoordinator.copy(entry, as: .swiftLabel)
                },
            ])
    }
}
