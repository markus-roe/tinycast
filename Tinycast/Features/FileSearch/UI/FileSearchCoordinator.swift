import AppKit

@MainActor
final class FileSearchCoordinator {
    private let settings: AppSettings
    private let appIndex: AppIndex
    private let session: FileSearchSession
    private let palette: PaletteState
    private let paletteCoordinator: PaletteCoordinator
    private let windowController: PaletteWindowController
    private unowned let core: AppCore

    init(
        settings: AppSettings, appIndex: AppIndex, session: FileSearchSession,
        palette: PaletteState, paletteCoordinator: PaletteCoordinator,
        windowController: PaletteWindowController, core: AppCore
    ) {
        self.settings = settings
        self.appIndex = appIndex
        self.session = session
        self.palette = palette
        self.paletteCoordinator = paletteCoordinator
        self.windowController = windowController
        self.core = core
    }

    func applyEnabled() {
        appIndex.setCommandsVisible([.searchFiles], settings.fileSearchEnabled)
        guard !settings.fileSearchEnabled else { return }
        session.cancel()
        if palette.mode == .fileSearch { palette.prepare(mode: .launcher) }
    }

    func applyPolicy() {
        session.apply(
            scopes: settings.fileSearchScopes, ignorePatterns: settings.fileSearchIgnorePatterns)
    }

    /// `query` is the fallback row's: the screen opens already narrowed to what was typed.
    func show(query: String = "") {
        guard settings.fileSearchEnabled else { return }
        paletteCoordinator.togglePalette(mode: .fileSearch, seeding: query.isEmpty ? nil : query)
    }

    func open(_ result: FileSearchResult) {
        paletteCoordinator.hidePalette(restoreFocus: false)
        Task {
            do {
                _ = try await NSWorkspace.shared.open(
                    result.url, configuration: NSWorkspace.OpenConfiguration())
            } catch {
                await core.showNotice(
                    title: "Couldn’t Open \(result.name)",
                    message: error.localizedDescription,
                    symbol: result.isDirectory ? "folder" : "doc", tone: .danger)
            }
        }
    }

    func showInFinder(_ result: FileSearchResult) {
        paletteCoordinator.hidePalette(restoreFocus: false)
        AppLauncher.showInFinder(result.url)
    }

    func copyPath(_ result: FileSearchResult) {
        Paster.copyPlainText(result.id)
        core.showMessage("Copied path")
    }

    func copyName(_ result: FileSearchResult) {
        Paster.copyPlainText(result.name)
        core.showMessage("Copied name")
    }

    /// The file itself rather than its path, so Finder and Mail paste a copy of it.
    func copyFile(_ result: FileSearchResult) {
        PasteboardFiles.write(result.url, to: .general)
        core.showMessage("Copied file")
    }

    /// Into whichever app the palette was summoned over, which is what the row's title names.
    func pasteFile(_ result: FileSearchResult) {
        let previous = windowController.previousApp
        paletteCoordinator.hidePalette(restoreFocus: false)
        Paster.pasteFile(result.url, previousApp: previous)
    }

    func trash(_ result: FileSearchResult) {
        Task {
            do {
                try await Task.detached(priority: .userInitiated) {
                    try FileManager.default.trashItem(at: result.url, resultingItemURL: nil)
                }.value
                session.remove(result)
                core.showMessage("Moved to Trash")
            } catch {
                await core.showNotice(
                    title: "Couldn’t Move \(result.name) to Trash",
                    message: error.localizedDescription,
                    symbol: "trash", tone: .danger)
            }
        }
    }

    func openInTerminal(_ result: FileSearchResult) {
        guard let terminal = FileActionRunner.installedTerminal() else {
            Task {
                await core.showNotice(
                    title: "No Terminal Found",
                    message: "Install Terminal, iTerm, Warp or Ghostty.",
                    symbol: "terminal", tone: .danger)
            }
            return
        }
        let folder = FileActionPolicy.containerURL(for: result.url, isDirectory: result.isDirectory)
        paletteCoordinator.hidePalette(restoreFocus: false)
        Task {
            do {
                try await FileActionRunner.open([folder], withApplicationAt: terminal.url)
            } catch {
                await core.showNotice(
                    title: "Couldn’t Open in \(terminal.name)",
                    message: error.localizedDescription,
                    symbol: "terminal", tone: .danger)
            }
        }
    }

    func openInEditor(_ result: FileSearchResult) {
        guard let editor = FileActionRunner.installedEditor(openingFolder: result.isDirectory)
        else {
            Task {
                await core.showNotice(
                    title: "No Editor Found",
                    message: "Install Cursor, VS Code, Zed, Xcode or TextEdit.",
                    symbol: "chevron.left.forwardslash.chevron.right", tone: .danger)
            }
            return
        }
        paletteCoordinator.hidePalette(restoreFocus: false)
        Task {
            do {
                try await FileActionRunner.open([result.url], withApplicationAt: editor.url)
            } catch {
                await core.showNotice(
                    title: "Couldn’t Open in \(editor.name)",
                    message: error.localizedDescription,
                    symbol: "chevron.left.forwardslash.chevron.right", tone: .danger)
            }
        }
    }

    func shareViaAirDrop(_ result: FileSearchResult) {
        paletteCoordinator.hidePalette(restoreFocus: false)
        guard FileActionRunner.shareViaAirDrop(result.url) else {
            Task {
                await core.showNotice(
                    title: "Couldn’t Share \(result.name)",
                    message: "AirDrop is unavailable for this item.",
                    symbol: "square.and.arrow.up", tone: .danger)
            }
            return
        }
    }

    func toggleTag(_ tag: String, on result: FileSearchResult) {
        writeTags(FileActionPolicy.toggling(tag, in: FileActionRunner.tags(at: result.url)), on: result)
    }

    func addTag(_ result: FileSearchResult) {
        Task {
            guard
                let raw = await core.prompt(
                    title: "Add Tag", message: "Finder shows it on \(result.name).",
                    symbol: "tag", placeholder: "Work", confirmTitle: "Add"),
                let tag = FileActionPolicy.parsedTag(raw)
            else { return }
            writeTags(
                FileActionPolicy.applying(tag, to: FileActionRunner.tags(at: result.url)),
                on: result)
        }
    }

    private func writeTags(_ tags: [String], on result: FileSearchResult) {
        do {
            try FileActionRunner.setTags(tags, at: result.url)
            core.showMessage(tags.isEmpty ? "Removed tags" : "Updated tags")
        } catch {
            Task {
                await core.showNotice(
                    title: "Couldn’t Tag \(result.name)",
                    message: error.localizedDescription,
                    symbol: "tag", tone: .danger)
            }
        }
    }
}
