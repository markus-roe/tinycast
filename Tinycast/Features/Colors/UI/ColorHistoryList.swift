import SwiftUI

/// Pick row, optional live card, then history — one flat index, same as calculator history.
struct ColorHistoryList: View {
    @Environment(\.metrics) private var metrics
    let rows: [ColorScreen.Row]
    let selection: Int
    let scroll: ScrollIntent
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
                    }
                }
                .padding(.horizontal, metrics.spacing.md)
                .padding(.top, metrics.spacing.xs)
                .padding(.bottom, metrics.spacing.md)
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
    private func rowView(_ row: ColorScreen.Row, index: Int) -> some View {
        Group {
            switch row {
            case .pick:
                ColorPickRow(selected: index == selection)
            case .parsed(let color):
                ColorCard(color: color, selected: index == selection)
                    .padding(.bottom, metrics.spacing.xs)
            case .history(let entry):
                ColorHistoryRow(entry: entry, selected: index == selection)
            }
        }
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

private struct ColorPickRow: View {
    @Environment(\.metrics) private var metrics
    let selected: Bool
    @State private var hovered = false

    private var fill: Color {
        if selected { return Theme.Colors.selection }
        if hovered { return Theme.Colors.rowHover }
        return .clear
    }

    var body: some View {
        HStack(spacing: metrics.spacing.lg) {
            SymbolImage(name: "eyedropper", size: 14, monochrome: true)
                .foregroundStyle(Theme.Colors.textSecondary)
                .frame(width: metrics.size.rowIcon, height: metrics.size.rowIcon)
            Text("Pick from Screen")
                .font(metrics.typography.rowTitle)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, metrics.spacing.md)
        .padding(.vertical, metrics.spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: metrics.radius.row, style: .continuous)
                .fill(fill)
        )
        .armedHover($hovered)
    }
}

private struct ColorHistoryRow: View {
    @Environment(\.metrics) private var metrics
    let entry: ColorHistoryEntry
    let selected: Bool
    @State private var hovered = false

    private var fill: Color {
        if selected { return Theme.Colors.selection }
        if hovered { return Theme.Colors.rowHover }
        return .clear
    }

    var body: some View {
        let format = ColorFormat.primary(for: entry.color)
        HStack(spacing: metrics.spacing.lg) {
            ColorSwatch(color: entry.color)
                .frame(width: metrics.size.rowIcon, height: metrics.size.rowIcon)
            Text(format.string(for: entry.color))
                .font(metrics.typography.rowTitle.weight(.semibold))
                .lineLimit(1)
            Spacer(minLength: metrics.spacing.xl)
            Text(format.title)
                .font(metrics.typography.rowTrailing)
                .foregroundStyle(Theme.Colors.textSecondary)
        }
        .padding(.horizontal, metrics.spacing.md)
        .padding(.vertical, metrics.spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: metrics.radius.row, style: .continuous)
                .fill(fill)
        )
        .armedHover($hovered)
    }
}
