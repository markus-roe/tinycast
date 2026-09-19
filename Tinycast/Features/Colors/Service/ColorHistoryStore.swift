import Foundation

/// Picked and converted colours as a capped JSON file beside calculator history.
@MainActor
@Observable
final class ColorHistoryStore {
    private let fileURL: URL
    private let now: () -> Date
    private let makeID: () -> UUID

    private(set) var entries: [ColorHistoryEntry]

    private struct SearchKey: Equatable {
        let query: String
        let revision: Int
    }

    @ObservationIgnored private var searchMemo = Memo<SearchKey, [ColorHistoryEntry]>()
    private var revision = 0

    init(
        fileURL: URL = AppPaths.applicationSupport().appendingPathComponent("color-history.json"),
        now: @escaping () -> Date = Date.init,
        makeID: @escaping () -> UUID = UUID.init
    ) {
        self.fileURL = fileURL
        self.now = now
        self.makeID = makeID
        if let data = try? Data(contentsOf: fileURL),
            let decoded = try? JSONDecoder().decode([ColorHistoryEntry].self, from: data)
        {
            entries = decoded
        } else {
            entries = []
        }
    }

    func record(_ color: ColorValue) {
        entries = ColorHistoryPolicy.applying(color, to: entries, id: makeID(), now: now())
        persist()
    }

    func remove(_ entry: ColorHistoryEntry) {
        entries.removeAll { $0.id == entry.id }
        persist()
    }

    func clearAll() {
        entries = []
        persist()
    }

    /// Case-insensitive match over every notation the colour copies as.
    func search(_ query: String) -> [ColorHistoryEntry] {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return entries }
        return searchMemo.value(for: SearchKey(query: q, revision: revision)) {
            entries.filter { entry in
                ColorFormat.offered(for: entry.color).contains {
                    $0.string(for: entry.color).localizedCaseInsensitiveContains(q)
                }
            }
        }
    }

    private func persist() {
        revision &+= 1
        if let data = try? JSONEncoder().encode(entries) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }
}
