import SwiftUI

/// The launcher's reminder card; selectable like a row, Enter adds and dismisses.
struct ReminderCard: View {
    @Environment(\.metrics) private var metrics
    let draft: ReminderDraft
    let now: Date
    let calendar: Calendar
    let selected: Bool

    var body: some View {
        HStack(spacing: metrics.spacing.xl) {
            SymbolImage(
                name: draft.kind == .timer ? "timer" : "bell",
                size: metrics.size.headerIconSlot
            )
            .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: metrics.spacing.xs) {
                Text(draft.title)
                    .font(metrics.typography.calcResult.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(draft.whenCaption(now: now, calendar: calendar))
                    .font(metrics.typography.rowTrailing)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: metrics.spacing.md)
            Text(kindLabel)
                .font(metrics.typography.rowTitle.weight(.medium))
                .lineLimit(1)
                .padding(.horizontal, metrics.spacing.md)
                .padding(.vertical, metrics.spacing.xxs)
                .background(
                    RoundedRectangle(cornerRadius: metrics.radius.keyCap, style: .continuous)
                        .fill(Theme.Colors.controlSurface)
                )
        }
        .padding(.horizontal, metrics.spacing.xl)
        .padding(.vertical, metrics.spacing.xxl)
        .leadCard(selected: selected)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(draft.title), \(draft.whenCaption(now: now, calendar: calendar))")
        .accessibilityAddTraits(.isButton)
    }

    private var kindLabel: String {
        switch draft.kind {
        case .timer: return "Timer"
        case .reminder: return "Reminder"
        }
    }
}

@MainActor
enum ReminderLeadActionsMenu {
    static func content(draft: ReminderDraft, core: AppCore) -> PopoverMenuContent {
        PopoverMenuContent(
            header: draft.title,
            items: [
                PopoverMenuItem(
                    title: "Add to Reminders", systemImage: "bell", shortcut: "↵"
                ) { core.reminderCoordinator.addFromLauncher(draft) }
            ])
    }
}
