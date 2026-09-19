# Manage Processes

A palette sub-screen over the processes this Mac is running, so a name, a PID or `:3000` is enough
to quit one. It records nothing: every open is a fresh `libproc` snapshot.

## Invariants

- **`Model/` stays Foundation-only.** `ProcessEntry`, `ProcessQuery`, `ProcessSearch` and
  `ProcessPolicy` compile in `process-test` with the shared fuzzy scorer. Listing and signalling
  live in `Service/`.
- **No persistence.** There is no history file, no ranking store and no settings key. Hiding the
  palette resets the session.
- **A blank query leads with listeners.** `:3000` is the reason the screen exists, so processes
  with a listening port sort first; a typed query ranks through `SearchRelevance` on name, PID,
  path and port.
- **`:3000` is a port, `3000` is text.** A leading colon is the only spelling that drops every
  process that is not listening on that port. A bare number still matches a PID.
- **Tinycast cannot quit itself, pid ≤ 1, or `kernel_task` / `launchd` / `WindowServer`.** Another
  user's process is listed and can be copied, but ↵ refuses it.
- **Force Quit asks.** ↵ is `SIGTERM` (or `NSRunningApplication.terminate` for a GUI app) and does
  not confirm. ⌃X is `SIGKILL` after `DialogController`.

## Layout

| Path | Role |
| --- | --- |
| `Model/ProcessEntry.swift` | The row, its ports and the memory spelling |
| `Model/ProcessQuery.swift` | `:port` versus text |
| `Model/ProcessSearch.swift` | Ranking and the 200-row cap |
| `Model/ProcessPolicy.swift` | Who may be signalled |
| `Service/ProcessEnumerator.swift` | `libproc` snapshot, off-main |
| `Service/ProcessSession.swift` | The live list the screen reads |
| `Service/ProcessRunner.swift` | Terminate / force-terminate |
| `UI/ProcessCoordinator.swift` | Show, quit, copy |
| `UI/ProcessScreen.swift`, `UI/ProcessList.swift` | The palette screen |

## Commands

`Manage Processes` is always on and listed in Settings → Commands. ↵ quits; ⌘↵ copies the PID;
⌃⌘C / ⌥⌘C copy the PID / name; ⌃X force-quits after a confirm.
