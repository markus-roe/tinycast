import SwiftUI

@MainActor
@Observable
final class ReminderFormState {
    var form = ReminderForm()
}

struct ReminderDraftFields: View {
    @Environment(\.metrics) private var metrics
    @Bindable var state: ReminderFormState
    @FocusState private var titleFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: metrics.spacing.xl) {
            TextField("", text: $state.form.title, prompt: Text("Title"))
                .focused($titleFocused)
                .dialogTextField()

            HStack(alignment: .top, spacing: metrics.spacing.xl) {
                picker(label: "Date", components: .date)
                picker(label: "Time", components: .hourAndMinute)
            }
            .opacity(state.form.when == .none ? 0.45 : 1)

            VStack(alignment: .leading, spacing: metrics.spacing.sm) {
                Text(whenCaption)
                    .font(metrics.typography.rowTrailing)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .lineLimit(1)
                HStack(spacing: 0) {
                    ForEach(ReminderForm.shortcuts, id: \.label) { shortcut in
                        SuggestionChip(
                            title: shortcut.label,
                            selected: state.form.when == shortcut.when
                        ) { state.form.when = shortcut.when }
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: metrics.radius.row, style: .continuous)
                        .fill(Theme.Colors.controlSurface))
            }
        }
        .defaultFocus($titleFocused, true)
        .onAppear { titleFocused = true }
    }

    private func picker(label: String, components: DatePicker.Components) -> some View {
        VStack(alignment: .leading, spacing: metrics.spacing.sm) {
            Text(label)
                .font(metrics.typography.rowTrailing)
                .foregroundStyle(Theme.Colors.textSecondary)
            DatePicker("", selection: pickerDate, displayedComponents: components)
                .datePickerStyle(.compact)
                .labelsHidden()
                .controlSize(.regular)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var pickerDate: Binding<Date> {
        Binding(
            get: {
                state.form.fireAt(now: Date(), calendar: .current) ?? Self.fallbackDate
            },
            set: { state.form.when = .custom($0) }
        )
    }

    private var whenCaption: String {
        let now = Date()
        let calendar = Calendar.current
        let draft = state.form.draft(now: now, calendar: calendar)
        guard draft.fireAt != nil else { return "No date" }
        return draft.whenCaption(now: now, calendar: calendar)
    }

    /// Shown only while no date is committed, so a first click on a picker has somewhere to start.
    private static var fallbackDate: Date {
        let now = Date()
        let calendar = Calendar.current
        let next = calendar.date(byAdding: .hour, value: 1, to: now) ?? now
        return calendar.date(bySetting: .minute, value: 0, of: next)
            .flatMap { calendar.date(bySetting: .second, value: 0, of: $0) } ?? next
    }
}

private struct SuggestionChip: View {
    @Environment(\.metrics) private var metrics
    let title: String
    let selected: Bool
    let action: () -> Void
    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(metrics.typography.rowTrailing)
                .foregroundStyle(selected ? Theme.Colors.textPrimary : Theme.Colors.textSecondary)
                .frame(maxWidth: .infinity)
                .frame(height: metrics.size.dialogButtonHeight)
                .contentShape(Rectangle())
                .background(
                    RoundedRectangle(cornerRadius: metrics.radius.row, style: .continuous)
                        .fill(fill))
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
        .accessibilityLabel(title)
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }

    private var fill: Color {
        if selected { return Theme.Colors.selection }
        if hovered { return Theme.Colors.rowHover }
        return .clear
    }
}
