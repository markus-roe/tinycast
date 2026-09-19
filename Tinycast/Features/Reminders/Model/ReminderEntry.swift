import Foundation

struct ReminderEntry: Identifiable, Hashable, Sendable {
    /// `EKReminder.calendarItemIdentifier` — the only handle EventKit will take back.
    let id: String
    var title: String
    var dueAt: Date?
    var completedAt: Date?
    var listName: String

    var isCompleted: Bool { completedAt != nil }

    func isDue(at now: Date) -> Bool {
        guard let dueAt, !isCompleted else { return false }
        return dueAt <= now
    }

    func searchFields() -> SearchFields {
        var fields: SearchFields = [.name(title)]
        if !listName.isEmpty { fields.append(.owner(listName)) }
        return fields
    }

    func whenLabel(at now: Date, calendar: Calendar) -> String {
        if isCompleted { return "Done" }
        guard let dueAt else { return listName }
        if dueAt <= now { return "Now" }
        let horizon: TimeInterval = 12 * 60 * 60
        if dueAt.timeIntervalSince(now) < horizon {
            return ReminderWhen.remaining(until: dueAt, now: now)
        }
        return ReminderWhen.clockLabel(dueAt, now: now, calendar: calendar)
    }

    func symbol(at now: Date) -> String {
        guard let dueAt, !isCompleted, dueAt.timeIntervalSince(now) < 12 * 60 * 60 else {
            return "bell"
        }
        return "timer"
    }
}

enum ReminderWhen {
    static func remaining(until fireAt: Date, now: Date) -> String {
        let seconds = Int(fireAt.timeIntervalSince(now).rounded())
        if seconds <= 0 { return "Now" }
        if seconds < 60 { return "\(seconds)s" }
        if seconds < 3600 { return "\(seconds / 60)m" }
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        return minutes == 0 ? "\(hours)h" : "\(hours)h \(minutes)m"
    }

    static func clockLabel(_ date: Date, now: Date, calendar: Calendar) -> String {
        let time = timeLabel(date, calendar: calendar)
        if calendar.isDate(date, inSameDayAs: now) { return time }
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: now),
            calendar.isDate(date, inSameDayAs: tomorrow)
        {
            return "Tomorrow \(time)"
        }
        let month = calendar.component(.month, from: date)
        let day = calendar.component(.day, from: date)
        return "\(month)/\(day) \(time)"
    }

    static func timeLabel(_ date: Date, calendar: Calendar) -> String {
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        return String(format: "%d:%02d", hour, minute)
    }
}
