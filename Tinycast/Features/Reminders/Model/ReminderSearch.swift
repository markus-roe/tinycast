import Foundation

enum ReminderSearch {
    static func rank(
        _ entries: [ReminderEntry], for raw: String, now: Date
    ) -> (open: [ReminderEntry], completed: [ReminderEntry]) {
        let open = ReminderPolicy.open(in: entries, now: now)
        let done = ReminderPolicy.completed(in: entries)
        let folded = FuzzyMatch.Query(raw)
        guard !folded.isEmpty else { return (open, done) }
        return (matches(open, folded: folded), matches(done, folded: folded))
    }

    private static func matches(
        _ entries: [ReminderEntry], folded: FuzzyMatch.Query
    ) -> [ReminderEntry] {
        entries.enumerated()
            .compactMap { position, entry -> (ReminderEntry, Int, Int)? in
                guard let quality = SearchRelevance.quality(folded, fields: entry.searchFields())
                else { return nil }
                return (entry, quality, position)
            }
            .sorted { $0.1 != $1.1 ? $0.1 > $1.1 : $0.2 < $1.2 }
            .map(\.0)
    }
}
