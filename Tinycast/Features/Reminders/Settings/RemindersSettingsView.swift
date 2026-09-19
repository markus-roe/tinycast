import SwiftUI

struct RemindersSettingsView: View {
    @Environment(AppCore.self) private var core
    @Environment(AppSettings.self) private var settings
    @Environment(ReminderStore.self) private var store

    var body: some View {
        @Bindable var settings = settings
        Form {
            FeatureSwitchSection(
                anchor: .remindersReminders,
                enableTitle: "Use Apple Reminders",
                enableSubtitle:
                    "Reads and writes Reminders on this Mac so they sync to your iPhone. "
                    + "Nothing else leaves this Mac.",
                isEnabled: enabledBinding,
                showsInLauncher: $settings.remindersShowInLauncher)

            if settings.remindersEnabled, store.access == .notDetermined {
                Section {
                    SettingsRow(
                        title: "Reminders access is needed",
                        subtitle: "Needed to list and add reminders."
                    ) {
                        Button("Allow Reminders Access…") {
                            core.reminderCoordinator.setRemindersEnabled(true)
                        }
                    }
                }
            } else if store.access == .denied {
                Section {
                    SettingsRow(
                        title: "Reminders access is off",
                        subtitle: "Allow it in Privacy & Security ▸ Reminders."
                    ) {
                        Button("Open System Settings…") { Permissions.openRemindersSettings() }
                    }
                }
            }

            FeatureCommandsSection(owner: .reminders, anchor: .remindersCommands)
                .settingsEnabled(settings.remindersEnabled)
        }
        .formStyle(.grouped)
        .settingsScrollTarget(.reminders)
        .releasesFocusOnOutsideClick()
        .onAppear { store.refreshAccess() }
    }

    private var enabledBinding: Binding<Bool> {
        Binding(
            get: { settings.remindersEnabled },
            set: { core.reminderCoordinator.setRemindersEnabled($0) }
        )
    }
}
