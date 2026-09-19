import SwiftUI

struct SymbolGridSection: Identifiable {
    let title: String
    let entries: [SymbolEntry]
    let start: Int

    var id: String { title }
}

enum SymbolGrid {
    @MainActor
    static func sections(
        query: String, index: SymbolIndex, frequent: FrequentSymbolStore,
        filter: SFSymbolCategoryFilter
    ) -> [SymbolGridSection] {
        var sections: [SymbolGridSection] = []
        var start = 0
        func append(_ title: String, _ entries: [SymbolEntry]) {
            guard !entries.isEmpty else { return }
            sections.append(SymbolGridSection(title: title, entries: entries, start: start))
            start += entries.count
        }

        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            switch filter {
            case .all:
                append("Frequently Used", frequent.top().compactMap(index.entry(named:)))
                for section in index.categorySections {
                    append(section.category.title, section.entries)
                }
            case .frequentlyUsed:
                append("Frequently Used", frequent.top().compactMap(index.entry(named:)))
            case .category(let category):
                if let section = index.categorySections.first(where: { $0.category == category }) {
                    append(section.category.title, section.entries)
                }
            }
        } else {
            let results = index.search(query, frequent: frequent)
            switch filter {
            case .all:
                append("Results", results)
            case .frequentlyUsed:
                let names = Set(frequent.top())
                append("Results", results.filter { names.contains($0.name) })
            case .category(let category):
                append("Results", results.filter { $0.categoryKeys.contains(category.key) })
            }
        }
        return sections
    }
}

private struct SymbolGridRow: Identifiable {
    let id: String
    let start: Int
    let entries: ArraySlice<SymbolEntry>
    let isLastInSection: Bool

    subscript(column: Int) -> SymbolEntry {
        entries[entries.index(entries.startIndex, offsetBy: column)]
    }
}

private enum SymbolGridItem: Identifiable {
    case header(id: String, title: String, count: Int)
    case row(SymbolGridRow)

    var id: String {
        switch self {
        case .header(let id, _, _): return id
        case .row(let row): return row.id
        }
    }
}

struct SymbolGridView: View {
    @Environment(\.metrics) private var metrics
    let sections: [SymbolGridSection]
    let selection: Int
    let columns: EmojiGridColumns
    let scroll: ScrollIntent
    let onSelect: (Int) -> Void
    let onActivate: () -> Void
    let onActions: (Int) -> Void

    private var items: [SymbolGridItem] {
        var items: [SymbolGridItem] = []
        for section in sections {
            items.append(
                .header(
                    id: section.id + "-header", title: section.title,
                    count: section.entries.count))
            var offset = 0
            var row = 0
            while offset < section.entries.count {
                let end = min(offset + columns.rawValue, section.entries.count)
                items.append(
                    .row(
                        SymbolGridRow(
                            id: section.id + "-row-\(row)",
                            start: section.start + offset,
                            entries: section.entries[offset..<end],
                            isLastInSection: end == section.entries.count)))
                offset = end
                row += 1
            }
        }
        return items
    }

    private var selectedRowID: String? {
        guard let section = sections.last(where: { selection >= $0.start }),
            selection - section.start < section.entries.count
        else { return nil }
        return section.id + "-row-\((selection - section.start) / columns.rawValue)"
    }

    private var firstRowID: String? { sections.first.map { $0.id + "-row-0" } }

    var body: some View {
        let items = items
        return ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(items) { item in
                        switch item {
                        case .header(_, let title, let count):
                            SymbolSectionHeader(
                                title: title, count: count, isFirst: item.id == items.first?.id)
                        case .row(let row):
                            SymbolGridRowView(
                                row: row, selection: selection, columns: columns,
                                onSelect: onSelect, onActivate: onActivate, onActions: onActions
                            )
                            .padding(
                                .bottom,
                                row.isLastInSection ? 0 : metrics.spacing.md
                            )
                            .selectionFrame(item.id == selectedRowID)
                        }
                    }
                }
                .padding(.horizontal, metrics.size.emojiGridInset)
                .padding(.top, metrics.spacing.xs)
                .padding(.bottom, metrics.spacing.md)
                .hideNativeScrollers()
                .scrollOriginAnchor()
            }
            .edgeDissolve()
            .thinScrollbar()
            .scrollFollowsSelection(
                scroll, row: selectedRowID, atOrigin: selectedRowID == firstRowID, proxy: proxy
            )
        }
    }
}

private struct SymbolSectionHeader: View {
    @Environment(\.metrics) private var metrics
    let title: String
    let count: Int
    let isFirst: Bool

    var body: some View {
        HStack(spacing: metrics.spacing.sm) {
            Text(title)
                .foregroundStyle(Theme.Colors.textSecondary)
            Text(count, format: .number)
                .foregroundStyle(Theme.Colors.textTertiary)
                .monospacedDigit()
            Spacer(minLength: 0)
        }
        .font(metrics.typography.sectionHeader)
        .padding(.top, isFirst ? metrics.spacing.xs : metrics.spacing.emojiSectionSpacing)
        .padding(.bottom, metrics.spacing.md)
    }
}

/// Interaction lives on the row, never the cell — same bound as the emoji grid.
private struct SymbolGridRowView: View {
    @Environment(\.metrics) private var metrics
    @Environment(PaletteState.self) private var palette
    let row: SymbolGridRow
    let selection: Int
    let columns: EmojiGridColumns
    let onSelect: (Int) -> Void
    let onActivate: () -> Void
    let onActions: (Int) -> Void

    @State private var hoveredColumn: Int?

    private var spacing: CGFloat { metrics.spacing.md }

    private var cellSize: CGFloat {
        let count = CGFloat(columns.rawValue)
        let contentWidth = metrics.size.panelWidth - metrics.size.emojiGridInset * 2
        return (contentWidth - spacing * (count - 1)) / count
    }

    var body: some View {
        HStack(spacing: spacing) {
            ForEach(0..<columns.rawValue, id: \.self) { column in
                if column < row.entries.count {
                    SymbolCell(
                        name: row[column].name,
                        selected: row.start + column == selection,
                        hovered: column == hoveredColumn,
                        size: cellSize)
                } else {
                    Color.clear.frame(width: cellSize, height: cellSize)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .gesture(
            SpatialTapGesture().onEnded { value in
                if let column = column(at: value.location) { onSelect(row.start + column) }
            }
        )
        .simultaneousGesture(
            SpatialTapGesture(count: 2).onEnded { value in
                guard let column = column(at: value.location) else { return }
                onSelect(row.start + column)
                onActivate()
            }
        )
        .onRightClick { point in
            if let column = column(at: point) { onActions(row.start + column) }
        }
        .onContinuousHover(coordinateSpace: .local) { phase in
            switch phase {
            case .active(let point):
                hoveredColumn = palette.hoverHighlightArmed ? column(at: point) : nil
            case .ended:
                hoveredColumn = nil
            }
        }
        .onChange(of: palette.hoverDisarmToken) { hoveredColumn = nil }
    }

    private func column(at point: CGPoint) -> Int? {
        guard point.x >= 0 else { return nil }
        let pitch = cellSize + spacing
        let column = Int(point.x / pitch)
        let positionInCell = point.x - CGFloat(column) * pitch
        guard column < row.entries.count, positionInCell <= cellSize else { return nil }
        return column
    }
}

private struct SymbolCell: View {
    let name: String
    let selected: Bool
    let hovered: Bool
    let size: CGFloat

    var body: some View {
        let glyph = min(size * 0.46, 22)
        ZStack {
            RoundedRectangle(cornerRadius: Theme.Radius.emojiCell, style: .continuous)
                .fill(selected ? Theme.Colors.selection : hovered ? Theme.Colors.rowHover : .clear)
            SymbolImage(name: name, size: glyph, monochrome: true)
                .foregroundStyle(Theme.Colors.textPrimary)
        }
        .frame(width: size, height: size)
        .accessibilityLabel(name)
    }
}
