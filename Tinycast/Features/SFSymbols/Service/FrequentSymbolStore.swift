import Foundation

struct FrequentSymbol: Codable, Hashable, Sendable {
    let name: String
    var count: Int
    var lastUsed: Date
}

/// Usage counts as a capped JSON file, feeding the grid's "Frequently Used".
@MainActor
@Observable
final class FrequentSymbolStore {
    private static let cap = 300

    private let fileURL: URL
    private(set) var records: [FrequentSymbol]
    @ObservationIgnored private var sortedMemo = Memo<Int, [String]>()
    private(set) var revision = 0

    init(
        fileURL: URL = AppPaths.applicationSupport().appendingPathComponent(
            "sf-symbol-frequency.json")
    ) {
        self.fileURL = fileURL
        if let data = try? Data(contentsOf: fileURL),
            let decoded = try? JSONDecoder().decode([FrequentSymbol].self, from: data)
        {
            records = decoded
        } else {
            records = []
        }
    }

    func record(_ name: String) {
        revision &+= 1
        if let index = records.firstIndex(where: { $0.name == name }) {
            records[index].count += 1
            records[index].lastUsed = Date()
        } else {
            records.append(FrequentSymbol(name: name, count: 1, lastUsed: Date()))
        }
        if records.count > Self.cap {
            records.sort { $0.count != $1.count ? $0.count > $1.count : $0.lastUsed > $1.lastUsed }
            records.removeLast(records.count - Self.cap)
        }
        persist()
    }

    func top(_ n: Int = 16) -> [String] {
        let sorted = sortedMemo.value(for: revision) {
            records
                .sorted { $0.count != $1.count ? $0.count > $1.count : $0.lastUsed > $1.lastUsed }
                .map(\.name)
        }
        return Array(sorted.prefix(n))
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(records) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }
}
