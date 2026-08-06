import SwiftUI
import UIKit
import UniformTypeIdentifiers

enum SettingsParitySection: String, CaseIterable {
    case profile = "Profile"
    case appearance = "Appearance"
    case countingPreferences = "Counting Preferences"
    case dateAndCalendar = "Date & Calendar"
    case notifications = "Notifications"
    case prayerTimes = "Prayer Times"
    case audioLibrary = "Audio Library"
    case language = "Language"
    case dataManagement = "Data Management"
    case about = "About"

    var title: LocalizedStringKey { LocalizedStringKey(rawValue) }
}

struct SettingsView: View {
    @Environment(AwradStore.self) private var store
    @Environment(AppServices.self) private var services
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
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
    @State private var notificationAuthorizationState: NotificationAuthorizationState = .notDetermined
    @State private var notificationRetry: (() -> Void)?
    @State private var syncHealth: ProgressSyncHealth?
    @State private var syncConflicts: [ProgressSyncConflict] = []
    private var language: AppLanguage { store.preferences.appLanguage }
    private var audioItems: [Dhikr] { store.dhikrs.filter { $0.audioURL != nil } }
    private var pendingAudioItems: [Dhikr] { audioItems.filter { !$0.isDownloaded } }
    private var audioSummary: AudioLibrarySummary { AudioLibraryCalculator.summary(for: store.dhikrs) }

    var body: some View {
        Form {
            Group {
                Section(SettingsParitySection.profile.title) {
                ProfileNameEditor(
                    name: store.preferences.userName,
                    isEditing: $isEditingProfileName,
                    draftName: $draftProfileName,
                    onEdit: startEditingProfileName,
                    onSave: saveProfileName,
                    onCancel: cancelEditingProfileName
                )
            }

            Section(SettingsParitySection.appearance.title) {
                AwradBottomSheetPicker(
                    title: "App theme",
                    selection: preferenceBinding(\.colorSchemeMode),
                    options: ColorSchemeMode.allCases
                ) { $0.title }
            }

            Section(SettingsParitySection.countingPreferences.title) {
                Toggle(isOn: preferenceBinding(\.vibrateOnCount)) {
                    SettingsPreferenceLabel(
                        title: "Haptic feedback",
                        subtitle: "Vibrate gently with each count."
                    )
                }
                    .tint(AwradTheme.sage)
                Toggle(isOn: preferenceBinding(\.keepScreenOn)) {
                    SettingsPreferenceLabel(
                        title: "Keep screen awake",
                        subtitle: "Prevent the display from sleeping while counting."
                    )
                }
                    .tint(AwradTheme.sage)
                Toggle(isOn: preferenceBinding(\.soundOnCount)) {
                    SettingsPreferenceLabel(
                        title: "Sound on count",
                        subtitle: "Play a subtle sound for each count."
                    )
                }
                    .tint(AwradTheme.sage)
            }

            Section(SettingsParitySection.dateAndCalendar.title) {
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

            Section(SettingsParitySection.notifications.title) {
                Toggle(isOn: dailyReminderBinding) {
                    SettingsPreferenceLabel(
                        title: "Daily reminder",
                        subtitle: "Receive a reminder at your chosen time."
                    )
                }
                    .tint(AwradTheme.sage)

                if store.preferences.dailyReminderEnabled {
                    DatePicker(
                        "Reminder time",
                        selection: reminderTimeBinding,
                        displayedComponents: .hourAndMinute
                    )
                }

                Toggle(isOn: dailyRemembranceBinding) {
                    SettingsPreferenceLabel(
                        title: "Daily remembrance",
                        subtitle: "A devotional reminder every day at 9:00 AM."
                    )
                }
                    .tint(AwradTheme.sage)

                Toggle(isOn: urgencyRemindersBinding) {
                    SettingsPreferenceLabel(
                        title: "urgency.reminders.title",
                        subtitle: "urgency.reminders.subtitle"
                    )
                }
                    .tint(AwradTheme.sage)

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

                Button(action: openNotificationSettings) {
                    HStack(spacing: 12) {
                        Label("Notification permission", systemImage: "bell.badge")
                        Spacer()
                        Text(notificationAuthorizationTitle)
                            .font(AwradTheme.bodyFont(.caption, weight: .bold))
                            .foregroundStyle(notificationAuthorizationState == .authorized ? AwradTheme.sage : .red)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                (notificationAuthorizationState == .authorized ? AwradTheme.sage : Color.red).opacity(0.12),
                                in: Capsule()
                            )
                        Image(systemName: "arrow.up.forward.app")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section(SettingsParitySection.prayerTimes.title) {
                PrayerLocationSetupView(
                    mode: .displayWithChange,
                    onSelect: rescheduleAllReminders
                )

                AwradBottomSheetPicker(
                    title: "Calculation method",
                    selection: preferenceBinding(\.calculationMethod, sideEffect: rescheduleAllReminders),
                    options: PrayerCalculationMethod.allCases
                ) { $0.title }
                AwradBottomSheetPicker(
                    title: "Madhab",
                    selection: preferenceBinding(\.madhab, sideEffect: rescheduleAllReminders),
                    options: PrayerMadhab.allCases
                ) { $0.title }
            }

            Section(SettingsParitySection.audioLibrary.title) {
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

            Section(SettingsParitySection.language.title) {
                AwradBottomSheetPicker(
                    title: "Language",
                    selection: preferenceBinding(\.appLanguage, sideEffect: rescheduleAllReminders),
                    options: AppLanguage.allCases
                ) { $0.title }
            }

            Section(SettingsParitySection.dataManagement.title) {
                Button {
                    Task {
                        await services.progressSync.synchronize(store: store)
                        refreshSyncHealth()
                    }
                } label: {
                    Label("Sync progress now", systemImage: "arrow.triangle.2.circlepath")
                }
                if let syncHealth {
                    Text(syncStatusText(syncHealth))
                        .font(AwradTheme.bodyFont(.footnote))
                        .foregroundStyle(syncHealth.lastError == nil ? .secondary : Color.red)
                }
                ForEach(syncConflicts) { conflict in
                    VStack(alignment: .leading, spacing: 8) {
                        Text("A synced change needs attention.")
                            .font(AwradTheme.bodyFont(.footnote))
                        HStack {
                            if conflict.entityType != nil, conflict.status == "conflict" {
                                Button("Use cloud version") {
                                    resolveSyncConflict(conflict, keepDevice: false)
                                }
                                if conflict.commandType == "entity_upsert" {
                                    Button("Keep device version") {
                                        resolveSyncConflict(conflict, keepDevice: true)
                                    }
                                }
                            } else {
                                Button("Discard failed change") {
                                    discardSyncConflict(conflict)
                                }
                            }
                        }
                        .buttonStyle(.borderless)
                    }
                }

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

                Section(SettingsParitySection.about.title) {
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
            .listRowBackground(AwradTheme.surface)
        }
        .scrollContentBackground(.hidden)
        .background(AwradTheme.background)
        .navigationTitle("Settings")
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                settingsBackButton
            }
        }
        .task {
            await refreshNotificationAuthorization()
            refreshSyncHealth()
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task { await refreshNotificationAuthorization() }
        }
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
            if notificationRetry != nil {
                Button("Retry") {
                    let retry = notificationRetry
                    notificationRetry = nil
                    retry?()
                }
            }
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

    @ViewBuilder
    private var settingsBackButton: some View {
        if #available(iOS 26.0, *) {
            backButton
                .buttonStyle(.glass)
        } else {
            backButton
                .buttonStyle(.plain)
                .background(.ultraThinMaterial, in: Circle())
                .overlay {
                    Circle()
                        .stroke(.white.opacity(0.16), lineWidth: 0.75)
                }
                .shadow(color: .black.opacity(0.12), radius: 8, y: 4)
        }
    }

    private var backButton: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "chevron.backward")
                .font(AwradTheme.bodyFont(.headline, weight: .semibold))
                .foregroundStyle(AwradTheme.sage)
                .frame(width: 38, height: 38)
                .contentShape(Circle())
        }
        .accessibilityLabel("Back")
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
                let hour = components.hour ?? store.preferences.reminderHour
                let minute = components.minute ?? store.preferences.reminderMinute
                updateReminderTime(hour: hour, minute: minute)
            }
        )
    }

    private var dailyReminderBinding: Binding<Bool> {
        Binding(
            get: { store.preferences.dailyReminderEnabled },
            set: setDailyReminderEnabled
        )
    }

    private var dailyRemembranceBinding: Binding<Bool> {
        Binding(
            get: { store.preferences.dailyRemembranceEnabled },
            set: setDailyRemembranceEnabled
        )
    }

    private var urgencyRemindersBinding: Binding<Bool> {
        Binding(get: { store.preferences.urgencyRemindersEnabled }, set: setUrgencyRemindersEnabled)
    }

    private var notificationAuthorizationTitle: String {
        switch notificationAuthorizationState {
        case .notDetermined:
            AwradLocalizer.localized("Not requested", language: language)
        case .denied:
            AwradLocalizer.localized("Disabled", language: language)
        case .authorized:
            AwradLocalizer.localized("Allowed", language: language)
        }
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

    private func preferenceBinding<Value: Equatable>(
        _ keyPath: WritableKeyPath<UserPreferences, Value>,
        sideEffect: (() -> Void)? = nil
    ) -> Binding<Value> {
        Binding(
            get: { store.preferences[keyPath: keyPath] },
            set: { value in
                guard store.preferences[keyPath: keyPath] != value else { return }
                guard store.updatePreferences({ preferences in
                    preferences[keyPath: keyPath] = value
                }) else { return }
                sideEffect?()
            }
        )
    }

    private func setDailyReminderEnabled(_ enabled: Bool) {
        guard enabled != store.preferences.dailyReminderEnabled else { return }
        let previous = store.preferences.dailyReminderEnabled
        guard store.updatePreferences({ $0.dailyReminderEnabled = enabled }) else { return }
        Task {
            let result = await reconcileAllReminders()
            if !result.succeeded {
                _ = store.updatePreferences { $0.dailyReminderEnabled = previous }
                _ = await reconcileAllReminders()
                showNotificationFailure(result) { setDailyReminderEnabled(enabled) }
            }
            await refreshNotificationAuthorization()
        }
    }

    private func setDailyRemembranceEnabled(_ enabled: Bool) {
        guard enabled != store.preferences.dailyRemembranceEnabled else { return }
        let previous = store.preferences.dailyRemembranceEnabled
        guard store.updatePreferences({ $0.dailyRemembranceEnabled = enabled }) else { return }
        Task {
            let result = await reconcileAllReminders()
            if !result.succeeded {
                _ = store.updatePreferences { $0.dailyRemembranceEnabled = previous }
                _ = await reconcileAllReminders()
                showNotificationFailure(result) { setDailyRemembranceEnabled(enabled) }
            }
            await refreshNotificationAuthorization()
        }
    }

    private func setUrgencyRemindersEnabled(_ enabled: Bool) {
        if enabled == store.preferences.urgencyRemindersEnabled {
            guard enabled else { return }
            retryUrgencyReminders()
            return
        }
        guard store.updatePreferences({ $0.urgencyRemindersEnabled = enabled }) else { return }
        Task {
            let result = await services.refreshNotifications(
                store: store,
                change: .init(goalIDs: Set(store.goals.map(\.id)), reason: .preferenceMutation),
                requestUrgencyAuthorization: enabled
            )
            await refreshNotificationAuthorization()
            if !result.succeeded {
                showNotificationFailure(result, retry: retryUrgencyReminders)
            }
        }
    }

    private func retryUrgencyReminders() {
        Task {
            let result = await services.refreshNotifications(
                store: store,
                change: .init(goalIDs: Set(store.goals.map(\.id)), reason: .preferenceMutation),
                requestUrgencyAuthorization: true
            )
            await refreshNotificationAuthorization()
            if !result.succeeded {
                showNotificationFailure(result, retry: retryUrgencyReminders)
            }
        }
    }

    private func updateReminderTime(hour: Int, minute: Int) {
        let previousHour = store.preferences.reminderHour
        let previousMinute = store.preferences.reminderMinute
        guard hour != previousHour || minute != previousMinute else { return }
        guard store.updatePreferences({ preferences in
            preferences.reminderHour = hour
            preferences.reminderMinute = minute
        }) else { return }
        Task {
            let result = await reconcileAllReminders()
            guard !result.succeeded else { return }
            _ = store.updatePreferences { preferences in
                preferences.reminderHour = previousHour
                preferences.reminderMinute = previousMinute
            }
            _ = await reconcileAllReminders()
            showNotificationFailure(result) { updateReminderTime(hour: hour, minute: minute) }
        }
    }

    private func refreshNotificationAuthorization() async {
        notificationAuthorizationState = await services.notifications.authorizationState()
    }

    private func openNotificationSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        openURL(url)
    }

    private func refreshSyncHealth() {
        syncHealth = try? services.progressSync.health()
        syncConflicts = (try? services.progressSync.conflicts()) ?? []
    }

    private func resolveSyncConflict(_ conflict: ProgressSyncConflict, keepDevice: Bool) {
        Task {
            if keepDevice {
                await services.progressSync.keepDeviceVersion(commandID: conflict.commandID, store: store)
            } else {
                await services.progressSync.acceptCloud(commandID: conflict.commandID, store: store)
            }
            refreshSyncHealth()
        }
    }

    private func discardSyncConflict(_ conflict: ProgressSyncConflict) {
        Task {
            await services.progressSync.discardTerminalChange(commandID: conflict.commandID, store: store)
            refreshSyncHealth()
        }
    }

    private func syncStatusText(_ health: ProgressSyncHealth) -> String {
        if health.lastError != nil {
            return AwradLocalizer.localized(
                "The last sync did not finish. Tap to retry.", language: language
            )
        }
        if health.conflicts > 0 || health.failedCommands > 0 {
            return AwradLocalizer.format(
                "%lld conflicts and %lld failed changes need attention.",
                language: language,
                Int64(health.conflicts), Int64(health.failedCommands)
            )
        }
        if health.pendingCommands > 0 {
            return AwradLocalizer.format(
                "%lld changes waiting to sync.", language: language,
                Int64(health.pendingCommands)
            )
        }
        return AwradLocalizer.localized(
            health.lastSyncAt == nil
                ? "Progress has not synced yet."
                : "Cloud progress is up to date.",
            language: language
        )
    }

    private func startEditingProfileName() {
        draftProfileName = store.preferences.userName
        isEditingProfileName = true
    }

    private func saveProfileName() {
        guard store.updateUserName(draftProfileName) else { return }
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
                    if !store.markDhikrAudioDownloaded(dhikrID: item.id, fileName: fileName) {
                        failedCount += 1
                    }
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

    private func rescheduleAllReminders() {
        Task {
            let result = await reconcileAllReminders()
            if !result.succeeded {
                showNotificationFailure(result, retry: rescheduleAllReminders)
            }
        }
    }

    private func reconcileAllReminders() async -> NotificationSchedulingResult {
        await services.refreshNotifications(store: store)
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
            Task {
                let result = await reconcileAllReminders()
                if result.succeeded {
                    showDataStatus(AwradLocalizer.localized("Backup imported.", language: language))
                } else {
                    showNotificationFailure(result, retry: rescheduleAllReminders)
                }
            }
        } catch {
            showDataStatus(error.localizedDescription)
        }
    }

    private func performDestructiveAction(_ action: SettingsDestructiveAction) {
        destructiveAction = nil
        switch action {
        case .resetProgress:
            guard store.resetProgress() else { return }
            Task {
                let result = await reconcileAllReminders()
                if result.succeeded {
                    showDataStatus(AwradLocalizer.localized("Progress reset.", language: language))
                } else {
                    showNotificationFailure(result, retry: rescheduleAllReminders)
                }
            }
        case .deleteAllGoals:
            guard store.deleteAllGoals() else { return }
            Task {
                _ = await reconcileAllReminders()
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
        Task {
            let result = await reconcileAllReminders()
            if result.succeeded {
                showDataStatus(AwradLocalizer.localized("Reminders rescheduled.", language: language))
            } else {
                showNotificationFailure(result, retry: rescheduleAllRemindersFromDebug)
            }
        }
    }

    private func debugNotificationBody() -> String {
        if let goal = store.goals.first(where: { $0.reminders.contains(where: \.enabled) }) {
            return AwradLocalizer.format("Time for your %@ goal.", language: language, store.title(for: goal))
        }
        return AwradLocalizer.localized("Your daily remembrance is ready.", language: language)
    }
    #endif

    private func showNotificationFailure(
        _ result: NotificationSchedulingResult,
        retry: @escaping () -> Void
    ) {
        guard let message = result.localizedFailureMessage(language: language) else { return }
        showDataStatus(message, retry: retry)
    }

    private func showDataStatus(_ message: String, retry: (() -> Void)? = nil) {
        dataMessage = message
        notificationRetry = retry
        showDataMessage = true
    }
}

private struct SettingsPreferenceLabel: View {
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(AwradTheme.bodyFont(.body, weight: .medium))
            Text(subtitle)
                .font(AwradTheme.bodyFont(.footnote))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
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
