import SwiftUI

struct ReminderScreen: PaletteScreen {
    let store: ReminderStore
    let core: AppCore
    let vm: PaletteState
    let openActions: () -> Void

    enum Row: Equatable, Identifiable {
        case compose(ReminderDraft)
        case create
        case item(ReminderEntry)
        case openApp

        var id: String {
            switch self {
            case .compose: return "compose"
            case .create: return "create"
            case .item(let entry): return entry.id
            case .openApp: return "open-app"
            }
        }
    }

    private var calendar: Calendar { .current }
    private var now: Date { Date() }

    private var composeDraft: ReminderDraft? {
        let query = vm.query.trimmingCharacters(in: .whitespacesAndNewlines)
        if let parsed = ReminderQuery.parse(query, now: now, calendar: calendar) { return parsed }
        if !query.isEmpty { return .undated(title: query) }
        return nil
    }

    private var matches: (open: [ReminderEntry], completed: [ReminderEntry]) {
        store.search(vm.query)
    }

    var rows: [Row] {
        var rows: [Row] = []
        if let composeDraft {
            rows.append(.compose(composeDraft))
        } else {
            rows.append(.create)
        }
        rows.append(contentsOf: matches.open.map(Row.item))
        rows.append(contentsOf: matches.completed.map(Row.item))
        rows.append(.openApp)
        return rows
    }

    var primaryActionTitle: String {
        switch row(at: vm.selection) {
        case .compose: return "Add to Reminders"
        case .create: return "New Reminder"
        case .item(let entry): return entry.isCompleted ? "Delete" : "Done"
        case .openApp: return "Open Reminders"
        case nil: return "New Reminder"
        }
    }

    var actsWithoutRows: Bool { true }

    private func row(at selection: Int) -> Row? {
        let rows = rows
        return rows.indices.contains(selection) ? rows[selection] : nil
    }

    func actions(at selection: Int) -> PopoverMenuContent? {
        switch row(at: selection) {
        case .compose(let draft):
            return PopoverMenuContent(
                header: draft.title,
                items: [
                    PopoverMenuItem(
                        title: "Add to Reminders", systemImage: "bell", shortcut: "↵"
                    ) { core.reminderCoordinator.add(draft) },
                    ReminderOpenApp.menuItem(core: core, startsSection: true),
                ])
        case .create:
            return PopoverMenuContent(
                header: "New Reminder",
                items: [
                    PopoverMenuItem(title: "New Reminder…", systemImage: "plus", shortcut: "↵") {
                        Task { await core.reminderCoordinator.prompt() }
                    },
                    ReminderOpenApp.menuItem(core: core, startsSection: true),
                ])
        case .item(let entry):
            return ReminderActionsMenu.content(entry: entry, core: core)
        case .openApp:
            return PopoverMenuContent(
                header: "Reminders",
                items: [ReminderOpenApp.menuItem(core: core, shortcut: "↵", startsSection: false)])
        case nil:
            return nil
        }
    }

    func secondary(at selection: Int) -> Bool { false }

    func activate(at selection: Int) {
        switch row(at: selection) {
        case .compose(let draft):
            core.reminderCoordinator.add(draft)
        case .create:
            Task { await core.reminderCoordinator.prompt() }
        case .item(let entry):
            if entry.isCompleted {
                core.reminderCoordinator.remove(entry)
            } else {
                core.reminderCoordinator.complete(entry)
            }
        case .openApp:
            core.reminderCoordinator.openApp()
        case nil:
            break
        }
    }

    func perform(_ shortcut: PaletteShortcut, at selection: Int) -> Bool {
        guard shortcut == .delete, case .item(let entry) = row(at: selection) else { return false }
        core.reminderCoordinator.remove(entry)
        return true
    }

    func body(selection: Int, scroll: ScrollIntent) -> AnyView {
        AnyView(
            ReminderList(
                rows: rows, selection: selection, scroll: scroll, calendar: calendar,
                onSelect: { vm.selection = $0 },
                onActivate: { activate(at: vm.selection) },
                onActions: { index in
                    vm.selection = index
                    openActions()
                }))
    }
}

@MainActor
enum ReminderActionsMenu {
    static func content(entry: ReminderEntry, core: AppCore) -> PopoverMenuContent {
        var items = [
            PopoverMenuItem(
                title: entry.isCompleted ? "Delete" : "Done",
                systemImage: entry.isCompleted ? "trash" : "checkmark",
                shortcut: "↵", isDestructive: entry.isCompleted
            ) {
                if entry.isCompleted {
                    core.reminderCoordinator.remove(entry)
                } else {
                    core.reminderCoordinator.complete(entry)
                }
            }
        ]
        items.append(
            PopoverMenuItem(
                title: "Delete", systemImage: "trash", startsSection: true, shortcut: "⌃X",
                isDestructive: true
            ) { core.reminderCoordinator.remove(entry) })
        items.append(ReminderOpenApp.menuItem(core: core, startsSection: true))
        return PopoverMenuContent(header: entry.title, items: items)
    }
}

@MainActor
enum ReminderOpenApp {
    static func menuItem(
        core: AppCore, shortcut: String? = nil, startsSection: Bool = false
    ) -> PopoverMenuItem {
        PopoverMenuItem(
            title: "Open Reminders", systemImage: "arrow.up.forward.app",
            startsSection: startsSection, shortcut: shortcut
        ) { core.reminderCoordinator.openApp() }
    }
}
