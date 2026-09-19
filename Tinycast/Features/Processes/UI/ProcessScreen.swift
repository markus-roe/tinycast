import SwiftUI

struct ProcessScreen: PaletteScreen {
    let session: ProcessSession
    let core: AppCore
    let vm: PaletteState
    let openActions: () -> Void

    var rows: [ProcessEntry] { session.filtered }

    var primaryActionTitle: String { "Quit" }

    private func entry(at selection: Int) -> ProcessEntry? {
        rows.indices.contains(selection) ? rows[selection] : nil
    }

    func actions(at selection: Int) -> PopoverMenuContent? {
        guard let entry = entry(at: selection) else { return nil }
        return ProcessActionsMenu.content(entry: entry, core: core)
    }

    func activate(at selection: Int) {
        guard let entry = entry(at: selection) else { return }
        core.processCoordinator.quit(entry)
    }

    func secondary(at selection: Int) -> Bool {
        guard let entry = entry(at: selection) else { return false }
        core.processCoordinator.copyPID(entry)
        return true
    }

    func perform(_ shortcut: PaletteShortcut, at selection: Int) -> Bool {
        guard let entry = entry(at: selection) else { return false }
        let coordinator = core.processCoordinator
        switch shortcut {
        case .copyPath:
            coordinator.copyPID(entry)
            return true
        case .copyName:
            coordinator.copyName(entry)
            return true
        case .delete:
            coordinator.forceQuit(entry)
            return true
        default:
            return false
        }
    }

    func body(selection: Int, scroll: ScrollIntent) -> AnyView {
        AnyView(content(selection: selection, scroll: scroll))
    }

    @ViewBuilder
    private func content(selection: Int, scroll: ScrollIntent) -> some View {
        if rows.isEmpty {
            emptyState
        } else {
            ProcessList(
                entries: rows,
                selectedID: rows.indices.contains(selection) ? rows[selection].id : nil,
                scroll: scroll,
                onSelect: { entry in vm.selection = rows.firstIndex(of: entry) ?? 0 },
                onActivate: { core.processCoordinator.quit($0) },
                onActions: { entry in
                    if let index = rows.firstIndex(of: entry) { vm.selection = index }
                    openActions()
                })
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        if session.isLoading {
            Color.clear
        } else if vm.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            EmptyResults(text: "No running processes")
        } else {
            EmptyResults(text: "No processes found")
        }
    }
}

@MainActor
enum ProcessActionsMenu {
    static func content(entry: ProcessEntry, core: AppCore) -> PopoverMenuContent {
        let coordinator = core.processCoordinator
        return PopoverMenuContent(
            header: entry.name,
            items: [
                PopoverMenuItem(title: "Quit", systemImage: "xmark", shortcut: "↵") {
                    coordinator.quit(entry)
                },
                PopoverMenuItem(
                    title: "Force Quit", systemImage: "xmark.app", shortcut: "⌃X",
                    isDestructive: true
                ) { coordinator.forceQuit(entry) },
                PopoverMenuItem(
                    title: "Copy PID", icon: .symbol("doc.on.clipboard"), startsSection: true,
                    shortcut: "⌃⌘C", detail: String(entry.pid)
                ) { coordinator.copyPID(entry) },
                PopoverMenuItem(
                    title: "Copy Name", systemImage: "doc.on.clipboard", shortcut: "⌥⌘C"
                ) { coordinator.copyName(entry) },
            ])
    }
}
