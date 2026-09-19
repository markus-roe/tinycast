import AppKit

/// Owns symbol delivery: frequency tallies the name, the copy format is chosen at the call site.
@MainActor
final class SymbolCoordinator {
    private let frequent: FrequentSymbolStore
    private let windowController: PaletteWindowController
    private let paletteCoordinator: PaletteCoordinator

    init(
        frequent: FrequentSymbolStore,
        windowController: PaletteWindowController,
        paletteCoordinator: PaletteCoordinator
    ) {
        self.frequent = frequent
        self.windowController = windowController
        self.paletteCoordinator = paletteCoordinator
    }

    func paste(_ entry: SymbolEntry, as format: SymbolCopyFormat = .name) {
        frequent.record(entry.name)
        let previous = windowController.previousApp
        paletteCoordinator.hidePalette(restoreFocus: false)
        Paster.pasteString(format.string(for: entry.name), previousApp: previous)
    }

    func copy(_ entry: SymbolEntry, as format: SymbolCopyFormat = .name) {
        frequent.record(entry.name)
        paletteCoordinator.hidePalette(restoreFocus: false)
        Paster.copyString(format.string(for: entry.name))
    }

    func pasteKeepingWindowOpen(_ entry: SymbolEntry, as format: SymbolCopyFormat = .name) {
        frequent.record(entry.name)
        windowController.pasteStringKeepingWindowOpen(format.string(for: entry.name))
    }
}
