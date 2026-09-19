import Darwin
import Foundation

enum ProcessEnumerator {
    /// Every readable process plus its listening sockets. Injected IDs keep this off the main actor.
    nonisolated static func list(selfPID: pid_t, userID: uid_t) -> [ProcessEntry] {
        let pids = listPIDs()
        var entries: [ProcessEntry] = []
        entries.reserveCapacity(pids.count)
        for pid in pids {
            if pid <= 0 { continue }
            guard let identity = identity(of: pid) else { continue }
            let path = path(of: pid)
            let memory = memory(of: pid)
            let ports = sockets(of: pid)
            entries.append(
                ProcessEntry(
                    pid: pid, name: identity.name, path: path, memoryBytes: memory,
                    ports: ports, isOwned: identity.uid == userID || pid == selfPID))
        }
        return entries
    }

    private nonisolated static func listPIDs() -> [pid_t] {
        let bytes = proc_listpids(UInt32(PROC_ALL_PIDS), 0, nil, 0)
        guard bytes > 0 else { return [] }
        var pids = [pid_t](repeating: 0, count: Int(bytes) / MemoryLayout<pid_t>.stride)
        let filled = pids.withUnsafeMutableBufferPointer { buffer in
            proc_listpids(
                UInt32(PROC_ALL_PIDS), 0, buffer.baseAddress, Int32(buffer.count * MemoryLayout<pid_t>.stride))
        }
        guard filled > 0 else { return [] }
        let count = Int(filled) / MemoryLayout<pid_t>.stride
        return Array(pids.prefix(count))
    }

    private nonisolated static func identity(of pid: pid_t) -> (name: String, uid: uid_t)? {
        var info = proc_bsdinfo()
        let size = Int32(MemoryLayout<proc_bsdinfo>.size)
        guard proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, size) == size else { return nil }
        let name = cString(from: info.pbi_name)
        let fallback = cString(from: info.pbi_comm)
        let resolved = name.isEmpty ? fallback : name
        guard !resolved.isEmpty else { return nil }
        return (resolved, info.pbi_uid)
    }

    private nonisolated static func path(of pid: pid_t) -> String {
        var buffer = [CChar](repeating: 0, count: 4 * Int(MAXPATHLEN))
        let length = proc_pidpath(pid, &buffer, UInt32(buffer.count))
        guard length > 0 else { return "" }
        return decode(buffer.prefix(Int(length)))
    }

    private nonisolated static func cString<T>(from tuple: T) -> String {
        withUnsafeBytes(of: tuple) { raw in
            decode(raw.bindMemory(to: CChar.self))
        }
    }

    private nonisolated static func decode<S: Sequence>(_ bytes: S) -> String where S.Element == CChar {
        let chars = Array(bytes.prefix { $0 != 0 })
        return String(decoding: chars.map { UInt8(bitPattern: $0) }, as: UTF8.self)
    }

    private nonisolated static func memory(of pid: pid_t) -> UInt64 {
        var info = proc_taskinfo()
        let size = Int32(MemoryLayout<proc_taskinfo>.size)
        guard proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &info, size) == size else { return 0 }
        return info.pti_resident_size
    }

    private nonisolated static func sockets(of pid: pid_t) -> [ProcessPort] {
        let listSize = proc_pidinfo(pid, PROC_PIDLISTFDS, 0, nil, 0)
        guard listSize > 0 else { return [] }
        let count = Int(listSize) / MemoryLayout<proc_fdinfo>.stride
        var fds = [proc_fdinfo](repeating: proc_fdinfo(), count: count)
        let filled = fds.withUnsafeMutableBufferPointer { buffer in
            proc_pidinfo(
                pid, PROC_PIDLISTFDS, 0, buffer.baseAddress,
                Int32(buffer.count * MemoryLayout<proc_fdinfo>.stride))
        }
        guard filled > 0 else { return [] }
        let live = Int(filled) / MemoryLayout<proc_fdinfo>.stride
        var seen: Set<ProcessPort> = []
        for index in 0..<live {
            let fd = fds[index]
            guard fd.proc_fdtype == UInt32(PROX_FDTYPE_SOCKET) else { continue }
            var socket = socket_fdinfo()
            let size = Int32(MemoryLayout<socket_fdinfo>.size)
            guard proc_pidfdinfo(pid, fd.proc_fd, PROC_PIDFDSOCKETINFO, &socket, size) == size
            else { continue }
            if let port = listeningPort(in: socket) { seen.insert(port) }
        }
        return seen.sorted { left, right in
            left.number != right.number
                ? left.number < right.number : left.kind.rawValue < right.kind.rawValue
        }
    }

    private nonisolated static func listeningPort(in socket: socket_fdinfo) -> ProcessPort? {
        let kind = socket.psi.soi_kind
        if kind == SOCKINFO_TCP {
            let tcp = socket.psi.soi_proto.pri_tcp
            guard tcp.tcpsi_state == TSI_S_LISTEN else { return nil }
            let port = Int(UInt16(bigEndian: UInt16(truncatingIfNeeded: tcp.tcpsi_ini.insi_lport)))
            guard ProcessQuery.isPort(port) else { return nil }
            return ProcessPort(number: port, kind: .tcp)
        }
        if kind == SOCKINFO_IN {
            let port = Int(
                UInt16(bigEndian: UInt16(truncatingIfNeeded: socket.psi.soi_proto.pri_in.insi_lport)))
            guard ProcessQuery.isPort(port) else { return nil }
            return ProcessPort(number: port, kind: .udp)
        }
        return nil
    }
}
