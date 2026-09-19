import AppKit

struct FileActionApp: Equatable, Sendable {
    let bundleID: String
    let name: String
    let url: URL
}

enum FileActionRunner {
    static func installedTerminal() -> FileActionApp? {
        firstInstalled(bundleIDs: FileActionPolicy.terminalBundleIDs)
    }

    static func installedEditor(openingFolder: Bool) -> FileActionApp? {
        firstInstalled(bundleIDs: FileActionPolicy.editorBundleIDs(openingFolder: openingFolder))
    }

    static func firstInstalled(bundleIDs: [String]) -> FileActionApp? {
        let workspace = NSWorkspace.shared
        for bundleID in bundleIDs {
            guard let url = workspace.urlForApplication(withBundleIdentifier: bundleID) else {
                continue
            }
            let name =
                (try? url.resourceValues(forKeys: [.localizedNameKey]).localizedName)
                ?? url.deletingPathExtension().lastPathComponent
            return FileActionApp(bundleID: bundleID, name: name, url: url)
        }
        return nil
    }

    static func open(_ urls: [URL], withApplicationAt application: URL) async throws {
        _ = try await NSWorkspace.shared.open(
            urls, withApplicationAt: application, configuration: NSWorkspace.OpenConfiguration())
    }

    static func shareViaAirDrop(_ url: URL) -> Bool {
        guard let service = NSSharingService(named: .sendViaAirDrop) else { return false }
        guard service.canPerform(withItems: [url]) else { return false }
        service.perform(withItems: [url])
        return true
    }

    static func tags(at url: URL) -> [String] {
        (try? url.resourceValues(forKeys: [.tagNamesKey]).tagNames) ?? []
    }

    static func setTags(_ tags: [String], at url: URL) throws {
        var values = URLResourceValues()
        values.tagNames = tags
        var writable = url
        try writable.setResourceValues(values)
    }
}
