import AppKit
import EventKit

/// Incomplete and recently completed reminders, read from EventKit. See docs/features/reminders.md.
@MainActor
@Observable
final class ReminderStore {
    private(set) var entries: [ReminderEntry] = []
    private(set) var access: CalendarAccess = Permissions.remindersAccess()

    /// Built on first use, so a Mac with the feature off never loads EventKit at launch.
    @ObservationIgnored private var eventStore: EKEventStore?
    @ObservationIgnored private var changeObserver: NotificationToken?
    @ObservationIgnored private var wakeObserver: NotificationToken?
    /// One in-flight fetch: EventKit's search queue cannot overlap another query on the same store.
    @ObservationIgnored private var reloadTask: Task<Void, Never>?

    func refreshAccess() {
        access = Permissions.remindersAccess()
    }

    func start() {
        refreshAccess()
        guard access == .granted else { return }
        observeWake()
        Task { await reload() }
    }

    func stop() {
        reloadTask?.cancel()
        reloadTask = nil
        changeObserver = nil
        wakeObserver = nil
        eventStore = nil
        entries = []
    }

    func requestAccess() async -> Bool {
        let granted = await Permissions.requestRemindersAccess()
        refreshAccess()
        guard granted else { return false }
        // A store built before the grant never sees the new lists; drop it and rebuild.
        changeObserver = nil
        eventStore = nil
        return true
    }

    func search(_ query: String) -> (open: [ReminderEntry], completed: [ReminderEntry]) {
        ReminderSearch.rank(entries, for: query, now: Date())
    }

    func reload() async {
        reloadTask?.cancel()
        let task = Task { await self.performReload() }
        reloadTask = task
        await task.value
    }

    func add(_ draft: ReminderDraft) -> Bool {
        let store = eventStore ?? EKEventStore()
        eventStore = store
        guard access == .granted,
            let list = store.defaultCalendarForNewReminders()
                ?? store.calendars(for: .reminder).first(where: \.allowsContentModifications)
        else {
            return false
        }
        let reminder = EKReminder(eventStore: store)
        reminder.calendar = list
        reminder.title = draft.title
        if let fireAt = draft.fireAt {
            reminder.dueDateComponents = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute], from: fireAt)
            reminder.addAlarm(EKAlarm(absoluteDate: fireAt))
        }
        guard (try? store.save(reminder, commit: true)) != nil else { return false }
        Task { await reload() }
        return true
    }

    func complete(_ entry: ReminderEntry) -> Bool {
        guard let reminder = reminder(id: entry.id) else { return false }
        reminder.isCompleted = true
        reminder.completionDate = Date()
        guard (try? eventStore?.save(reminder, commit: true)) != nil else { return false }
        Task { await reload() }
        return true
    }

    func remove(_ entry: ReminderEntry) -> Bool {
        guard let reminder = reminder(id: entry.id) else { return false }
        guard (try? eventStore?.remove(reminder, commit: true)) != nil else { return false }
        Task { await reload() }
        return true
    }

    private func performReload() async {
        refreshAccess()
        guard access == .granted else {
            entries = []
            return
        }
        let store = eventStore ?? EKEventStore()
        eventStore = store
        observeWake()

        let lists = store.calendars(for: .reminder)
        let incomplete = store.predicateForIncompleteReminders(
            withDueDateStarting: nil, ending: nil, calendars: lists)
        let completedStart = Calendar.current.date(byAdding: .day, value: -14, to: Date())
        let completed = store.predicateForCompletedReminders(
            withCompletionDateStarting: completedStart, ending: Date(), calendars: lists)

        let openItems = await fetchEntries(matching: incomplete, from: store)
        guard !Task.isCancelled else { return }
        let doneItems = await fetchEntries(matching: completed, from: store)
        guard !Task.isCancelled else { return }
        entries = openItems + doneItems
        // After the first snapshot: a change mid-fetch would have overlapped the search queue.
        observeStoreChanges()
    }

    private func reminder(id: String) -> EKReminder? {
        eventStore?.calendarItem(withIdentifier: id) as? EKReminder
    }

    private func observeStoreChanges() {
        guard changeObserver == nil, let eventStore else { return }
        let center = NotificationCenter.default
        let token = center.addObserver(
            forName: .EKEventStoreChanged, object: eventStore, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in await self?.reload() }
        }
        changeObserver = NotificationToken(token, center: center)
    }

    private func observeWake() {
        guard wakeObserver == nil else { return }
        let center = NSWorkspace.shared.notificationCenter
        let token = center.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in await self?.reload() }
        }
        wakeObserver = NotificationToken(token, center: center)
    }

    /// `fetchReminders` finishes on `com.apple.eventkit.reminders.search`. EK objects are only
    /// safe on the thread that created the store, so the array is handed to main before mapping.
    private func fetchEntries(
        matching predicate: NSPredicate, from store: EKEventStore
    ) async -> [ReminderEntry] {
        let box: ReminderFetchBox = await withCheckedContinuation { continuation in
            store.fetchReminders(matching: predicate) { reminders in
                let box = ReminderFetchBox(reminders ?? [])
                DispatchQueue.main.async {
                    continuation.resume(returning: box)
                }
            }
        }
        return box.items.compactMap(Self.entry(from:))
    }

    private static func entry(from reminder: EKReminder) -> ReminderEntry? {
        let title = reminder.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !title.isEmpty else { return nil }
        let due = reminder.dueDateComponents.flatMap { Calendar.current.date(from: $0) }
        return ReminderEntry(
            id: reminder.calendarItemIdentifier, title: title, dueAt: due,
            completedAt: reminder.isCompleted ? (reminder.completionDate ?? due ?? Date()) : nil,
            listName: reminder.calendar?.title ?? "")
    }
}

/// Carries EventKit's fetch result off its search queue; the items are only read on main.
private final class ReminderFetchBox: @unchecked Sendable {
    let items: [EKReminder]
    init(_ items: [EKReminder]) { self.items = items }
}
