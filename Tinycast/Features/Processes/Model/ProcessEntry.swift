import Foundation

struct ProcessPort: Hashable, Sendable {
    enum Kind: String, Sendable {
        case tcp
        case udp
    }

    let number: Int
    let kind: Kind

    var display: String {
        kind == .tcp ? ":\(number)" : ":\(number)/udp"
    }
}

struct ProcessEntry: Identifiable, Hashable, Sendable {
    let pid: Int32
    let name: String
    let path: String
    let memoryBytes: UInt64
    let ports: [ProcessPort]
    /// False when the process belongs to another user, so Quit is offered but refused.
    let isOwned: Bool

    var id: String { String(pid) }

    var listeningPorts: [ProcessPort] { ports }

    /// The `.app` wrapper an executable lives inside, when the path is a bundle member.
    var appBundlePath: String? {
        guard let range = path.range(of: ".app") else { return nil }
        return String(path[..<range.upperBound])
    }

    var memoryDisplay: String { Self.memoryDisplay(memoryBytes) }

    /// Ports first so ":3000 · 42 MB" is what a listener row is for.
    var trailing: String {
        let memory = memoryDisplay
        if let first = ports.first {
            let extra = ports.count > 1 ? " +\(ports.count - 1)" : ""
            return "\(first.display)\(extra) · \(memory)"
        }
        return "\(pid) · \(memory)"
    }

    func searchFields() -> SearchFields {
        var fields: SearchFields = [
            .name(name),
            .technical(String(pid)),
        ]
        if !path.isEmpty { fields.append(.owner(path)) }
        for port in ports {
            fields.append(.technical(port.display))
            fields.append(.technical(String(port.number)))
        }
        return fields
    }

    static func memoryDisplay(_ bytes: UInt64) -> String {
        if bytes >= 1_073_741_824 {
            return String(format: "%.1f GB", Double(bytes) / 1_073_741_824)
        }
        if bytes >= 1_048_576 {
            return "\(bytes / 1_048_576) MB"
        }
        if bytes >= 1_024 {
            return "\(bytes / 1_024) KB"
        }
        return "\(bytes) B"
    }
}
