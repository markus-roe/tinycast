# SF Symbols picker

A palette sub-screen, sibling of [emoji.md](emoji.md), over the SF Symbols this Mac actually ships.

## Invariants

- **`Model/` stays Foundation-only.** `SymbolEntry`, `SFSymbolCategory`, `SFSymbolCategoryFilter`,
  `SymbolCopyFormat` and `SymbolSearch` compile in `sf-symbols-test`, so an `import AppKit` there
  breaks the suite.
- **The catalog is this Mac's CoreGlyphs bundle, never a generated file.** `SymbolCatalogLoader`
  reads `name_availability.plist`, `symbol_order.plist`, `symbol_categories.plist`,
  `symbol_search.plist` and `categories.plist` off-main. A new OS with new symbols shows them
  without a Tinycast release. The loader prefers `/System/Library/CoreServices/CoreGlyphs.bundle`
  and falls back to the SF Symbols framework copy.
- **Locale variants are dropped.** Names matching `.(ar|he|hi|ja|ko|th|zh)` are the same glyph for
  another script; the Latin name is the one `Image(systemName:)` takes.
- **Rendering-mode collections are not browse sections.** `all`, `whatsnew`, `draw`, `variable` and
  `multicolor` would list almost every symbol twice; they stay out of the category menu.
- **Interaction lives on the row, never the cell.** Same bound as the emoji grid: a fast scroll
  over thousands of cells must not attach per-cell gestures. Vertical arrows reuse
  `EmojiGridGeometry`.
- **Usage breaks ties, never tiers.** `FrequentSymbolStore.top` adds a 100…1 bonus, the way
  `FrequentEmojiStore` does, and the store's identity and revision are in the search memo key.

## Layout

| Path | Role |
| --- | --- |
| `Model/SymbolEntry.swift` | Entry, `SFSymbolCategory`, filter, copy format |
| `Model/SymbolSearch.swift` | Pure ranking over name and keywords |
| `Service/SymbolCatalogLoader.swift` | CoreGlyphs read |
| `Service/SymbolIndex.swift` | Loaded catalog and memoized search |
| `Service/FrequentSymbolStore.swift` | `sf-symbol-frequency.json` |
| `UI/SymbolCoordinator.swift` | Paste / copy |
| `UI/SymbolScreen.swift`, `UI/SymbolGridView.swift` | The palette screen |

## Copy

↵ pastes the symbol name into the previous app. ⌘↵ copies the name. The Actions menu also offers
`Image(systemName:)` and `Label("…", systemImage:)`, because those are the two spellings a Swift
file actually wants. Frequency tallies the name in every case.
