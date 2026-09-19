import SwiftUI

struct ReminderList: View {
    @Environment(\.metrics) private var metrics
    let rows: [ReminderScreen.Row]
    let selection: Int
    let scroll: ScrollIntent
    let calendar: Calendar
    let onSelect: (Int) -> Void
    let onActivate: () -> Void
    let onActions: (Int) -> Void

    private var selectedID: String? {
        rows.indices.contains(selection) ? rows[selection].id : nil
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                        rowView(row, index: index)
                            .selectionFrame(index == selection)
                            .contentShape(Rectangle())
                            .onTapGesture { onSelect(index) }
                            .simultaneousGesture(
                                TapGesture(count: 2).onEnded {
                                    onSelect(index)
                                    onActivate()
                                }
                            )
                            .onRightClick { onActions(index) }
                    }
                }
                .padding(.horizontal, metrics.spacing.md)
                .padding(.vertical, metrics.spacing.md)
                .hideNativeScrollers()
                .scrollOriginAnchor()
            }
            .edgeDissolve()
            .thinScrollbar()
            .scrollFollowsSelection(
                scroll, row: selectedID, atOrigin: selection == 0, proxy: proxy)
        }
    }

    @ViewBuilder
    private func rowView(_ row: ReminderScreen.Row, index: Int) -> some View {
        switch row {
        case .compose(let draft):
            ReminderActionRow(
                title: draft.summary(now: Date(), calendar: calendar),
                symbol: draft.kind == .timer ? "timer" : "bell",
                selected: index == selection)
        case .create:
            ReminderActionRow(
                title: "New Reminder…", symbol: "plus", selected: index == selection)
        case .item(let entry):
            ReminderItemRow(entry: entry, selected: index == selection, calendar: calendar)
        case .openApp:
            ReminderActionRow(
                title: "Open Reminders", symbol: "arrow.up.forward.app",
                selected: index == selection)
        }
    }
}

private struct ReminderActionRow: View {
    @Environment(\.metrics) private var metrics
    let title: String
    let symbol: String
    let selected: Bool
    @State private var hovered = false

    var body: some View {
        HStack(spacing: metrics.spacing.lg) {
            EntryIconView(source: .symbol(symbol))
                .frame(width: metrics.size.rowIcon, height: metrics.size.rowIcon)
            Text(title)
                .font(metrics.typography.rowTitle)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, metrics.spacing.md)
        .padding(.vertical, metrics.spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: metrics.radius.row, style: .continuous)
                .fill(fill))
        .armedHover($hovered)
    }

    private var fill: Color {
        if selected { return Theme.Colors.selection }
        if hovered { return Theme.Colors.rowHover }
        return .clear
    }
}

private struct ReminderItemRow: View {
    @Environment(\.metrics) private var metrics
    let entry: ReminderEntry
    let selected: Bool
    let calendar: Calendar
    @State private var hovered = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            HStack(spacing: metrics.spacing.lg) {
                EntryIconView(source: .symbol(entry.symbol(at: context.date)))
                    .frame(width: metrics.size.rowIcon, height: metrics.size.rowIcon)
                    .opacity(entry.isCompleted ? 0.45 : 1)
                VStack(alignment: .leading, spacing: 1) {
                    Text(entry.title)
                        .font(metrics.typography.rowTitle)
                        .strikethrough(entry.isCompleted)
                        .foregroundStyle(
                            entry.isCompleted ? AnyShapeStyle(.secondary) : AnyShapeStyle(.primary))
                        .lineLimit(1)
                    if !entry.listName.isEmpty, entry.dueAt != nil || entry.isCompleted {
                        Text(entry.listName)
                            .font(metrics.typography.rowTrailing)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: metrics.spacing.md)
                Text(entry.whenLabel(at: context.date, calendar: calendar))
                    .font(metrics.typography.rowTrailing)
                    .foregroundStyle(entry.isDue(at: context.date) ? Theme.Colors.destructive : .secondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, metrics.spacing.md)
            .padding(.vertical, metrics.spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: metrics.radius.row, style: .continuous)
                    .fill(fill))
        }
        .armedHover($hovered)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(entry.title)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var fill: Color {
        if selected { return Theme.Colors.selection }
        if hovered { return Theme.Colors.rowHover }
        return .clear
    }
}
