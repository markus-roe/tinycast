import Foundation

enum ProcessSearch {
    /// Listeners lead on a blank query so "what's on :3000" is visible without typing.
    static func rank(_ entries: [ProcessEntry], for raw: String) -> [ProcessEntry] {
        switch ProcessQuery.parse(raw) {
        case .empty:
            return Array(sorted(entries).prefix(ProcessPolicy.resultLimit))
        case .port(let port):
            return Array(
                entries.filter { entry in entry.ports.contains { $0.number == port } }
                    .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
                    .prefix(ProcessPolicy.resultLimit))
        case .text(let text):
            let folded = FuzzyMatch.Query(text)
            guard !folded.isEmpty else { return Array(sorted(entries).prefix(ProcessPolicy.resultLimit)) }
            return entries.enumerated()
                .compactMap { position, entry -> (ProcessEntry, Int, Int)? in
                    guard let quality = SearchRelevance.quality(folded, fields: entry.searchFields())
                    else { return nil }
                    return (entry, quality, position)
                }
                .sorted { $0.1 != $1.1 ? $0.1 > $1.1 : $0.2 < $1.2 }
                .prefix(ProcessPolicy.resultLimit)
                .map(\.0)
        }
    }

    private static func sorted(_ entries: [ProcessEntry]) -> [ProcessEntry] {
        entries.sorted { left, right in
            let leftListens = !left.ports.isEmpty
            let rightListens = !right.ports.isEmpty
            if leftListens != rightListens { return leftListens }
            let names = left.name.localizedCaseInsensitiveCompare(right.name)
            if names != .orderedSame { return names == .orderedAscending }
            return left.pid < right.pid
        }
    }
}
