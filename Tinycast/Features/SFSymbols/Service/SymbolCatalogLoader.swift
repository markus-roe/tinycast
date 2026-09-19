import Foundation

/// Reads this Mac's CoreGlyphs bundle, so the picker always matches the installed SF Symbols set.
enum SymbolCatalogLoader {
    private static let bundlePaths = [
        "/System/Library/CoreServices/CoreGlyphs.bundle",
        "/System/Library/PrivateFrameworks/SFSymbols.framework/Versions/A/Resources/CoreGlyphs.bundle",
    ]

    /// Rendering-mode collections, not browse sections — they would list almost every symbol twice.
    private static let skippedCategoryKeys: Set<String> = [
        "all", "whatsnew", "draw", "variable", "multicolor",
    ]

    static func load() -> (entries: [SymbolEntry], categories: [SFSymbolCategory]) {
        guard let resources = bundlePaths.lazy.compactMap(resourcesURL).first else {
            return ([], [])
        }
        let names = symbolNames(in: resources)
        let order = stringArray(named: "symbol_order", in: resources)
        let search = stringArrayDictionary(named: "symbol_search", in: resources)
        let grouped = stringArrayDictionary(named: "symbol_categories", in: resources)
        let categories = categories(in: resources)
        let allowed = Set(categories.map(\.key))

        let ranked = order.isEmpty ? names.sorted() : ordered(names, by: order)
        let entries = ranked.map { name in
            let keys = (grouped[name] ?? []).filter { allowed.contains($0) }
            return SymbolEntry(
                name: name,
                keywords: (search[name] ?? []).joined(separator: ","),
                categoryKeys: keys)
        }
        return (entries, categories)
    }

    private static func resourcesURL(at path: String) -> URL? {
        let url = URL(fileURLWithPath: path).appending(path: "Contents/Resources")
        let availability = url.appending(path: "name_availability.plist")
        return FileManager.default.fileExists(atPath: availability.path) ? url : nil
    }

    private static func symbolNames(in resources: URL) -> [String] {
        guard let root = plist(named: "name_availability", in: resources) as? [String: Any],
            let symbols = root["symbols"] as? [String: Any]
        else { return [] }
        return symbols.keys.filter { !isLocalizedVariant($0) }
    }

    /// Locale suffixes are the same glyph drawn for another script; the Latin name is the one you copy.
    private static func isLocalizedVariant(_ name: String) -> Bool {
        name.range(of: #"\.(ar|he|hi|ja|ko|th|zh)(\.|$)"#, options: .regularExpression) != nil
    }

    private static func categories(in resources: URL) -> [SFSymbolCategory] {
        guard let rows = plist(named: "categories", in: resources) as? [[String: Any]] else {
            return []
        }
        return rows.compactMap { row in
            guard let key = row["key"] as? String, !skippedCategoryKeys.contains(key) else {
                return nil
            }
            return SFSymbolCategory(
                key: key, title: title(for: key),
                systemImage: row["icon"] as? String ?? "square.grid.2x2")
        }
    }

    private static func title(for key: String) -> String {
        switch key {
        case "objectsandtools": "Objects & Tools"
        case "cameraandphotos": "Camera & Photos"
        case "privacyandsecurity": "Privacy & Security"
        case "textformatting": "Text Formatting"
        default:
            key.replacingOccurrences(of: "and", with: " & ")
                .replacingOccurrences(of: "And", with: " & ")
                .capitalized
        }
    }

    private static func ordered(_ names: [String], by order: [String]) -> [String] {
        let known = Set(names)
        var seen = Set<String>()
        var ranked: [String] = []
        for name in order where known.contains(name) && seen.insert(name).inserted {
            ranked.append(name)
        }
        for name in names where seen.insert(name).inserted { ranked.append(name) }
        return ranked
    }

    private static func stringArray(named name: String, in resources: URL) -> [String] {
        plist(named: name, in: resources) as? [String] ?? []
    }

    private static func stringArrayDictionary(named name: String, in resources: URL) -> [String: [String]]
    {
        plist(named: name, in: resources) as? [String: [String]] ?? [:]
    }

    private static func plist(named name: String, in resources: URL) -> Any? {
        let url = resources.appending(path: "\(name).plist")
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? PropertyListSerialization.propertyList(from: data, format: nil)
    }
}
