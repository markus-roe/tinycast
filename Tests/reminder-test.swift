import Foundation

/// Query spelling, when-labels, due-first open order and completed ranking.
@main
@MainActor
struct ReminderTests {
    static var failures = 0

    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    static let now = calendar.date(
        from: DateComponents(year: 2026, month: 9, day: 19, hour: 15, minute: 0))!

    static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        if !condition() {
            failures += 1
            print("FAIL: \(message)")
        }
    }

    static func parse(_ raw: String) -> ReminderDraft? {
        ReminderQuery.parse(raw, now: now, calendar: calendar)
    }

    static func entry(
        title: String, dueAt: Date? = nil, completedAt: Date? = nil,
        listName: String = "Reminders", id: String = UUID().uuidString
    ) -> ReminderEntry {
        ReminderEntry(
            id: id, title: title, dueAt: dueAt, completedAt: completedAt, listName: listName)
    }

    static func main() {
        query()
        when()
        form()
        policy()
        ranking()
        print(failures == 0 ? "Reminder tests passed" : "\(failures) reminder tests failed")
        exit(failures == 0 ? 0 : 1)
    }

    static func query() {
        let tea = parse("in 25m Tee")
        expect(tea?.title == "Tee" && tea?.kind == .timer, "in 25m takes the rest as the title")
        expect(tea?.fireAt == now.addingTimeInterval(25 * 60), "in 25m is twenty-five minutes")

        let bare = parse("25m")
        expect(bare?.title == ReminderQuery.defaultTimerTitle, "a bare duration is a timer")
        expect(bare?.kind == .timer, "a duration without a clock is a timer")

        let words = parse("15 minutes tea")
        expect(
            words?.title == "tea" && words?.fireAt == now.addingTimeInterval(15 * 60),
            "a split amount and unit still parse")

        let clock = parse("14:30 call")
        expect(clock?.title == "call" && clock?.kind == .reminder, "HH:MM is a reminder")
        expect(
            clock?.fireAt
                == calendar.date(
                    byAdding: .day, value: 1,
                    to: calendar.date(bySettingHour: 14, minute: 30, second: 0, of: now)!)!,
            "a past clock rolls to tomorrow")

        let later = parse("at 16:00")
        expect(
            later?.title == ReminderQuery.defaultReminderTitle
                && later?.fireAt
                    == calendar.date(bySettingHour: 16, minute: 0, second: 0, of: now),
            "at HH:MM today stays today when it is still ahead")

        let tomorrow = parse("tomorrow milk")
        expect(tomorrow?.title == "milk" && tomorrow?.kind == .reminder, "tomorrow is a reminder")
        expect(
            tomorrow?.fireAt
                == calendar.date(
                    bySettingHour: 9, minute: 0, second: 0,
                    of: calendar.date(byAdding: .day, value: 1, to: now)!)!,
            "tomorrow without a clock is 9:00")

        expect(parse("  ") == nil, "whitespace is no reminder")
        expect(parse("hello") == nil, "prose without a when is left to an undated compose")
        expect(parse("200h") == nil, "longer than a week is refused")
        expect(parse("0m") == nil, "zero is not a duration")

        let lead = ReminderQuery.lead("in 2m test", now: now, calendar: calendar)
        expect(lead?.title == "test" && lead?.kind == .timer, "in 2m test leads the launcher")
        expect(
            ReminderQuery.lead("in 2m", now: now, calendar: calendar)?.title
                == ReminderQuery.defaultTimerTitle,
            "a when-word without a title still leads")
        expect(
            ReminderQuery.lead("25m tea", now: now, calendar: calendar)?.title == "tea",
            "a duration plus a title leads")
        expect(ReminderQuery.lead("25m", now: now, calendar: calendar) == nil, "a bare duration does not lead")
        expect(
            ReminderQuery.lead("14:30 call", now: now, calendar: calendar)?.title == "call",
            "a clock plus a title leads")
        expect(
            ReminderQuery.lead("14:30", now: now, calendar: calendar) == nil,
            "a bare clock does not lead")
        expect(ReminderQuery.lead("hello", now: now, calendar: calendar) == nil, "prose does not lead")
        expect(
            ReminderQuery.lead("tomorrow milk", now: now, calendar: calendar)?.title == "milk",
            "tomorrow plus a title leads")
    }

    static func when() {
        expect(
            ReminderWhen.remaining(until: now.addingTimeInterval(45), now: now) == "45s",
            "under a minute stays seconds")
        expect(
            ReminderWhen.remaining(until: now.addingTimeInterval(90), now: now) == "1m",
            "minutes drop the leftover seconds")
        expect(
            ReminderWhen.remaining(until: now.addingTimeInterval(3600), now: now) == "1h",
            "an exact hour has no leftover minutes")
        expect(
            ReminderWhen.remaining(until: now.addingTimeInterval(3660), now: now) == "1h 1m",
            "hours keep the leftover minutes")
        expect(
            ReminderWhen.remaining(until: now.addingTimeInterval(-1), now: now) == "Now",
            "a time already up is Now")

        let today = calendar.date(bySettingHour: 16, minute: 5, second: 0, of: now)!
        expect(
            ReminderWhen.clockLabel(today, now: now, calendar: calendar) == "16:05",
            "today is the clock only")
        let next = calendar.date(byAdding: .day, value: 1, to: today)!
        expect(
            ReminderWhen.clockLabel(next, now: now, calendar: calendar) == "Tomorrow 16:05",
            "the next day names tomorrow")
        let later = calendar.date(byAdding: .day, value: 2, to: today)!
        expect(
            ReminderWhen.clockLabel(later, now: now, calendar: calendar) == "9/21 16:05",
            "farther days are month/day")

        let due = entry(title: "Tea", dueAt: now.addingTimeInterval(-1))
        expect(due.whenLabel(at: now, calendar: calendar) == "Now", "an open due row says Now")
        let inbox = entry(title: "Milk", listName: "Groceries")
        expect(
            inbox.whenLabel(at: now, calendar: calendar) == "Groceries",
            "an undated row trails its list")
        var done = due
        done.completedAt = now
        expect(done.whenLabel(at: now, calendar: calendar) == "Done", "a completed row says Done")
    }

    static func form() {
        var empty = ReminderForm()
        expect(!empty.isValid(now: now, calendar: calendar), "an empty title cannot be added")
        empty.title = "  Tea  "
        expect(
            empty.isValid(now: now, calendar: calendar) && empty.trimmedTitle == "Tea",
            "the title is trimmed")
        let draft = empty.draft(now: now, calendar: calendar)
        expect(draft.kind == .reminder && draft.fireAt == nil, "the default when is no date")
        empty.when = .minutes(25)
        expect(
            empty.draft(now: now, calendar: calendar).fireAt == now.addingTimeInterval(25 * 60),
            "25 min is a timed reminder")
        empty.when = .tomorrow
        expect(
            empty.draft(now: now, calendar: calendar).kind == .reminder
                && empty.draft(now: now, calendar: calendar).fireAt
                    == ReminderForm.tomorrowMorning(now: now, calendar: calendar),
            "tomorrow is 9:00 the next day")
        let picked = now.addingTimeInterval(90 * 60)
        empty.when = .custom(picked)
        expect(
            empty.draft(now: now, calendar: calendar).fireAt == picked
                && empty.draft(now: now, calendar: calendar).kind == .reminder,
            "a picker date is an absolute reminder")
        expect(ReminderDraft.undated(title: "Milk").fireAt == nil, "prose compose is undated")
    }

    static func policy() {
        let due = entry(title: "Due", dueAt: now.addingTimeInterval(-10))
        let later = entry(title: "Later", dueAt: now.addingTimeInterval(120))
        let soon = entry(title: "Soon", dueAt: now.addingTimeInterval(30))
        let inbox = entry(title: "Milk")
        let ordered = ReminderPolicy.open(in: [later, inbox, due, soon], now: now)
        expect(
            ordered.map(\.title) == ["Due", "Soon", "Later", "Milk"],
            "due rows lead, then soonest due, undated last")

        var many: [ReminderEntry] = []
        for index in 0..<ReminderPolicy.cap + 5 {
            many.append(entry(title: "t\(index)", dueAt: now.addingTimeInterval(Double(index))))
        }
        expect(
            ReminderPolicy.open(in: many, now: now).count == ReminderPolicy.cap,
            "open listing is capped")

        var done: [ReminderEntry] = []
        for index in 0..<ReminderPolicy.completedLimit + 4 {
            done.append(
                entry(
                    title: "d\(index)", dueAt: now,
                    completedAt: now.addingTimeInterval(Double(index))))
        }
        let kept = ReminderPolicy.completed(in: done)
        expect(kept.count == ReminderPolicy.completedLimit, "completed keeps the newest twenty")
        expect(
            kept.first?.title == "d\(ReminderPolicy.completedLimit + 3)",
            "the most recently completed leads")
    }

    static func ranking() {
        let tea = entry(title: "Tea", dueAt: now.addingTimeInterval(60))
        let coffee = entry(title: "Coffee", dueAt: now.addingTimeInterval(90))
        let done = entry(
            title: "Tea later", dueAt: now, completedAt: now.addingTimeInterval(-10))
        let ranked = ReminderSearch.rank([tea, coffee, done], for: "tea", now: now)
        expect(ranked.open.map(\.title) == ["Tea"], "search keeps the matching open row")
        expect(
            ranked.completed.map(\.title) == ["Tea later"], "search keeps matching completed rows")
        let empty = ReminderSearch.rank([tea, coffee, done], for: "", now: now)
        expect(empty.open.count == 2 && empty.completed.count == 1, "a blank query lists everyone")
    }
}
