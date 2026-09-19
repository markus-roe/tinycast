import Foundation

enum ReminderKind: Sendable, Equatable {
    case timer
    case reminder
}

struct ReminderDraft: Equatable, Sendable {
    let title: String
    let fireAt: Date?
    let kind: ReminderKind

    func summary(now: Date, calendar: Calendar) -> String {
        guard fireAt != nil else { return "Add “\(title)” to Reminders" }
        switch kind {
        case .timer:
            return "\(title) in \(whenCaption(now: now, calendar: calendar))"
        case .reminder:
            return "\(title) · \(whenCaption(now: now, calendar: calendar))"
        }
    }

    func whenCaption(now: Date, calendar: Calendar) -> String {
        guard let fireAt else { return "" }
        switch kind {
        case .timer:
            return ReminderWhen.remaining(until: fireAt, now: now)
        case .reminder:
            return ReminderWhen.clockLabel(fireAt, now: now, calendar: calendar)
        }
    }

    static func relative(title: String, seconds: TimeInterval, now: Date) -> Self {
        ReminderDraft(
            title: title, fireAt: now.addingTimeInterval(seconds), kind: .timer)
    }

    static func absolute(title: String, fireAt: Date) -> Self {
        ReminderDraft(title: title, fireAt: fireAt, kind: .reminder)
    }

    static func undated(title: String) -> Self {
        ReminderDraft(title: title, fireAt: nil, kind: .reminder)
    }
}

enum ReminderFormWhen: Equatable, Sendable {
    case none
    case minutes(Int)
    case tomorrow
    case custom(Date)
}

struct ReminderForm: Equatable, Sendable {
    struct Shortcut: Equatable, Sendable {
        let label: String
        let when: ReminderFormWhen
    }

    static let shortcuts: [Shortcut] = [
        Shortcut(label: "No date", when: .none),
        Shortcut(label: "25 min", when: .minutes(25)),
        Shortcut(label: "1 hr", when: .minutes(60)),
        Shortcut(label: "Tomorrow", when: .tomorrow),
    ]

    var title: String = ""
    var when: ReminderFormWhen = .none

    var trimmedTitle: String { title.trimmingCharacters(in: .whitespacesAndNewlines) }

    func isValid(now _: Date, calendar _: Calendar) -> Bool {
        !trimmedTitle.isEmpty
    }

    func fireAt(now: Date, calendar: Calendar) -> Date? {
        switch when {
        case .none: return nil
        case .minutes(let minutes):
            return now.addingTimeInterval(TimeInterval(minutes * 60))
        case .tomorrow:
            return Self.tomorrowMorning(now: now, calendar: calendar)
        case .custom(let date):
            return date
        }
    }

    func draft(now: Date, calendar: Calendar) -> ReminderDraft {
        switch when {
        case .none:
            return .undated(title: trimmedTitle)
        case .minutes(let minutes):
            return .relative(
                title: trimmedTitle, seconds: TimeInterval(minutes * 60), now: now)
        case .tomorrow:
            return .absolute(
                title: trimmedTitle, fireAt: Self.tomorrowMorning(now: now, calendar: calendar))
        case .custom(let date):
            return .absolute(title: trimmedTitle, fireAt: date)
        }
    }

    static func tomorrowMorning(now: Date, calendar: Calendar) -> Date {
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) ?? now
        return calendar.date(bySettingHour: 9, minute: 0, second: 0, of: tomorrow) ?? tomorrow
    }
}
