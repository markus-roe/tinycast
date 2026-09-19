import AppKit

/// Eyedropper, history and copy: one funnel so a pick and a typed conversion land in the same file.
@MainActor
final class ColorCoordinator {
    private let history: ColorHistoryStore
    private let windowController: PaletteWindowController
    private let paletteCoordinator: PaletteCoordinator
    private unowned let core: AppCore

    init(
        history: ColorHistoryStore,
        windowController: PaletteWindowController,
        paletteCoordinator: PaletteCoordinator,
        core: AppCore
    ) {
        self.history = history
        self.windowController = windowController
        self.paletteCoordinator = paletteCoordinator
        self.core = core
    }

    func showHistory() {
        paletteCoordinator.togglePalette(mode: .colors)
    }

    func pickFromScreen(reopenHistory: Bool = false) {
        paletteCoordinator.hidePalette(restoreFocus: false)
        Task { await sample(reopenHistory: reopenHistory) }
    }

    func copy(_ color: ColorValue, as format: ColorFormat) {
        history.record(color)
        paletteCoordinator.hidePalette(restoreFocus: false)
        Paster.copyPlainText(format.string(for: color))
    }

    func copyKeepingWindowOpen(_ color: ColorValue, as format: ColorFormat) {
        history.record(color)
        windowController.pasteStringKeepingWindowOpen(format.string(for: color))
    }

    func delete(_ entry: ColorHistoryEntry) {
        history.remove(entry)
    }

    private func sample(reopenHistory: Bool) async {
        NSApp.activate(ignoringOtherApps: true)
        guard let color = await ColorSampler.pick() else { return }
        let format = ColorFormat.primary(for: color)
        history.record(color)
        Paster.copyPlainText(format.string(for: color))
        core.showMessage(format.string(for: color))
        if reopenHistory { paletteCoordinator.showPalette(mode: .colors) }
    }

    func deleteAll() async {
        guard
            await core.confirm(
                title: "Clear color history?",
                message: "Every picked colour goes. This can't be undone.",
                symbol: PaletteMode.colors.systemImage, confirmTitle: "Clear History")
        else { return }
        history.clearAll()
    }
}
