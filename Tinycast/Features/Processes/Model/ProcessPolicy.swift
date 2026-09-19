import Foundation

enum ProcessPolicy {
    static let resultLimit = 200

    static let protectedNames: Set<String> = [
        "kernel_task", "launchd", "WindowServer",
    ]

    static func isProtected(pid: Int32, name: String, selfPID: Int32) -> Bool {
        pid <= 1 || pid == selfPID || protectedNames.contains(name)
    }

    static func canSignal(_ entry: ProcessEntry, selfPID: Int32) -> Bool {
        entry.isOwned && !isProtected(pid: entry.pid, name: entry.name, selfPID: selfPID)
    }
}
