import Foundation

enum ReminderQuery {
    static let maxRelative = 7 * 24 * 60 * 60
    static let defaultTimerTitle = "Timer"
    static let defaultReminderTitle = "Reminder"

    static func parse(_ raw: String, now: Date, calendar: Calendar) -> ReminderDraft? {
        var tokens = raw.split(whereSeparator: \.isWhitespace).map(String.init)
        guard !tokens.isEmpty else { return nil }

        if matches(tokens[0], "in") {
            tokens.removeFirst()
            guard let seconds = consumeDuration(&tokens) else { return nil }
            return ReminderDraft.relative(
                title: title(from: tokens, fallback: defaultTimerTitle), seconds: seconds, now: now)
        }
        if matches(tokens[0], "tomorrow") {
            tokens.removeFirst()
            let clock = consumeClock(&tokens)
            return ReminderDraft.absolute(
                title: title(from: tokens, fallback: defaultReminderTitle),
                fireAt: day(offset: 1, clock: clock, now: now, calendar: calendar))
        }
        if matches(tokens[0], "at") {
            tokens.removeFirst()
            guard let clock = consumeClock(&tokens) else { return nil }
            return ReminderDraft.absolute(
                title: title(from: tokens, fallback: defaultReminderTitle),
                fireAt: nextOccurrence(of: clock, now: now, calendar: calendar))
        }
        if let seconds = consumeDuration(&tokens) {
            return ReminderDraft.relative(
                title: title(from: tokens, fallback: defaultTimerTitle), seconds: seconds, now: now)
        }
        if let clock = consumeClock(&tokens) {
            return ReminderDraft.absolute(
                title: title(from: tokens, fallback: defaultReminderTitle),
                fireAt: nextOccurrence(of: clock, now: now, calendar: calendar))
        }
        return nil
    }

    /// Root search only leads on a when, so `milk` never steals the first row from apps.
    static func lead(_ raw: String, now: Date, calendar: Calendar) -> ReminderDraft? {
        guard let draft = parse(raw, now: now, calendar: calendar), draft.fireAt != nil else {
            return nil
        }
        var tokens = raw.split(whereSeparator: \.isWhitespace).map(String.init)
        guard let first = tokens.first else { return nil }
        if matches(first, "in") || matches(first, "tomorrow") || matches(first, "at") {
            return draft
        }
        if consumeDuration(&tokens) != nil || consumeClock(&tokens) != nil {
            return title(from: tokens, fallback: "").isEmpty ? nil : draft
        }
        return nil
    }

    private static func consumeDuration(_ tokens: inout [String]) -> TimeInterval? {
        guard let first = tokens.first else { return nil }
        if let seconds = duration(from: first) {
            tokens.removeFirst()
            return seconds
        }
        guard tokens.count >= 2, let amount = Int(first), amount > 0,
            let unit = unitSeconds(tokens[1])
        else { return nil }
        tokens.removeFirst(2)
        return clamp(TimeInterval(amount) * unit)
    }

    private static func duration(from token: String) -> TimeInterval? {
        let folded = token.lowercased()
        let digits = folded.prefix(while: \.isNumber)
        guard let amount = Int(digits), amount > 0, digits.count < folded.count else { return nil }
        let unit = String(folded.dropFirst(digits.count))
        guard let seconds = unitSeconds(unit) else { return nil }
        return clamp(TimeInterval(amount) * seconds)
    }

    private static func unitSeconds(_ raw: String) -> TimeInterval? {
        switch raw.lowercased() {
        case "s", "sec", "secs", "second", "seconds": return 1
        case "m", "min", "mins", "minute", "minutes": return 60
        case "h", "hr", "hrs", "hour", "hours": return 3600
        default: return nil
        }
    }

    private static func consumeClock(_ tokens: inout [String]) -> (hour: Int, minute: Int)? {
        guard let first = tokens.first, let clock = clock(from: first) else { return nil }
        tokens.removeFirst()
        return clock
    }

    private static func clock(from token: String) -> (hour: Int, minute: Int)? {
        let parts = token.split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count == 2, let hour = Int(parts[0]), let minute = Int(parts[1]),
            (0...23).contains(hour), (0...59).contains(minute)
        else { return nil }
        return (hour, minute)
    }

    private static func nextOccurrence(
        of clock: (hour: Int, minute: Int), now: Date, calendar: Calendar
    ) -> Date {
        let today = calendar.date(bySettingHour: clock.hour, minute: clock.minute, second: 0, of: now)
        if let today, today > now.addingTimeInterval(-30) { return today }
        return day(offset: 1, clock: clock, now: now, calendar: calendar)
    }

    private static func day(
        offset: Int, clock: (hour: Int, minute: Int)?, now: Date, calendar: Calendar
    ) -> Date {
        let base = calendar.date(byAdding: .day, value: offset, to: now) ?? now
        let hour = clock?.hour ?? 9
        let minute = clock?.minute ?? 0
        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: base) ?? base
    }

    private static func title(from tokens: [String], fallback: String) -> String {
        let joined = tokens.joined(separator: " ").trimmingCharacters(in: .whitespaces)
        return joined.isEmpty ? fallback : joined
    }

    private static func clamp(_ seconds: TimeInterval) -> TimeInterval? {
        guard seconds >= 1, seconds <= TimeInterval(maxRelative) else { return nil }
        return seconds
    }

    private static func matches(_ token: String, _ word: String) -> Bool {
        token.localizedCaseInsensitiveCompare(word) == .orderedSame
    }
}
