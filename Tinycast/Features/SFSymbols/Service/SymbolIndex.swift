import Foundation

/// The parsed catalog: sections precomputed at load, search memoized one query deep.
@MainActor
@Observable
final class SymbolIndex {
    private(set) var entries: [SymbolEntry] = []
    private(set) var categories: [SFSymbolCategory] = []
    private(set) var categorySections: [(category: SFSymbolCategory, entries: [SymbolEntry])] = []

    private struct SearchKey: Equatable {
        let query: String
        let revision: Int
        let frequentID: ObjectIdentifier
        let frequentRevision: Int
        let limit: Int
    }

    private var byName: [String: SymbolEntry] = [:]
    @ObservationIgnored private var searchMemo = Memo<SearchKey, [SymbolEntry]>()
    private var revision = 0

    var isLoaded: Bool { !entries.isEmpty }

    var filters: [SFSymbolCategoryFilter] {
        [.all, .frequentlyUsed] + categories.map(SFSymbolCategoryFilter.category)
    }

    func load() async {
        let loaded = await Task.detached(priority: .utility) { SymbolCatalogLoader.load() }.value
        entries = loaded.entries
        categories = loaded.categories
        var grouped: [String: [SymbolEntry]] = [:]
        for entry in loaded.entries {
            if let key = entry.categoryKeys.first { grouped[key, default: []].append(entry) }
        }
        categorySections = loaded.categories.compactMap { category in
            grouped[category.key].map { (category, $0) }
        }
        byName = Dictionary(
            loaded.entries.map { ($0.name, $0) }, uniquingKeysWith: { first, _ in first })
        revision &+= 1
    }

    func entry(named name: String) -> SymbolEntry? { byName[name] }

    func search(_ query: String, frequent: FrequentSymbolStore, limit: Int = 320) -> [SymbolEntry] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, limit > 0 else { return [] }
        let key = SearchKey(
            query: trimmed, revision: revision, frequentID: ObjectIdentifier(frequent),
            frequentRevision: frequent.revision, limit: limit)
        return searchMemo.value(for: key) {
            let top = frequent.top(SymbolSearch.frecencyLimit)
            let frecency = Dictionary(
                top.enumerated().map { ($0.element, SymbolSearch.frecencyLimit - $0.offset) },
                uniquingKeysWith: max)
            return SymbolSearch.matches(
                query: trimmed, in: entries, frecency: frecency, limit: limit)
        }
    }
}
