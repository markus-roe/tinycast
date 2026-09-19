import Foundation

enum ProcessQuery: Equatable, Sendable {
    case empty
    /// `:3000` — only processes listening on that port.
    case port(Int)
    /// A name, a PID, or a bare number that may be either.
    case text(String)

    static func parse(_ raw: String) -> Self {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return .empty }
        if trimmed.hasPrefix(":"), let port = Int(trimmed.dropFirst()), Self.isPort(port) {
            return .port(port)
        }
        return .text(trimmed)
    }

    static func isPort(_ value: Int) -> Bool {
        (1...65_535).contains(value)
    }
}
