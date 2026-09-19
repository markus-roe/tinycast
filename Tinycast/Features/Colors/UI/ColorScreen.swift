import SwiftUI

/// Picked colours and a live conversion of whatever the search field spells.
struct ColorScreen: PaletteScreen {
    let history: ColorHistoryStore
    let core: AppCore
    let vm: PaletteState
    let openActions: () -> Void

    enum Row: Equatable, Identifiable {
        case pick
        case parsed(ColorValue)
        case history(ColorHistoryEntry)

        var id: String {
            switch self {
            case .pick: return "pick"
            case .parsed: return "parsed"
            case .history(let entry): return entry.id.uuidString
            }
        }
    }

    private var parsed: ColorValue? { ColorValue.parse(vm.query) }
    private var matches: [ColorHistoryEntry] { history.search(vm.query) }

    var rows: [Row] {
        var rows: [Row] = [.pick]
        if let parsed { rows.append(.parsed(parsed)) }
        rows.append(contentsOf: matches.map(Row.history))
        return rows
    }

    var primaryActionTitle: String {
        if case .pick = row(at: vm.selection) { return "Pick Color" }
        return "Copy"
    }

    var actsWithoutRows: Bool { true }

    private func row(at selection: Int) -> Row? {
        let rows = rows
        return rows.indices.contains(selection) ? rows[selection] : nil
    }

    func actions(at selection: Int) -> PopoverMenuContent? {
        switch row(at: selection) {
        case .pick:
            return PopoverMenuContent(
                header: "Pick Color",
                items: [
                    PopoverMenuItem(
                        title: "Pick from Screen", systemImage: "eyedropper", shortcut: "↵"
                    ) {
                        core.colorCoordinator.pickFromScreen(reopenHistory: true)
                    }
                ])
        case .parsed(let color):
            return ColorActionsMenu.content(color: color, core: core)
        case .history(let entry):
            return ColorHistoryActionsMenu.content(entry: entry, core: core)
        case nil:
            return nil
        }
    }

    func activate(at selection: Int) {
        switch row(at: selection) {
        case .pick:
            core.colorCoordinator.pickFromScreen(reopenHistory: true)
        case .parsed(let color):
            core.colorCoordinator.copy(color, as: ColorFormat.primary(for: color))
        case .history(let entry):
            core.colorCoordinator.copy(entry.color, as: ColorFormat.primary(for: entry.color))
        case nil:
            break
        }
    }

    func secondary(at selection: Int) -> Bool {
        switch row(at: selection) {
        case .parsed(let color):
            core.colorCoordinator.copy(color, as: ColorFormat.hex)
            return true
        case .history(let entry):
            core.colorCoordinator.copy(entry.color, as: ColorFormat.hex)
            return true
        default:
            return false
        }
    }

    func pasteKeepingWindowOpen(at selection: Int) -> Bool {
        switch row(at: selection) {
        case .parsed(let color):
            core.colorCoordinator.copyKeepingWindowOpen(
                color, as: ColorFormat.primary(for: color))
            return true
        case .history(let entry):
            core.colorCoordinator.copyKeepingWindowOpen(
                entry.color, as: ColorFormat.primary(for: entry.color))
            return true
        default:
            return false
        }
    }

    func perform(_ shortcut: PaletteShortcut, at selection: Int) -> Bool {
        switch shortcut {
        case .commandDelete, .delete:
            guard case .history(let entry) = row(at: selection) else { return false }
            core.colorCoordinator.delete(entry)
            return true
        case .deleteAll:
            Task { await core.colorCoordinator.deleteAll() }
            return true
        default:
            return false
        }
    }

    func body(selection: Int, scroll: ScrollIntent) -> AnyView {
        AnyView(
            ColorHistoryList(
                rows: rows, selection: selection, scroll: scroll,
                onSelect: { vm.selection = $0 },
                onActivate: { activate(at: vm.selection) },
                onActions: { index in
                    vm.selection = index
                    openActions()
                }))
    }
}

@MainActor
enum ColorHistoryActionsMenu {
    static func content(entry: ColorHistoryEntry, core: AppCore) -> PopoverMenuContent {
        let color = entry.color
        let primary = ColorFormat.primary(for: color)
        var items = ColorFormat.offered(for: color).map { format in
            PopoverMenuItem(
                title: format.title, icon: .blank,
                shortcut: format == primary ? "↵" : nil, detail: format.string(for: color)
            ) {
                core.colorCoordinator.copy(color, as: format)
            }
        }
        items.append(
            PopoverMenuItem(
                title: "Delete Entry", systemImage: "trash", startsSection: true, shortcut: "⌃X",
                isDestructive: true
            ) {
                core.colorCoordinator.delete(entry)
            })
        items.append(
            PopoverMenuItem(
                title: "Delete All Entries", systemImage: "trash", shortcut: "⌃⇧X",
                isDestructive: true
            ) {
                Task { await core.colorCoordinator.deleteAll() }
            })
        return PopoverMenuContent(header: primary.string(for: color), items: items)
    }
}
