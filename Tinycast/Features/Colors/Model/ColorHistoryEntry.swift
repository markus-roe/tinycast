import Foundation

/// One picked or copied colour, stored as the sRGB components `ColorValue` already uses.
struct ColorHistoryEntry: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let red: Double
    let green: Double
    let blue: Double
    let alpha: Double
    let createdAt: Date

    var color: ColorValue {
        ColorValue(red: red, green: green, blue: blue, alpha: alpha)
    }

    init(id: UUID = UUID(), color: ColorValue, createdAt: Date) {
        self.id = id
        self.red = color.red
        self.green = color.green
        self.blue = color.blue
        self.alpha = color.alpha
        self.createdAt = createdAt
    }
}

/// Newest first, same colour bumped rather than stacked, capped so the file stays bounded.
enum ColorHistoryPolicy {
    static let cap = 200

    static func applying(
        _ color: ColorValue, to entries: [ColorHistoryEntry], id: UUID, now: Date
    ) -> [ColorHistoryEntry] {
        var next = entries.filter { $0.color != color }
        next.insert(ColorHistoryEntry(id: id, color: color, createdAt: now), at: 0)
        if next.count > cap { next.removeLast(next.count - cap) }
        return next
    }
}
