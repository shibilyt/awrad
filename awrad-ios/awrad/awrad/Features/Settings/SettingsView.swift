import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(AwradStore.self) private var store
    @Environment(AppServices.self) private var services
    @State private var backupDocument: AwradBackupDocument?
    @State private var isExportingBackup = false
    @State private var isImportingBackup = false
    @State private var dataMessage: String?
    @State private var showDataMessage = false
    @State private var isDownloadingAudioLibrary = false
    @State private var audioDownloadCompletedCount = 0
    @State private var audioDownloadTotalCount = 0
    @State private var destructiveAction: SettingsDestructiveAction?
    @State private var isEditingProfileName = false
    @State private var draftProfileName = ""
    private var language: AppLanguage { store.preferences.appLanguage }
    private var audioItems: [Dhikr] { store.dhikrs.filter { $0.audioURL != nil } }
    private var pendingAudioItems: [Dhikr] { audioItems.filter { !$0.isDownloaded } }
    private var audioSummary: AudioLibrarySummary { AudioLibraryCalculator.summary(for: store.dhikrs) }

    var body: some View {
        Form {
            Section("Profile") {
                ProfileNameEditor(
                    name: store.preferences.userName,
                    isEditing: $isEditingProfileName,
                    draftName: $draftProfileName,
                    onEdit: startEditingProfileName,
                    onSave: saveProfileName,
                    onCancel: cancelEditingProfileName
                )
            }

            Section("Counting") {
                Toggle("Haptic feedback", isOn: preferenceBinding(\.vibrateOnCount))
                    .tint(AwradTheme.sage)
                Toggle("Keep screen awake while counting", isOn: preferenceBinding(\.keepScreenOn))
                    .tint(AwradTheme.sage)
                Toggle("Sound on count", isOn: preferenceBinding(\.soundOnCount))
                    .tint(AwradTheme.sage)
            }

            Section("Date & Calendar") {
                AwradBottomSheetPicker(
                    title: "Day reset",
                    selection: preferenceBinding(\.dayReset),
                    options: DayResetOption.allCases
                ) { $0 == .midnight ? "Midnight" : "Maghrib" }
                AwradBottomSheetPicker(
                    title: "Calendar",
                    selection: preferenceBinding(\.calendarSystem),
                    options: CalendarSystem.allCases
                ) { $0 == .gregorian ? "Gregorian" : "Hijri" }
                if store.preferences.dayReset == .maghrib && store.preferences.latitude == nil {
                    Text("Set a prayer location to use Maghrib as the day boundary.")
                        .font(AwradTheme.bodyFont(.footnote))
                        .foregroundStyle(.secondary)
                }
            }

            Section("Notifications & Reminders") {
                Toggle("Daily reminder", isOn: Binding(
                    get: { store.preferences.dailyReminderEnabled },
                    set: { enabled in
                        store.updatePreferences { $0.dailyReminderEnabled = enabled }
                        if enabled {
                            Task {
                                await services.notifications.scheduleDailyReminder(
                                    hour: store.preferences.reminderHour,
                                    minute: store.preferences.reminderMinute,
                                    language: store.preferences.appLanguage
                                )
                            }
                        } else {
                            services.notifications.cancelDailyReminder()
                        }
                    }
                ))
                .tint(AwradTheme.sage)

                DatePicker(
                    "Reminder time",
                    selection: reminderTimeBinding,
                    displayedComponents: .hourAndMinute
                )
                Stepper(value: preferenceBinding(\.prayerSlotDefaultLeadMinutes), in: 0...180, step: 5) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Before-prayer start window")
                        Text(AwradLocalizer.format(
                            "%d minutes before prayer",
                            language: language,
                            store.preferences.prayerSlotDefaultLeadMinutes
                        ))
                        .font(AwradTheme.bodyFont(.footnote))
                        .foregroundStyle(.secondary)
                    }
                }
                Button {
                    rescheduleAllReminders()
                } label: {
                    Label("Refresh scheduled reminders", systemImage: "arrow.clockwise")
                }
            }

            Section("Prayer Settings") {
                PrayerLocationSetupView(mode: .displayWithChange)

                AwradBottomSheetPicker(
                    title: "Calculation method",
                    selection: preferenceBinding(\.calculationMethod),
                    options: PrayerCalculationMethod.allCases
                ) { $0.title }
                AwradBottomSheetPicker(
                    title: "Madhab",
                    selection: preferenceBinding(\.madhab),
                    options: PrayerMadhab.allCases
                ) { $0.title }
            }

            Section("Audio Library") {
                HStack(spacing: 12) {
                    Label("Offline audio", systemImage: "waveform.circle.fill")
                    Spacer()
                    Text("\(audioSummary.downloadedCount)/\(audioSummary.availableCount)")
                        .font(AwradTheme.bodyFont(.body).monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                if audioSummary.availableCount == 0 {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("No audio files available yet")
                            .font(AwradTheme.bodyFont(.subheadline, weight: .semibold))
                        Text("Audio files will appear here when available.")
                            .font(AwradTheme.bodyFont(.footnote))
                            .foregroundStyle(.secondary)
                    }
                } else {
                    ProgressView(value: audioSummary.progress)
                        .tint(AwradTheme.sage)

                    if isDownloadingAudioLibrary {
                        ProgressView(
                            value: Double(audioDownloadCompletedCount),
                            total: Double(max(audioDownloadTotalCount, 1))
                        )
                        .tint(AwradTheme.gold)
                        Text(AwradLocalizer.format(
                            "Downloading %d of %d",
                            language: language,
                            audioDownloadCompletedCount,
                            audioDownloadTotalCount
                        ))
                        .font(AwradTheme.bodyFont(.footnote))
                        .foregroundStyle(.secondary)
                    }

                    Button {
                        downloadMissingAudio()
                    } label: {
                        Label(audioLibraryButtonTitle, systemImage: "arrow.down.circle.fill")
                    }
                    .disabled(audioSummary.pendingCount == 0 || isDownloadingAudioLibrary)

                    ForEach(Array(audioItems.prefix(5))) { dhikr in
                        audioLibraryRow(for: dhikr)
                    }
                }
            }

            Section("Appearance") {
                AwradBottomSheetPicker(
                    title: "Appearance",
                    selection: preferenceBinding(\.colorSchemeMode),
                    options: ColorSchemeMode.allCases
                ) { $0.title }
            }

            Section("Language") {
                AwradBottomSheetPicker(
                    title: "Language",
                    selection: preferenceBinding(\.appLanguage),
                    options: AppLanguage.allCases
                ) { $0.title }
            }

            Section("Data") {
                Button {
                    exportBackup()
                } label: {
                    Label("Export backup", systemImage: "square.and.arrow.up")
                }

                Button {
                    isImportingBackup = true
                } label: {
                    Label("Import backup", systemImage: "square.and.arrow.down")
                }

                Button(role: .destructive) {
                    destructiveAction = .resetProgress
                } label: {
                    Label("Reset progress", systemImage: "arrow.counterclockwise")
                }

                Button(role: .destructive) {
                    destructiveAction = .deleteAllGoals
                } label: {
                    Label("Delete all goals", systemImage: "trash")
                }
            }

            #if DEBUG
            DebugSettingsSection(
                onTestNow: sendTestNotificationNow,
                onTestIn30Seconds: scheduleTestNotificationIn30Seconds,
                onRescheduleAll: rescheduleAllRemindersFromDebug
            )
            #endif

            Section("About") {
                HStack(spacing: 12) {
                    Image(systemName: "info.circle")
                        .foregroundStyle(AwradTheme.sage)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(appDisplayName)
                            .font(AwradTheme.bodyFont(.subheadline, weight: .semibold))
                        Text(AwradLocalizer.format("Version %@", language: language, appVersion))
                            .font(AwradTheme.bodyFont(.footnote))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Settings")
        .onChange(of: store.preferences.reminderHour) { _, _ in rescheduleReminderIfNeeded() }
        .onChange(of: store.preferences.reminderMinute) { _, _ in rescheduleReminderIfNeeded() }
        .onChange(of: store.preferences.latitude) { _, _ in rescheduleAllReminders() }
        .onChange(of: store.preferences.longitude) { _, _ in rescheduleAllReminders() }
        .onChange(of: store.preferences.calculationMethod) { _, _ in rescheduleAllReminders() }
        .onChange(of: store.preferences.madhab) { _, _ in rescheduleAllReminders() }
        .fileExporter(
            isPresented: $isExportingBackup,
            document: backupDocument,
            contentType: .json,
            defaultFilename: "awrad-backup"
        ) { result in
            switch result {
            case .success:
                showDataStatus(AwradLocalizer.localized("Backup exported.", language: language))
            case .failure(let error):
                showDataStatus(error.localizedDescription)
            }
        }
        .fileImporter(
            isPresented: $isImportingBackup,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else {
                    showDataStatus(AwradLocalizer.localized("No backup file was selected.", language: language))
                    return
                }
                importBackup(from: url)
            case .failure(let error):
                showDataStatus(error.localizedDescription)
            }
        }
        .alert("Settings", isPresented: $showDataMessage) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(dataMessage ?? "")
        }
        .confirmationDialog(
            destructiveDialogTitle,
            isPresented: destructiveDialogPresented,
            titleVisibility: .visible
        ) {
            if let destructiveAction {
                Button(LocalizedStringKey(destructiveAction.confirmTitleKey), role: .destructive) {
                    performDestructiveAction(destructiveAction)
                }
            }
            Button("Cancel", role: .cancel) {
                destructiveAction = nil
            }
        } message: {
            if let destructiveAction {
                Text(LocalizedStringKey(destructiveAction.messageKey))
            }
        }
    }

    private var audioLibraryButtonTitle: String {
        guard audioSummary.pendingCount > 0 else {
            return AwradLocalizer.localized("All audio files downloaded", language: language)
        }
        return AwradLocalizer.format("%d audio files available to download", language: language, audioSummary.pendingCount)
    }

    private var destructiveDialogTitle: LocalizedStringKey {
        LocalizedStringKey(destructiveAction?.titleKey ?? "Confirm destructive action")
    }

    private var destructiveDialogPresented: Binding<Bool> {
        Binding(
            get: { destructiveAction != nil },
            set: { isPresented in
                if !isPresented {
                    destructiveAction = nil
                }
            }
        )
    }

    private var appDisplayName: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? "Awrad"
    }

    private var appVersion: String {
        let shortVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        switch (shortVersion, build) {
        case let (.some(shortVersion), .some(build)) where !build.isEmpty && build != shortVersion:
            return "\(shortVersion) (\(build))"
        case let (.some(shortVersion), _):
            return shortVersion
        case let (_, .some(build)):
            return build
        default:
            return "1.0"
        }
    }

    private var reminderTimeBinding: Binding<Date> {
        Binding(
            get: {
                var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
                components.hour = store.preferences.reminderHour
                components.minute = store.preferences.reminderMinute
                return Calendar.current.date(from: components) ?? Date()
            },
            set: { date in
                let components = Calendar.current.dateComponents([.hour, .minute], from: date)
                store.updatePreferences { preferences in
                    preferences.reminderHour = components.hour ?? preferences.reminderHour
                    preferences.reminderMinute = components.minute ?? preferences.reminderMinute
                }
            }
        )
    }

    private func audioLibraryRow(for dhikr: Dhikr) -> some View {
        HStack(spacing: 12) {
            Image(systemName: dhikr.isDownloaded ? "checkmark.circle.fill" : "waveform")
                .foregroundStyle(dhikr.isDownloaded ? AwradTheme.sage : AwradTheme.gold)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 3) {
                Text(dhikr.displayTitle(language: language))
                    .font(AwradTheme.bodyFont(.subheadline, weight: .semibold))
                Text(LocalizedStringKey(dhikr.isDownloaded ? "Available offline" : "Streams until downloaded"))
                    .font(AwradTheme.bodyFont(.caption))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if dhikr.isDownloaded {
                Image(systemName: "checkmark")
                    .foregroundStyle(AwradTheme.sage)
            }
        }
    }

    private func preferenceBinding<Value>(_ keyPath: WritableKeyPath<UserPreferences, Value>) -> Binding<Value> {
        Binding(
            get: { store.preferences[keyPath: keyPath] },
            set: { value in
                store.updatePreferences { preferences in
                    preferences[keyPath: keyPath] = value
                }
            }
        )
    }

    private func startEditingProfileName() {
        draftProfileName = store.preferences.userName
        isEditingProfileName = true
    }

    private func saveProfileName() {
        store.updateUserName(draftProfileName)
        draftProfileName = store.preferences.userName
        isEditingProfileName = false
    }

    private func cancelEditingProfileName() {
        draftProfileName = store.preferences.userName
        isEditingProfileName = false
    }

    private func downloadMissingAudio() {
        let items = pendingAudioItems
        guard !items.isEmpty else {
            showDataStatus(AwradLocalizer.localized("All audio files downloaded", language: language))
            return
        }

        isDownloadingAudioLibrary = true
        audioDownloadCompletedCount = 0
        audioDownloadTotalCount = items.count

        Task {
            var failedCount = 0
            for item in items {
                guard let url = item.audioURL else { continue }
                do {
                    let fileName = try await services.audio.downloadAudio(
                        from: url,
                        suggestedFileName: item.audioFileName
                    )
                    store.markDhikrAudioDownloaded(dhikrID: item.id, fileName: fileName)
                } catch {
                    failedCount += 1
                }
                audioDownloadCompletedCount += 1
            }

            isDownloadingAudioLibrary = false
            if failedCount == 0 {
                showDataStatus(AwradLocalizer.localized("Audio downloads complete.", language: language))
            } else {
                showDataStatus(AwradLocalizer.format("%d audio downloads failed", language: language, failedCount))
            }
        }
    }

    private func rescheduleReminderIfNeeded() {
        guard store.preferences.dailyReminderEnabled else { return }
        Task {
            await services.notifications.scheduleDailyReminder(
                hour: store.preferences.reminderHour,
                minute: store.preferences.reminderMinute,
                language: store.preferences.appLanguage
            )
        }
    }

    private func rescheduleAllReminders() {
        Task {
            let inputs = ReminderScheduleBuilder.goalInputs(
                goals: store.goals,
                dhikrs: store.dhikrs,
                preferences: store.preferences,
                prayerTimeService: services.prayerTimes
            )
            await services.notifications.refreshScheduledReminders(
                goalInputs: inputs,
                dailyReminder: (
                    enabled: store.preferences.dailyReminderEnabled,
                    hour: store.preferences.reminderHour,
                    minute: store.preferences.reminderMinute,
                    language: store.preferences.appLanguage
                )
            )
        }
    }

    private func exportBackup() {
        do {
            backupDocument = AwradBackupDocument(data: try store.exportBackupData())
            isExportingBackup = true
        } catch {
            showDataStatus(error.localizedDescription)
        }
    }

    private func importBackup(from url: URL) {
        do {
            let didAccess = url.startAccessingSecurityScopedResource()
            defer {
                if didAccess {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            let data = try Data(contentsOf: url)
            try store.importBackupData(data)
            rescheduleAllReminders()
            showDataStatus(AwradLocalizer.localized("Backup imported.", language: language))
        } catch {
            showDataStatus(error.localizedDescription)
        }
    }

    private func performDestructiveAction(_ action: SettingsDestructiveAction) {
        destructiveAction = nil
        switch action {
        case .resetProgress:
            store.resetProgress()
            rescheduleAllReminders()
            showDataStatus(AwradLocalizer.localized("Progress reset.", language: language))
        case .deleteAllGoals:
            store.deleteAllGoals()
            Task {
                await services.notifications.cancelAllGoalReminders()
            }
            showDataStatus(AwradLocalizer.localized("All goals deleted.", language: language))
        }
    }

    #if DEBUG
    private func sendTestNotificationNow() {
        Task {
            let didSend = await services.notifications.deliverDebugNotificationNow(body: debugNotificationBody())
            showDataStatus(AwradLocalizer.localized(
                didSend ? "Test notification sent." : "Test notification could not be scheduled.",
                language: language
            ))
        }
    }

    private func scheduleTestNotificationIn30Seconds() {
        Task {
            let didSchedule = await services.notifications.scheduleDebugNotification(after: 30, body: debugNotificationBody())
            showDataStatus(AwradLocalizer.localized(
                didSchedule ? "Test notification scheduled in 30 seconds." : "Test notification could not be scheduled.",
                language: language
            ))
        }
    }

    private func rescheduleAllRemindersFromDebug() {
        rescheduleAllReminders()
        showDataStatus(AwradLocalizer.localized("Reminders rescheduled.", language: language))
    }

    private func debugNotificationBody() -> String {
        if let goal = store.goals.first(where: { $0.reminders.contains(where: \.enabled) }) {
            return AwradLocalizer.format("Time for your %@ goal.", language: language, store.title(for: goal))
        }
        return AwradLocalizer.localized("Your daily remembrance is ready.", language: language)
    }
    #endif

    private func showDataStatus(_ message: String) {
        dataMessage = message
        showDataMessage = true
    }
}

private struct ProfileNameEditor: View {
    let name: String
    @Binding var isEditing: Bool
    @Binding var draftName: String
    let onEdit: () -> Void
    let onSave: () -> Void
    let onCancel: () -> Void
    @FocusState private var isNameFocused: Bool

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if isEditing {
                editContent
            } else {
                displayContent
            }
        }
        .onChange(of: isEditing) { _, isEditing in
            isNameFocused = isEditing
        }
    }

    private var displayContent: some View {
        Button(action: onEdit) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Name")
                        .font(AwradTheme.bodyFont(.caption))
                        .foregroundStyle(.secondary)
                    if trimmedName.isEmpty {
                        Text("Not set")
                            .foregroundStyle(.secondary)
                    } else {
                        Text(trimmedName)
                            .foregroundStyle(.primary)
                    }
                }
                Spacer()
                Label("Edit", systemImage: "pencil")
                    .font(AwradTheme.bodyFont(.subheadline, weight: .semibold))
                    .foregroundStyle(AwradTheme.sage)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("settings-profile-edit-button")
    }

    private var editContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("Name", text: $draftName)
                .textContentType(.name)
                .submitLabel(.done)
                .focused($isNameFocused)
                .onSubmit(onSave)
                .accessibilityLabel(Text("Name"))
                .accessibilityIdentifier("settings-profile-name-field")

            HStack(spacing: 12) {
                Button(action: onCancel) {
                    Label("Cancel", systemImage: "xmark")
                }
                .buttonStyle(.borderless)
                .accessibilityIdentifier("settings-profile-cancel-button")

                Spacer()

                Button(action: onSave) {
                    Label("Save", systemImage: "checkmark")
                }
                .buttonStyle(.borderless)
                .fontWeight(.semibold)
                .accessibilityIdentifier("settings-profile-save-button")
            }
        }
    }
}

#if DEBUG
private struct DebugSettingsSection: View {
    let onTestNow: () -> Void
    let onTestIn30Seconds: () -> Void
    let onRescheduleAll: () -> Void

    var body: some View {
        Section("Debug") {
            Button(action: onTestNow) {
                Label("Test notification now", systemImage: "bell.badge")
            }

            Button(action: onTestIn30Seconds) {
                Label("Test notification in 30s", systemImage: "timer")
            }

            Button(action: onRescheduleAll) {
                Label("Reschedule all reminders", systemImage: "arrow.clockwise.circle")
            }
        }
    }
}
#endif

private enum SettingsDestructiveAction: Identifiable {
    case resetProgress
    case deleteAllGoals

    var id: Self { self }

    var titleKey: String {
        switch self {
        case .resetProgress: "Reset Progress?"
        case .deleteAllGoals: "Delete All Goals?"
        }
    }

    var messageKey: String {
        switch self {
        case .resetProgress:
            "Count history will be erased and all goals will be restored to active with zero completed counts. This cannot be undone."
        case .deleteAllGoals:
            "All goals, slots, reminders, and count history will be permanently deleted. This cannot be undone."
        }
    }

    var confirmTitleKey: String {
        switch self {
        case .resetProgress: "Reset progress"
        case .deleteAllGoals: "Delete all goals"
        }
    }
}

struct AwradBackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    var data: Data

    init(data: Data = Data()) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
