import AppKit

@MainActor
final class ReminderCoordinator {
    private let store: ReminderStore
    private let settings: AppSettings
    private let appIndex: AppIndex
    private let paletteCoordinator: PaletteCoordinator
    private unowned let core: AppCore

    init(
        store: ReminderStore, settings: AppSettings, appIndex: AppIndex,
        paletteCoordinator: PaletteCoordinator, core: AppCore
    ) {
        self.store = store
        self.settings = settings
        self.appIndex = appIndex
        self.paletteCoordinator = paletteCoordinator
        self.core = core
    }

    func setRemindersEnabled(_ enabled: Bool, thenShow: Bool = false) {
        if !enabled {
            guard settings.remindersEnabled else { return }
            settings.remindersEnabled = false
            applyEnabled()
            return
        }

        store.refreshAccess()
        guard !settings.remindersEnabled || store.access != .granted else {
            if thenShow { showReady() }
            return
        }
        NSApp.activate(ignoringOtherApps: true)
        Task {
            guard
                await core.confirm(
                    title: "Enable Reminders?",
                    message:
                        "Tinycast reads and writes your Apple Reminders so they sync to your iPhone. "
                        + "Nothing else leaves this Mac.",
                    symbol: "bell", confirmTitle: "Continue", tone: .neutral,
                    confirmRole: .standard)
            else { return }

            guard await store.requestAccess() else { return }
            settings.remindersEnabled = true
            applyEnabled()
            if thenShow { showReady() }
        }
    }

    func applyEnabled() {
        let enabled = settings.remindersEnabled
        let commands: Set<CommandID> = [.reminders, .createReminder]
        appIndex.setCommandsVisible(commands, enabled)
        appIndex.setCommandsListed(commands, settings.remindersShowInLauncher)
        appIndex.setApplicationsListed([Self.appBundleID], !enabled)
        guard enabled else {
            store.stop()
            return
        }
        store.start()
    }

    func show() {
        guard settings.remindersEnabled, store.access == .granted else {
            setRemindersEnabled(true, thenShow: true)
            return
        }
        showReady()
    }

    func create() {
        guard settings.remindersEnabled, store.access == .granted else {
            setRemindersEnabled(true, thenShow: true)
            return
        }
        paletteCoordinator.hidePalette(restoreFocus: false)
        Task {
            if await prompt() {
                paletteCoordinator.showPalette(mode: .reminders)
            }
        }
    }

    func add(_ draft: ReminderDraft) {
        add(draft, clearQuery: true)
    }

    func addFromLauncher(_ draft: ReminderDraft) {
        guard add(draft, clearQuery: false) else { return }
        paletteCoordinator.hidePalette(restoreFocus: false)
    }

    func openApp() {
        paletteCoordinator.hidePalette(restoreFocus: false)
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: Self.appBundleID)
        else { return }
        AppLauncher.launch(url)
    }

    func prompt(prefilled: String = "") async -> Bool {
        var form = ReminderForm()
        form.title = prefilled
        guard let draft = await core.createReminder(form: form) else { return false }
        return add(draft, clearQuery: false)
    }

    func complete(_ entry: ReminderEntry) {
        guard store.complete(entry) else {
            core.showMessage("Couldn't update Reminders", tone: .danger)
            return
        }
        core.showMessage("Done")
    }

    func remove(_ entry: ReminderEntry) {
        Task {
            guard
                await core.confirm(
                    title: "Delete “\(entry.title)”?",
                    message: "This removes it from Reminders on all your devices.",
                    symbol: "bell", confirmTitle: "Delete")
            else { return }
            guard store.remove(entry) else {
                core.showMessage("Couldn't delete from Reminders", tone: .danger)
                return
            }
            core.showMessage("Deleted")
        }
    }

    private func showReady() {
        Task { await store.reload() }
        paletteCoordinator.togglePalette(mode: .reminders)
    }

    private static let appBundleID = "com.apple.reminders"

    @discardableResult
    private func add(_ draft: ReminderDraft, clearQuery: Bool) -> Bool {
        guard store.add(draft) else {
            core.showMessage("Couldn't add to Reminders", tone: .danger)
            return false
        }
        core.showMessage(draft.summary(now: Date(), calendar: .current))
        if clearQuery {
            core.palette.query = ""
            core.palette.selection = 0
        }
        return true
    }
}
