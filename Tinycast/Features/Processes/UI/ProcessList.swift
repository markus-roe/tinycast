import SwiftUI

struct ProcessList: View {
    @Environment(\.metrics) private var metrics
    let entries: [ProcessEntry]
    let selectedID: ProcessEntry.ID?
    let scroll: ScrollIntent
    let onSelect: (ProcessEntry) -> Void
    let onActivate: (ProcessEntry) -> Void
    let onActions: (ProcessEntry) -> Void

    private var firstRowSelected: Bool {
        selectedID != nil && selectedID == entries.first?.id
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(entries) { entry in
                        ProcessRow(entry: entry, selected: entry.id == selectedID)
                            .selectionFrame(entry.id == selectedID)
                            .contentShape(Rectangle())
                            .onTapGesture { onSelect(entry) }
                            .simultaneousGesture(
                                TapGesture(count: 2).onEnded {
                                    onSelect(entry)
                                    onActivate(entry)
                                }
                            )
                            .onRightClick { onActions(entry) }
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
                scroll, row: selectedID, atOrigin: firstRowSelected, proxy: proxy)
        }
    }
}

private struct ProcessRow: View {
    @Environment(\.metrics) private var metrics
    let entry: ProcessEntry
    let selected: Bool
    @State private var hovered = false

    private var fill: Color {
        if selected { return Theme.Colors.selection }
        if hovered { return Theme.Colors.rowHover }
        return .clear
    }

    var body: some View {
        HStack(spacing: metrics.spacing.lg) {
            icon
                .frame(width: metrics.size.rowIcon, height: metrics.size.rowIcon)
            Text(entry.name)
                .font(metrics.typography.rowTitle)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: metrics.spacing.md)
            Text(entry.trailing)
                .font(metrics.typography.rowTrailing)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.horizontal, metrics.spacing.md)
        .padding(.vertical, metrics.spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: metrics.radius.row, style: .continuous)
                .fill(fill)
        )
        .armedHover($hovered)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(entry.name)
        .accessibilityValue(entry.trailing)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    @ViewBuilder private var icon: some View {
        if let path = entry.appBundlePath {
            EntryIconView(source: .file(stamp: 0), fileURL: URL(fileURLWithPath: path))
        } else if !entry.ports.isEmpty {
            EntryIconView(source: .symbol("network"))
        } else {
            EntryIconView(source: .symbol("apple.terminal"))
        }
    }
}
