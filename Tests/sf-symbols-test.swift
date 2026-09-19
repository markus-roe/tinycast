import Foundation

/// Symbol search ranking and copy spellings, compiling the shipped Model sources.
@main
@MainActor
struct SFSymbolsTests {
    static var failures = 0

    static func expect(_ condition: Bool, _ label: String) {
        if !condition {
            print("FAIL: \(label)")
            failures += 1
        }
    }

    static func main() {
        let heart = SymbolEntry(name: "heart.fill", keywords: "love,like", categoryKeys: ["health"])
        let star = SymbolEntry(name: "star", keywords: "favorite", categoryKeys: ["nature"])
        let heartCircle = SymbolEntry(
            name: "heart.circle", keywords: "love", categoryKeys: ["health"])
        let entries = [star, heart, heartCircle]

        let byName = SymbolSearch.matches(
            query: "heart.fill", in: entries, frecency: [:], limit: 10)
        expect(byName.first?.name == "heart.fill", "an exact name leads")

        let byWord = SymbolSearch.matches(query: "heart", in: entries, frecency: [:], limit: 10)
        expect(
            byWord.map(\.name) == ["heart.circle", "heart.fill"]
                || byWord.map(\.name) == ["heart.fill", "heart.circle"],
            "a leading name word matches dotted symbols: \(byWord.map(\.name))")
        expect(!byWord.contains(where: { $0.name == "star" }), "heart does not match star")

        let byKeyword = SymbolSearch.matches(query: "love", in: entries, frecency: [:], limit: 10)
        expect(
            Set(byKeyword.map(\.name)) == ["heart.fill", "heart.circle"],
            "a keyword matches without the name")

        let boosted = SymbolSearch.matches(
            query: "heart", in: entries, frecency: ["heart.fill": 100], limit: 10)
        expect(boosted.first?.name == "heart.fill", "usage breaks a name-word tie")

        expect(SymbolCopyFormat.name.string(for: "heart.fill") == "heart.fill", "name is bare")
        expect(
            SymbolCopyFormat.swiftImage.string(for: "heart.fill")
                == "Image(systemName: \"heart.fill\")",
            "Swift Image uses the systemName initialiser")
        expect(
            SymbolCopyFormat.swiftLabel.string(for: "heart.fill")
                == "Label(\"Heart Fill\", systemImage: \"heart.fill\")",
            "Swift Label title-cases the path")

        let filters: [SFSymbolCategoryFilter] = [
            .all, .frequentlyUsed,
            .category(SFSymbolCategory(key: "health", title: "Health", systemImage: "heart")),
        ]
        expect(filters.first?.title == "All Categories", "All Categories is the default row")
        expect(filters[1].systemImage == "clock", "Frequently Used uses the same clock as emoji")

        print(failures == 0 ? "ok" : "\(failures) failed")
        if failures > 0 { exit(1) }
    }
}
