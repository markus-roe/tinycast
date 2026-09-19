import Foundation

enum ReminderPolicy {
    static let cap = 200
    static let completedLimit = 20

    static func open(in entries: [ReminderEntry], now: Date) -> [ReminderEntry] {
        Array(
            entries.filter { !$0.isCompleted }
                .sorted { left, right in
                    let leftDue = left.isDue(at: now)
                    let rightDue = right.isDue(at: now)
                    if leftDue != rightDue { return leftDue }
                    let leftDate = left.dueAt ?? .distantFuture
                    let rightDate = right.dueAt ?? .distantFuture
                    if leftDate != rightDate { return leftDate < rightDate }
                    return left.title.localizedCaseInsensitiveCompare(right.title)
                        == .orderedAscending
                }
                .prefix(cap))
    }

    static func completed(in entries: [ReminderEntry]) -> [ReminderEntry] {
        Array(
            entries.filter(\.isCompleted)
                .sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
                .prefix(completedLimit))
    }

    static func due(in entries: [ReminderEntry], now: Date) -> [ReminderEntry] {
        entries.filter { $0.isDue(at: now) }.sorted {
            ($0.dueAt ?? .distantFuture) < ($1.dueAt ?? .distantFuture)
        }
    }
}
