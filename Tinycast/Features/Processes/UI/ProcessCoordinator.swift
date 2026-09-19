import AppKit

@MainActor
final class ProcessCoordinator {
    private let session: ProcessSession
    private let paletteCoordinator: PaletteCoordinator
    private unowned let core: AppCore

    init(session: ProcessSession, paletteCoordinator: PaletteCoordinator, core: AppCore) {
        self.session = session
        self.paletteCoordinator = paletteCoordinator
        self.core = core
    }

    func show() {
        paletteCoordinator.togglePalette(mode: .processes)
        Task { await session.refresh() }
    }

    func quit(_ entry: ProcessEntry) {
        guard canSignal(entry) else {
            refuse(entry)
            return
        }
        do {
            try ProcessRunner.terminate(pid: entry.pid)
            session.remove(pid: entry.pid)
            core.showMessage("Quit \(entry.name)")
        } catch {
            Task { await report(entry, verb: "Quit") }
        }
    }

    func forceQuit(_ entry: ProcessEntry) {
        guard canSignal(entry) else {
            refuse(entry)
            return
        }
        Task {
            let confirmed = await core.confirm(
                title: "Force Quit \(entry.name)?",
                message: "PID \(entry.pid) will be killed immediately.",
                symbol: "xmark.app", confirmTitle: "Force Quit")
            guard confirmed else { return }
            do {
                try ProcessRunner.forceTerminate(pid: entry.pid)
                session.remove(pid: entry.pid)
                core.showMessage("Force-quit \(entry.name)")
            } catch {
                await report(entry, verb: "Force Quit")
            }
        }
    }

    func copyPID(_ entry: ProcessEntry) {
        Paster.copyPlainText(String(entry.pid))
        core.showMessage("Copied PID")
    }

    func copyName(_ entry: ProcessEntry) {
        Paster.copyPlainText(entry.name)
        core.showMessage("Copied name")
    }

    private func canSignal(_ entry: ProcessEntry) -> Bool {
        ProcessPolicy.canSignal(entry, selfPID: ProcessInfo.processInfo.processIdentifier)
    }

    private func refuse(_ entry: ProcessEntry) {
        if ProcessPolicy.isProtected(
            pid: entry.pid, name: entry.name, selfPID: ProcessInfo.processInfo.processIdentifier)
        {
            core.showMessage("Can’t quit \(entry.name)", tone: .danger)
        } else {
            core.showMessage("Not your process", tone: .danger)
        }
    }

    private func report(_ entry: ProcessEntry, verb: String) async {
        await core.showNotice(
            title: "Couldn’t \(verb) \(entry.name)",
            message: "PID \(entry.pid) refused the signal.",
            symbol: "xmark.app", tone: .danger)
    }
}
