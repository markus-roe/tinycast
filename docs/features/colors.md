# Color picker

The system eyedropper and a history of colours you picked or converted. Typing a colour in the
launcher still answers with the existing card; this feature is the pick and the list of ones you
meant to keep.

## Invariants

- **`Model/` stays Foundation-only.** `ColorHistoryEntry` and `ColorHistoryPolicy` compile in
  `color-test` with the clipboard's `ColorValue` / `ColorFormat`, so an `import AppKit` there
  breaks the suite.
- **One parser, one writer.** The picker never invents a second colour type: `NSColorSampler`
  flattens through sRGB into `ColorValue`, and every copy goes through `ColorFormat`, the same
  pair the launcher card already uses.
- **A pick and a conversion land in the same file.** `ColorHistoryStore.record` is the only write;
  `ColorCoordinator.copy` and `ClipboardCoordinator.copyColor` both call it, so a hex typed in the
  launcher and a pixel sampled from the screen cannot drift into two histories.
- **The same colour is bumped, not stacked.** `ColorHistoryPolicy.applying` drops any earlier row
  with equal components and prepends, then caps at 200, so re-picking red does not grow the file.
- **Clearing asks.** `ColorCoordinator.deleteAll` is the only path ⌃⇧X and the menu share, and it
  confirms through `DialogController` the way calculator history does.

## Layout

| Path | Role |
| --- | --- |
| `Model/ColorHistoryEntry.swift` | The record and the cap/bump policy |
| `Service/ColorHistoryStore.swift` | `color-history.json` under Application Support |
| `Service/ColorSampler.swift` | `NSColorSampler` → `ColorValue` |
| `UI/ColorCoordinator.swift` | Pick, copy, delete |
| `UI/ColorScreen.swift`, `UI/ColorHistoryList.swift` | The palette screen |

## Commands

`Pick Color` hides the palette and opens the magnifier. A confirmed sample copies the primary
notation — hex, or hex-with-alpha — shows it in a HUD, and records the colour. Cancel records
nothing. `Color History` opens the screen: Pick from Screen, a live card when the query parses as
a colour, then the stored rows. ↵ on a stored row copies the primary notation; ⌘K offers every
`ColorFormat` the clipboard card already does.
