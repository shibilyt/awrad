import SwiftUI

struct GoalReminderDraft: Identifiable, Hashable {
    var id: AwradID
    var reminderType: ReminderType
    var slotID: AwradID?
    var hour: Int
    var minute: Int
    var offsetMinutes: Int
    var enabled: Bool

    init(reminder: GoalReminder) {
        id = reminder.id
        reminderType = reminder.reminderType
        slotID = reminder.slotID
        hour = reminder.hour ?? 8
        minute = reminder.minute ?? 0
        offsetMinutes = reminder.offsetMinutes ?? 10
        enabled = reminder.enabled
    }

    init(
        id: AwradID = UUID(),
        reminderType: ReminderType,
        slotID: AwradID? = nil,
        hour: Int = 8,
        minute: Int = 0,
        offsetMinutes: Int = 10,
        enabled: Bool = true
    ) {
        self.id = id
        self.reminderType = reminderType
        self.slotID = slotID
        self.hour = hour
        self.minute = minute
        self.offsetMinutes = offsetMinutes
        self.enabled = enabled
    }

    func reminder(goalID: AwradID, sortOrder: Int) -> GoalReminder {
        GoalReminder(
            id: id,
            goalID: goalID,
            slotID: reminderType == .fixedTime ? nil : slotID,
            reminderType: reminderType,
            hour: reminderType == .fixedTime ? hour : nil,
            minute: reminderType == .fixedTime ? minute : nil,
            offsetMinutes: reminderType == .prayerOffset ? offsetMinutes : (reminderType == .timeWindowStart ? 0 : nil),
            enabled: enabled,
            sortOrder: sortOrder
        )
    }
}

struct EditGoalRemindersView: View {
    @Environment(AwradStore.self) private var store
    @Environment(AppServices.self) private var services
    @Environment(\.dismiss) private var dismiss

    let goalID: AwradID

    @State private var drafts: [GoalReminderDraft] = []
    @State private var originalDrafts: [GoalReminderDraft] = []
    @State private var didLoad = false
    @State private var saveError: String?
    @State private var isSaving = false

    private var goal: Goal? { store.goal(id: goalID) }
    private var language: AppLanguage { store.preferences.appLanguage }
    private var prayerSlots: [GoalSlot] {
        goal?.activeSlots.filter { $0.slotType == .prayer }.sorted { $0.sortOrder < $1.sortOrder } ?? []
    }
    private var windowSlots: [GoalSlot] {
        goal?.activeSlots.filter { $0.slotType == .timeWindow }.sorted { $0.sortOrder < $1.sortOrder } ?? []
    }
    private var isDirty: Bool { drafts != originalDrafts }
    private var validationMessage: String? {
        let keys = drafts.map(duplicateKey)
        if Set(keys).count != keys.count { return "Each reminder must use a unique time or session." }
        for draft in drafts {
            switch draft.reminderType {
            case .fixedTime:
                if !(0...23).contains(draft.hour) || !(0...59).contains(draft.minute) {
                    return "Choose a valid reminder time."
                }
            case .prayerOffset:
                if !prayerSlots.contains(where: { $0.id == draft.slotID }) || draft.offsetMinutes < 0 {
                    return "Choose an active prayer session and a valid offset."
                }
            case .timeWindowStart:
                if !windowSlots.contains(where: { $0.id == draft.slotID }) {
                    return "Choose an active time-window session."
                }
            }
        }
        return nil
    }

    var body: some View {
        Group {
            if let goal {
                content(goal)
            } else {
                ContentUnavailableView(
                    "Goal not found",
                    systemImage: "target",
                    description: Text("This goal may have been removed.")
                )
            }
        }
        .background(AwradTheme.background)
        .navigationTitle("Edit reminders")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: save)
                    .fontWeight(.semibold)
                    .disabled(!isDirty || validationMessage != nil || isSaving)
            }
        }
        .task(id: goal?.id) { hydrateIfNeeded() }
        .alert("Couldn’t save changes", isPresented: Binding(
            get: { saveError != nil },
            set: { if !$0 { saveError = nil } }
        )) {
            Button("Retry", action: save)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(saveError ?? "")
        }
    }

    private func content(_ goal: Goal) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(store.title(for: goal))
                        .font(AwradTheme.displayFont(26, weight: .bold))
                    Text("Reminders follow this goal’s active sessions and schedule.")
                        .font(AwradTheme.bodyFont(.subheadline))
                        .foregroundStyle(.secondary)
                }

                if drafts.isEmpty {
                    AwradCard(padding: 18) {
                        ContentUnavailableView(
                            "No reminders",
                            systemImage: "bell.slash",
                            description: Text("Add a fixed time or a reminder linked to a session.")
                        )
                    }
                } else {
                    ForEach($drafts) { $draft in
                        GoalReminderEditorCard(
                            draft: $draft,
                            prayerSlots: prayerSlots,
                            windowSlots: windowSlots,
                            language: language,
                            onTypeChanged: { normalizeSlot(for: draft.id) },
                            onDelete: { drafts.removeAll { $0.id == draft.id } }
                        )
                    }
                }

                addReminderMenu

                if let validationMessage {
                    Label(LocalizedStringKey(validationMessage), systemImage: "exclamationmark.triangle.fill")
                        .font(AwradTheme.bodyFont(.caption))
                        .foregroundStyle(.red)
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
                }
            }
            .padding(20)
            .padding(.bottom, 40)
        }
    }

    private var addReminderMenu: some View {
        Menu {
            Button("Fixed time", systemImage: "clock") {
                drafts.append(GoalReminderDraft(reminderType: .fixedTime))
            }
            if let slot = prayerSlots.first {
                Button("Prayer session", systemImage: "sun.horizon") {
                    drafts.append(GoalReminderDraft(reminderType: .prayerOffset, slotID: slot.id))
                }
            }
            if let slot = windowSlots.first {
                Button("Session start", systemImage: "calendar.badge.clock") {
                    drafts.append(GoalReminderDraft(reminderType: .timeWindowStart, slotID: slot.id, offsetMinutes: 0))
                }
            }
        } label: {
            Label("Add reminder", systemImage: "plus.circle.fill")
                .font(AwradTheme.bodyFont(.headline, weight: .semibold))
                .frame(maxWidth: .infinity, minHeight: 50)
                .awradGlassSurface(cornerRadius: 18, tint: AwradTheme.mint.opacity(0.52), interactive: true)
        }
        .buttonStyle(.plain)
        .foregroundStyle(AwradTheme.sageDark)
    }

    private func hydrateIfNeeded() {
        guard !didLoad, let goal else { return }
        drafts = goal.reminders.sorted { $0.sortOrder < $1.sortOrder }.map { GoalReminderDraft(reminder: $0) }
        originalDrafts = drafts
        didLoad = true
    }

    private func normalizeSlot(for id: AwradID) {
        guard let index = drafts.firstIndex(where: { $0.id == id }) else { return }
        switch drafts[index].reminderType {
        case .fixedTime:
            drafts[index].slotID = nil
        case .prayerOffset:
            if !prayerSlots.contains(where: { $0.id == drafts[index].slotID }) {
                drafts[index].slotID = prayerSlots.first?.id
            }
        case .timeWindowStart:
            if !windowSlots.contains(where: { $0.id == drafts[index].slotID }) {
                drafts[index].slotID = windowSlots.first?.id
            }
            drafts[index].offsetMinutes = 0
        }
    }

    private func duplicateKey(_ draft: GoalReminderDraft) -> String {
        switch draft.reminderType {
        case .fixedTime:
            "fixed|\(draft.hour)|\(draft.minute)"
        case .prayerOffset:
            "prayer|\(draft.slotID?.uuidString ?? "")|\(draft.offsetMinutes)"
        case .timeWindowStart:
            "window|\(draft.slotID?.uuidString ?? "")"
        }
    }

    private func save() {
        guard !isSaving else { return }
        guard let goal, validationMessage == nil else {
            saveError = validationMessage ?? "Review the reminders and try again."
            return
        }
        let reminders = drafts.enumerated().map { index, draft in
            draft.reminder(goalID: goal.id, sortOrder: index)
        }
        guard let updated = store.updateGoalReminders(goalID: goal.id, reminders: reminders) else {
            saveError = "Review the reminders and try again."
            return
        }
        let previousGoal = goal
        isSaving = true
        Task {
            let result = await reschedule(updated)
            isSaving = false
            if result.succeeded {
                dismiss()
            } else {
                if let restored = store.restoreGoal(previousGoal) {
                    _ = await reschedule(restored)
                }
                saveError = result.localizedFailureMessage(language: language)
            }
        }
    }

    private func reschedule(_ goal: Goal) async -> NotificationSchedulingResult {
        let prayerTimes = ReminderScheduleBuilder.prayerSummaries(
            for: goal,
            preferences: store.preferences,
            prayerTimeService: services.prayerTimes
        )
        return await services.notifications.scheduleGoalReminders(
            for: goal,
            dhikrTitle: store.title(for: goal),
            language: language,
            prayerTimes: prayerTimes
        )
    }
}

private struct GoalReminderEditorCard: View {
    @Binding var draft: GoalReminderDraft
    let prayerSlots: [GoalSlot]
    let windowSlots: [GoalSlot]
    let language: AppLanguage
    let onTypeChanged: () -> Void
    let onDelete: () -> Void

    var body: some View {
        AwradCard(padding: 16) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Toggle("Enabled", isOn: $draft.enabled)
                        .font(AwradTheme.bodyFont(.headline, weight: .semibold))
                    Button(role: .destructive, action: onDelete) {
                        Image(systemName: "trash")
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Delete reminder")
                }

                Picker("Reminder type", selection: $draft.reminderType) {
                    Text("Fixed time").tag(ReminderType.fixedTime)
                    if !prayerSlots.isEmpty { Text("Prayer session").tag(ReminderType.prayerOffset) }
                    if !windowSlots.isEmpty { Text("Session start").tag(ReminderType.timeWindowStart) }
                }
                .pickerStyle(.menu)
                .onChange(of: draft.reminderType) { _, _ in onTypeChanged() }

                switch draft.reminderType {
                case .fixedTime:
                    DatePicker("Time", selection: fixedTime, displayedComponents: .hourAndMinute)
                case .prayerOffset:
                    Picker("Session", selection: $draft.slotID) {
                        ForEach(prayerSlots) { slot in
                            Text(slot.displayLabel(language: language)).tag(Optional(slot.id))
                        }
                    }
                    Stepper(value: $draft.offsetMinutes, in: 0...180, step: 5) {
                        Text("\(draft.offsetMinutes) minutes before")
                    }
                case .timeWindowStart:
                    Picker("Session", selection: $draft.slotID) {
                        ForEach(windowSlots) { slot in
                            Text(slot.displayLabel(language: language)).tag(Optional(slot.id))
                        }
                    }
                    Text("Delivered when the selected session begins.")
                        .font(AwradTheme.bodyFont(.caption))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var fixedTime: Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(from: DateComponents(hour: draft.hour, minute: draft.minute)) ?? Date()
            },
            set: { value in
                let components = Calendar.current.dateComponents([.hour, .minute], from: value)
                draft.hour = components.hour ?? 8
                draft.minute = components.minute ?? 0
            }
        )
    }
}
