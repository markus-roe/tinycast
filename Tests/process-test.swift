import Foundation

@main
@MainActor
struct ProcessTests {
    static var failures = 0

    static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        if !condition() {
            failures += 1
            print("FAIL: \(message)")
        }
    }

    static func entry(
        pid: Int32, name: String, path: String = "", memory: UInt64 = 0,
        ports: [ProcessPort] = [], owned: Bool = true
    ) -> ProcessEntry {
        ProcessEntry(
            pid: pid, name: name, path: path, memoryBytes: memory, ports: ports, isOwned: owned)
    }

    static func main() {
        identity()
        display()
        query()
        policy()
        ranking()
        print(failures == 0 ? "Process tests passed" : "\(failures) process tests failed")
        exit(failures == 0 ? 0 : 1)
    }

    static func identity() {
        expect(entry(pid: 42, name: "node").id == "42", "the id is the pid")
        expect(
            entry(pid: 1, name: "Cursor", path: "/Applications/Cursor.app/Contents/MacOS/Cursor")
                .appBundlePath == "/Applications/Cursor.app",
            "an executable inside a bundle resolves to the .app")
        expect(
            entry(pid: 1, name: "node", path: "/usr/local/bin/node").appBundlePath == nil,
            "a bare binary has no app bundle")
    }

    static func display() {
        expect(ProcessEntry.memoryDisplay(512) == "512 B", "bytes stay bytes")
        expect(ProcessEntry.memoryDisplay(2_048) == "2 KB", "kilobytes are whole")
        expect(ProcessEntry.memoryDisplay(5_242_880) == "5 MB", "megabytes are whole")
        expect(
            entry(pid: 9, name: "node", memory: 1_048_576).trailing == "9 · 1 MB",
            "a process without ports trails its pid and memory")
        expect(
            entry(
                pid: 9, name: "node", memory: 1_048_576,
                ports: [ProcessPort(number: 3000, kind: .tcp)]
            ).trailing == ":3000 · 1 MB",
            "a listener leads with its port")
        expect(
            entry(
                pid: 9, name: "node", memory: 1_048_576,
                ports: [
                    ProcessPort(number: 3000, kind: .tcp),
                    ProcessPort(number: 9229, kind: .tcp),
                ]
            ).trailing == ":3000 +1 · 1 MB",
            "extra ports are counted, not listed")
    }

    static func query() {
        expect(ProcessQuery.parse("  ") == .empty, "whitespace is no query")
        expect(ProcessQuery.parse(":3000") == .port(3000), "a leading colon is a port")
        expect(ProcessQuery.parse(":0") == .text(":0"), "port 0 is not a port")
        expect(ProcessQuery.parse("3000") == .text("3000"), "a bare number stays text so PID matches")
        expect(ProcessQuery.parse("node") == .text("node"), "a name is text")
        expect(ProcessQuery.isPort(1) && ProcessQuery.isPort(65_535), "the port range is inclusive")
        expect(!ProcessQuery.isPort(0) && !ProcessQuery.isPort(65_536), "outside the range is refused")
    }

    static func policy() {
        expect(ProcessPolicy.isProtected(pid: 0, name: "x", selfPID: 9), "pid 0 cannot be signalled")
        expect(ProcessPolicy.isProtected(pid: 1, name: "x", selfPID: 9), "pid 1 cannot be signalled")
        expect(
            ProcessPolicy.isProtected(pid: 9, name: "Tinycast", selfPID: 9),
            "Tinycast cannot quit itself")
        expect(
            ProcessPolicy.isProtected(pid: 12, name: "kernel_task", selfPID: 9),
            "kernel_task is protected by name")
        expect(
            !ProcessPolicy.isProtected(pid: 12, name: "node", selfPID: 9),
            "an ordinary process is not protected")
        let owned = entry(pid: 12, name: "node", owned: true)
        let foreign = entry(pid: 12, name: "node", owned: false)
        expect(ProcessPolicy.canSignal(owned, selfPID: 9), "an owned process can be signalled")
        expect(!ProcessPolicy.canSignal(foreign, selfPID: 9), "another user's process cannot")
    }

    static func ranking() {
        let node = entry(
            pid: 10, name: "node", ports: [ProcessPort(number: 3000, kind: .tcp)])
        let helper = entry(pid: 11, name: "node-helper")
        let nginx = entry(
            pid: 12, name: "nginx", ports: [ProcessPort(number: 8080, kind: .tcp)])
        let all = [helper, nginx, node]

        expect(
            ProcessSearch.rank(all, for: "").map(\.pid) == [nginx.pid, node.pid, helper.pid],
            "a blank query puts listeners first, then name: \(ProcessSearch.rank(all, for: "").map(\.pid))"
        )
        expect(
            ProcessSearch.rank(all, for: ":3000").map(\.pid) == [node.pid],
            "a port query returns only that listener")
        expect(
            ProcessSearch.rank(all, for: "node").map(\.name).contains("node"),
            "a name query matches the process name")
        expect(
            ProcessSearch.rank([node], for: "10").map(\.pid) == [node.pid],
            "a bare number matches the PID")

        let many = (0..<ProcessPolicy.resultLimit + 20).map {
            entry(pid: Int32($0 + 100), name: "worker-\($0)")
        }
        expect(
            ProcessSearch.rank(many, for: "").count == ProcessPolicy.resultLimit,
            "the blank list is capped")
    }
}
