# Reminders

A palette sub-screen over **Apple Reminders** on this Mac. Adds and completions go through EventKit,
so they appear in Reminders.app and sync to the iPhone when iCloud Reminders is on.

## Invariants

- **`Model/` stays Foundation-only.** `ReminderEntry`, `ReminderDraft`, `ReminderQuery`,
  `ReminderPolicy` and `ReminderSearch` compile in `reminder-test` with the shared fuzzy scorer.
  EventKit lives in `Service/ReminderStore.swift` and nothing EventKit-shaped leaves it.
- **Nothing is stored in Tinycast.** There is no `reminders.json` and no local notification
  schedule. Apple Reminders owns the record and the alert.
- **`remindersEnabled` doubles as consent**, so it is in `SettingsBackupCoverage.deliberatelyExcluded`
  and only `ReminderCoordinator.setRemindersEnabled` may write it. Tinycast's own dialog comes first,
  the macOS prompt second, and the flag is written only after macOS grants. Enabling is re-offered
  whenever access is anything but granted.
- **A typed when is a compose row; prose is an undated add.** `in 25m Tee`, `25m`, `14:30 call` and
  `tomorrow milk` set a due date and an alarm. `milk` adds an undated reminder. An empty field opens
  New Reminder…. The dialog's date and time pickers set an absolute due; chips are shortcuts.
  Relative times cap at 7 days.
- **Root search leads on a when, never on prose.** `ReminderQuery.lead` answers only after the
  calculator and colour cards pass, and only while the feature is on and granted. `in`, `at` and
  `tomorrow` lead even without a title; a bare duration or clock needs leftover words (`25m tea`,
  `14:30 call`) so `25m` stays metres. ↵ adds and dismisses. `milk` stays an app search.
- **Due first, completed last.** Open rows sort overdue, then soonest due, then undated. Completed
  rows keep the newest 20 from the last 14 days. Open listing caps at 200.
- **Delete asks.** Completing writes `isCompleted` to EventKit. ⌃X removes the reminder from
  Reminders on every device after `DialogController`.
- **The app leaves search while the feature is on.** `Reminders.app` and the command would otherwise
  be the same first row. The screen's **Open Reminders** row (and ⌘K) launches the app; turning the
  feature off puts the app back. Settings → Applications still lists it.

## Layout

| Path | Role |
| --- | --- |
| `Model/ReminderEntry.swift` | Flattened `EKReminder` and the remaining / clock labels |
| `Model/ReminderDraft.swift` | A parsed or dialog-built add, plus the form's date |
| `Model/ReminderQuery.swift` | `in` / `tomorrow` / `at` / duration / `HH:MM`, plus `lead` |
| `Model/ReminderPolicy.swift` | Cap, due-first open order |
| `Model/ReminderSearch.swift` | Ranking open and completed independently |
| `Service/ReminderStore.swift` | EventKit fetch, save, complete, remove |
| `UI/ReminderCoordinator.swift` | Consent, show, create, complete, delete |
| `UI/ReminderScreen.swift`, `UI/ReminderList.swift` | The palette screen |
| `UI/ReminderCard.swift` | The launcher lead card |
| `UI/ReminderDraftFields.swift` | The New Reminder dialog accessory |
| `Settings/RemindersSettingsView.swift` | The feature switch |

## Commands

`Reminders` and `Create Reminder` exist only while the feature is on, listed on Settings → Reminders.
The first run of either command (or the Settings switch) is the consent path. ↵ on an open row marks
it done in Reminders.app; ⌃X deletes after a confirm. A parsed when in root search is the same add
as the screen's compose row, without opening the screen. **Open Reminders** at the bottom of the
screen launches Reminders.app.
