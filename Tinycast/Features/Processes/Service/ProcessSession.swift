import Darwin
import Foundation

@MainActor
@Observable
final class ProcessSession {
    private(set) var snapshot: [ProcessEntry] = []
    private(set) var filtered: [ProcessEntry] = []
    private(set) var isLoading = false

    private var query = ""
    private var generation = 0

    func refresh() async {
        generation += 1
        let token = generation
        if snapshot.isEmpty { isLoading = true }
        let selfPID = ProcessInfo.processInfo.processIdentifier
        let userID = getuid()
        let listed = await Task.detached(priority: .userInitiated) {
            ProcessEnumerator.list(selfPID: selfPID, userID: userID)
        }.value
        guard token == generation else { return }
        snapshot = listed
        isLoading = false
        applyQuery()
    }

    func filter(_ query: String) {
        self.query = query
        applyQuery()
    }

    func remove(pid: Int32) {
        snapshot.removeAll { $0.pid == pid }
        applyQuery()
    }

    func reset() {
        generation += 1
        snapshot = []
        filtered = []
        isLoading = false
        query = ""
    }

    private func applyQuery() {
        filtered = ProcessSearch.rank(
            snapshot, for: query.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}
