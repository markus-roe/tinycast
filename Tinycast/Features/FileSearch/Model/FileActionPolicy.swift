import Foundation

enum FileActionPolicy {
    static let colorTagNames = ["Red", "Orange", "Yellow", "Green", "Blue", "Purple", "Gray"]

    /// First installed wins. Cursor before VS Code because that is the editor this feature is for.
    static let editorBundleIDs = [
        "com.todesktop.230313mzl4w4u92",
        "com.microsoft.VSCode",
        "dev.zed.Zed",
        "com.apple.dt.Xcode",
        "com.panic.Nova",
        "com.sublimetext.4",
    ]

    static let documentEditorBundleID = "com.apple.TextEdit"

    static let terminalBundleIDs = [
        "com.mitchellh.ghostty",
        "dev.warp.Warp-Stable",
        "com.googlecode.iterm2",
        "com.apple.Terminal",
    ]

    static func containerURL(for url: URL, isDirectory: Bool) -> URL {
        isDirectory ? url : url.deletingLastPathComponent()
    }

    static func editorBundleIDs(openingFolder: Bool) -> [String] {
        openingFolder ? editorBundleIDs : editorBundleIDs + [documentEditorBundleID]
    }

    static func parsedTag(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    static func isColorTag(_ tag: String) -> Bool {
        colorTagNames.contains { $0.caseInsensitiveCompare(tag) == .orderedSame }
    }

    static func applying(_ tag: String, to tags: [String]) -> [String] {
        if tags.contains(where: { $0.caseInsensitiveCompare(tag) == .orderedSame }) { return tags }
        return tags + [tag]
    }

    static func removing(_ tag: String, from tags: [String]) -> [String] {
        tags.filter { $0.caseInsensitiveCompare(tag) != .orderedSame }
    }

    static func toggling(_ tag: String, in tags: [String]) -> [String] {
        tags.contains(where: { $0.caseInsensitiveCompare(tag) == .orderedSame })
            ? removing(tag, from: tags) : applying(tag, to: tags)
    }
}
