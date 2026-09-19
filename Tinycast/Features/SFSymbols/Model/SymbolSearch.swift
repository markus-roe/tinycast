import Foundation

/// Ranked fuzzy matches over a symbol's name and CoreGlyphs keywords.
enum SymbolSearch {
    /// Just under half a tier, so an equal-quality name match always wins.
    private static let keywordPenalty = 500
    static let frecencyLimit = 100
    private static let leadingWordScore = 95_000
    private static let nameWordsScore = 60_000
    private static let mixedWordsScore = 50_000

    static func matches(
        query: String, in entries: [SymbolEntry], frecency: [String: Int], limit: Int
    ) -> [SymbolEntry] {
        let trimmed = FuzzyMatch.normalized(query).trimmingCharacters(in: .whitespacesAndNewlines)
        let words = trimmed.split(whereSeparator: \.isWhitespace).map(String.init)
        let q = words.joined(separator: " ")
        guard !q.isEmpty, limit > 0 else { return [] }
        let folded = FuzzyMatch.Query(q)
        var scored: [(entry: SymbolEntry, score: Int, order: Int)] = []
        for (order, entry) in entries.enumerated() {
            guard let textScore = textScore(folded, terms: words.count > 1 ? words : [], entry: entry)
            else { continue }
            scored.append((entry, textScore + (frecency[entry.name] ?? 0), order))
        }
        return
            scored
            .sorted { $0.score != $1.score ? $0.score > $1.score : $0.order < $1.order }
            .prefix(limit)
            .map(\.entry)
    }

    private static func textScore(
        _ query: FuzzyMatch.Query, terms: [String], entry: SymbolEntry
    ) -> Int? {
        var nameOnly = true
        if !terms.isEmpty {
            let name = FuzzyMatch.normalized(entry.name)
            let keywords = FuzzyMatch.normalized(entry.keywords)
            for term in terms where !containsWordStart(term, in: name) {
                guard containsWordStart(term, in: keywords) else { return nil }
                nameOnly = false
            }
        }

        let nameMatch = FuzzyMatch.match(query, candidate: entry.name)
        if nameMatch?.tier == .exact { return nameMatch?.score }
        var best = nameMatch?.score
        if let nameMatch, nameMatch.tier == .prefix,
            let next = FuzzyMatch.normalized(entry.name).dropFirst(nameMatch.queryLength).first,
            !next.isLetter && !next.isNumber
        {
            best = leadingWordScore - nameMatch.candidateLength
        }
        if !terms.isEmpty {
            let ordered = nameMatch?.tier == .subsequence ? nameMatch?.score ?? 0 : 0
            best = max(best ?? Int.min, (nameOnly ? nameWordsScore : mixedWordsScore) + ordered)
        }
        guard !entry.keywords.isEmpty, FuzzyMatch.score(query, candidate: entry.keywords) != nil
        else { return best }
        for keyword in entry.keywords.split(separator: ",") {
            guard let match = FuzzyMatch.match(query, candidate: String(keyword)) else { continue }
            best = max(best ?? Int.min, min(match.score, leadingWordScore) - keywordPenalty)
            if match.tier == .exact { break }
        }
        return best
    }

    private static func containsWordStart(_ term: String, in candidate: String) -> Bool {
        var start = candidate.startIndex
        while let range = candidate.range(of: term, range: start..<candidate.endIndex) {
            if range.lowerBound == candidate.startIndex { return true }
            let previous = candidate[candidate.index(before: range.lowerBound)]
            if !previous.isLetter && !previous.isNumber { return true }
            start = candidate.index(after: range.lowerBound)
        }
        return false
    }
}
