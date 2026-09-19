import AppKit
import Darwin

enum ProcessRunner {
    enum Failure: Error {
        case refused
        case failed
    }

    static func terminate(pid: pid_t) throws {
        if let app = NSRunningApplication(processIdentifier: pid) {
            guard app.terminate() else { throw Failure.failed }
            return
        }
        guard kill(pid, SIGTERM) == 0 else { throw Failure.refused }
    }

    static func forceTerminate(pid: pid_t) throws {
        if let app = NSRunningApplication(processIdentifier: pid), app.forceTerminate() {
            return
        }
        guard kill(pid, SIGKILL) == 0 else { throw Failure.refused }
    }
}
