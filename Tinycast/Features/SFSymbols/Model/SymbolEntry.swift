import Foundation

/// One SF Symbol, named as `Image(systemName:)` takes it.
struct SymbolEntry: Identifiable, Hashable, Sendable {
    var id: String { name }
    let name: String
    /// Comma-joined search phrases from CoreGlyphs, same shape as emoji keywords.
    let keywords: String
    let categoryKeys: [String]
}

struct SFSymbolCategory: Hashable, Sendable, Identifiable {
    var id: String { key }
    let key: String
    let title: String
    let systemImage: String
}

/// Which section the picker shows; `.all` keeps the catalog's complete ordered overview.
enum SFSymbolCategoryFilter: Hashable, Sendable {
    case all
    case frequentlyUsed
    case category(SFSymbolCategory)

    var title: String {
        switch self {
        case .all: "All Categories"
        case .frequentlyUsed: "Frequently Used"
        case .category(let category): category.title
        }
    }

    var systemImage: String {
        switch self {
        case .all: "square.grid.3x3.square"
        case .frequentlyUsed: "clock"
        case .category(let category): category.systemImage
        }
    }
}

enum SymbolCopyFormat: String, Sendable {
    case name
    case swiftImage
    case swiftLabel

    func string(for name: String) -> String {
        switch self {
        case .name: return name
        case .swiftImage: return "Image(systemName: \"\(name)\")"
        case .swiftLabel: return "Label(\"\(Self.title(for: name))\", systemImage: \"\(name)\")"
        }
    }

    /// The last path component, title-cased, so a label is readable without the dots.
    private static func title(for name: String) -> String {
        name.split(separator: ".").map { $0.capitalized }.joined(separator: " ")
    }
}
