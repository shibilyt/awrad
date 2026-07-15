import SwiftUI

struct GoalScheduleSlotDraft: Identifiable, Hashable {
    var id: AwradID
    var slotType: GoalSlotType
    var prayerName: Prayer?
    var prayerRelation: PrayerRelation?
    var label: String
    var beforeLeadMinutes: Int
    var startMinute: Int
    var endMinute: Int

    init(slot: GoalSlot) {
        id = slot.id
        slotType = slot.slotType
        prayerName = slot.prayerName
        prayerRelation = slot.prayerRelation
        label = slot.label ?? ""
        beforeLeadMinutes = slot.startLeadMinutesOverride ?? 30
        startMinute = slot.startMinute ?? 8 * 60
        endMinute = slot.endMinute ?? 9 * 60
    }

    init(
        id: AwradID = UUID(),
        slotType: GoalSlotType,
        prayerName: Prayer? = nil,
        prayerRelation: PrayerRelation? = nil,
        label: String = "",
        beforeLeadMinutes: Int = 30,
        startMinute: Int = 8 * 60,
        endMinute: Int = 9 * 60
    ) {
        self.id = id
        self.slotType = slotType
        self.prayerName = prayerName
        self.prayerRelation = prayerRelation
        self.label = label
        self.beforeLeadMinutes = beforeLeadMinutes
        self.startMinute = startMinute
        self.endMinute = endMinute
    }

    var slot: GoalSlot {
        GoalSlot(
            id: id,
            slotType: slotType,
            prayerName: slotType == .prayer ? prayerName : nil,
            prayerRelation: slotType == .prayer ? prayerRelation : nil,
            startMinute: slotType == .timeWindow ? startMinute : nil,
            endMinute: slotType == .timeWindow ? endMinute : nil,
            startLeadMinutesOverride: slotType == .prayer && prayerRelation == .before ? beforeLeadMinutes : nil,
            label: label.trimmedOrNil
        )
    }
}

struct GoalScheduleDraft: Hashable {
    var frequency: RecurrenceFrequency
    var calendar: CalendarSystem
    var intervalDaysText: String
    var yearlyMonth: Int
    var selectedWeekdays: Set<Int>
    var monthDaysText: String
    var specificDatesText: String
    var seasonTemplate: SeasonTemplateCode
    var timingMode: GoalTimingMode
    var slots: [GoalScheduleSlotDraft]

    init(goal: Goal) {
        let recurrence = goal.recurrence
        frequency = recurrence.frequency
        calendar = recurrence.calendar
        intervalDaysText = recurrence.intervalDays.map(String.init) ?? "1"
        yearlyMonth = recurrence.month ?? 1
        selectedWeekdays = recurrence.weekdays
        monthDaysText = recurrence.monthDays.sorted().map(String.init).joined(separator: ", ")
        specificDatesText = recurrence.specificDates.compactMap(\.date).sorted().joined(separator: "\n")
        seasonTemplate = recurrence.seasonCode.flatMap(SeasonTemplateCode.init(rawValue:)) ?? .ramadan
        slots = goal.activeSlots.sorted { $0.sortOrder < $1.sortOrder }.map { GoalScheduleSlotDraft(slot: $0) }

        if slots.allSatisfy({ $0.slotType == .prayer }) {
            timingMode = .prayerBased
        } else if slots.allSatisfy({ $0.slotType == .timeWindow }) {
            timingMode = .timeWindow
        } else {
            timingMode = .anytime
        }
        if slots.isEmpty { applyTimingMode(.anytime) }
    }

    var recurrence: GoalRecurrence? {
        switch frequency {
        case .daily:
            return GoalRecurrence(frequency: .daily)
        case .weekly:
            guard !selectedWeekdays.isEmpty else { return nil }
            return GoalRecurrence(frequency: .weekly, weekdays: selectedWeekdays)
        case .monthly:
            let days = parsedIntegers(monthDaysText, range: 1...31)
            guard !days.isEmpty else { return nil }
            return GoalRecurrence(frequency: .monthly, calendar: calendar, monthDays: days)
        case .interval:
            guard let interval = Int(intervalDaysText), interval > 0 else { return nil }
            return GoalRecurrence(frequency: .interval, intervalDays: interval)
        case .yearly:
            let days = parsedIntegers(monthDaysText, range: 1...31)
            guard (1...12).contains(yearlyMonth), !days.isEmpty else { return nil }
            return GoalRecurrence(
                frequency: .yearly,
                calendar: calendar,
                month: yearlyMonth,
                monthDays: days
            )
        case .season:
            return GoalRecurrence(
                frequency: .season,
                calendar: .hijri,
                seasonCode: seasonTemplate.rawValue
            )
        case .specificDates:
            let dates = parsedDates
            guard !dates.isEmpty else { return nil }
            return GoalRecurrence(frequency: .specificDates, specificDates: dates)
        }
    }

    var builtSlots: [GoalSlot]? {
        guard !slots.isEmpty else { return nil }
        let built = slots.enumerated().map { index, draft -> GoalSlot in
            var slot = draft.slot
            slot.sortOrder = index
            return slot
        }
        let identities = built.map(identityKey)
        guard Set(identities).count == identities.count,
              built.allSatisfy({ slot in
                  switch slot.slotType {
                  case .anytime:
                      true
                  case .prayer:
                      slot.prayerName != nil && slot.prayerRelation != nil &&
                          (slot.startLeadMinutesOverride ?? 0) >= 0
                  case .timeWindow:
                      slot.label?.isEmpty == false &&
                          (0..<(24 * 60)).contains(slot.startMinute ?? -1) &&
                          (1...(24 * 60)).contains(slot.endMinute ?? -1) &&
                          (slot.startMinute ?? 0) < (slot.endMinute ?? 0)
                  }
              }) else { return nil }
        return built
    }

    var validationMessage: String? {
        if recurrence == nil {
            switch frequency {
            case .weekly: return "Select at least one weekday."
            case .monthly, .yearly: return "Enter valid month days from 1 to 31."
            case .interval: return "Interval must be at least one day."
            case .specificDates: return "Enter at least one date as YYYY-MM-DD."
            case .daily, .season: return "Review the schedule."
            }
        }
        if builtSlots == nil {
            return "Sessions must be unique and use valid prayers or time windows."
        }
        return nil
    }

    mutating func applyTimingMode(_ mode: GoalTimingMode) {
        timingMode = mode
        switch mode {
        case .anytime:
            let existing = slots.first { $0.slotType == .anytime }
            slots = [existing ?? GoalScheduleSlotDraft(slotType: .anytime)]
        case .prayerBased:
            let existing = slots.filter { $0.slotType == .prayer }
            slots = existing.isEmpty
                ? [GoalScheduleSlotDraft(slotType: .prayer, prayerName: .fajr, prayerRelation: .after)]
                : existing
        case .morningEvening:
            let existing = slots.filter { $0.slotType == .timeWindow }
            if existing.count == 2 {
                slots = existing
            } else {
                slots = [
                    GoalScheduleSlotDraft(slotType: .timeWindow, label: "Morning", startMinute: 5 * 60, endMinute: 11 * 60),
                    GoalScheduleSlotDraft(slotType: .timeWindow, label: "Evening", startMinute: 17 * 60, endMinute: 22 * 60),
                ]
            }
        case .timeWindow:
            let existing = slots.filter { $0.slotType == .timeWindow }
            slots = existing.isEmpty
                ? [GoalScheduleSlotDraft(slotType: .timeWindow, label: "Session 1")]
                : existing
        }
    }

    mutating func addSlot() {
        switch timingMode {
        case .prayerBased:
            let used = Set(slots.compactMap { draft -> String? in
                guard let prayer = draft.prayerName, let relation = draft.prayerRelation else { return nil }
                return "\(prayer.rawValue)|\(relation.rawValue)"
            })
            let pair = Prayer.allCases.flatMap { prayer in
                PrayerRelation.allCases.map { (prayer, $0) }
            }.first { !used.contains("\($0.0.rawValue)|\($0.1.rawValue)") }
            if let pair {
                slots.append(GoalScheduleSlotDraft(slotType: .prayer, prayerName: pair.0, prayerRelation: pair.1))
            }
        case .timeWindow:
            let start = min(8 * 60 + slots.count * 120, 22 * 60)
            slots.append(
                GoalScheduleSlotDraft(
                    slotType: .timeWindow,
                    label: "Session \(slots.count + 1)",
                    startMinute: start,
                    endMinute: min(start + 60, 24 * 60)
                )
            )
        case .anytime, .morningEvening:
            break
        }
    }

    mutating func removeSlot(id: AwradID) {
        guard slots.count > 1 else { return }
        slots.removeAll { $0.id == id }
    }

    mutating func moveSlot(id: AwradID, offset: Int) {
        guard let source = slots.firstIndex(where: { $0.id == id }) else { return }
        let destination = source + offset
        guard slots.indices.contains(destination) else { return }
        slots.swapAt(source, destination)
    }

    private var parsedDates: Set<GoalSpecificDate> {
        Set(
            specificDatesText
                .split { $0 == "," || $0 == "\n" || $0 == " " }
                .map(String.init)
                .filter { Self.isDateKey($0) }
                .map { GoalSpecificDate(date: $0) }
        )
    }

    private func parsedIntegers(_ text: String, range: ClosedRange<Int>) -> Set<Int> {
        Set(
            text.split { $0 == "," || $0 == "\n" || $0 == " " }
                .compactMap { Int($0) }
                .filter(range.contains)
        )
    }

    private func identityKey(_ slot: GoalSlot) -> String {
        switch slot.slotType {
        case .anytime: "anytime"
        case .prayer: "prayer|\(slot.prayerName?.rawValue ?? "")|\(slot.prayerRelation?.rawValue ?? "")"
        case .timeWindow: "window|\(slot.label ?? "")|\(slot.startMinute ?? -1)|\(slot.endMinute ?? -1)"
        }
    }

    private static func isDateKey(_ value: String) -> Bool {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.isLenient = false
        return formatter.date(from: value) != nil
    }
}

struct EditGoalScheduleView: View {
    @Environment(AwradStore.self) private var store
    @Environment(AppServices.self) private var services
    @Environment(\.dismiss) private var dismiss

    let goalID: AwradID

    @State private var draft: GoalScheduleDraft?
    @State private var original: GoalScheduleDraft?
    @State private var saveError: String?
    @State private var isSaving = false

    private var goal: Goal? { store.goal(id: goalID) }
    private var isDirty: Bool { draft != original }

    var body: some View {
        Group {
            if goal == nil {
                ContentUnavailableView(
                    "Goal not found",
                    systemImage: "target",
                    description: Text("This goal may have been removed.")
                )
            } else if let draftBinding {
                editor(draftBinding)
            } else {
                ProgressView()
            }
        }
        .background(AwradTheme.background)
        .navigationTitle("Edit schedule")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: save)
                    .fontWeight(.semibold)
                    .disabled(!isDirty || draft?.validationMessage != nil || isSaving)
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

    private var draftBinding: Binding<GoalScheduleDraft>? {
        guard draft != nil else { return nil }
        return Binding(
            get: { draft ?? original! },
            set: { draft = $0 }
        )
    }

    private func editor(_ draft: Binding<GoalScheduleDraft>) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                scheduleCard(draft)
                sessionCard(draft)

                if let error = draft.wrappedValue.validationMessage {
                    Label(LocalizedStringKey(error), systemImage: "exclamationmark.triangle.fill")
                        .font(AwradTheme.bodyFont(.caption))
                        .foregroundStyle(.red)
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
                }

                if let goal, !goal.archivedSlots.isEmpty {
                    Label("Archived sessions stay attached to count history.", systemImage: "archivebox")
                        .font(AwradTheme.bodyFont(.caption))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(20)
            .padding(.bottom, 40)
        }
    }

    private func scheduleCard(_ draft: Binding<GoalScheduleDraft>) -> some View {
        AwradCard(padding: 16) {
            VStack(alignment: .leading, spacing: 16) {
                Label("Repeat", systemImage: "calendar")
                    .font(AwradTheme.bodyFont(.headline, weight: .semibold))

                Picker("Frequency", selection: draft.frequency) {
                    ForEach(RecurrenceFrequency.allCases) { frequency in
                        Text(GoalScheduleLabels.frequency(frequency)).tag(frequency)
                    }
                }
                .pickerStyle(.menu)

                recurrenceControls(draft)
            }
        }
    }

    @ViewBuilder
    private func recurrenceControls(_ draft: Binding<GoalScheduleDraft>) -> some View {
        switch draft.wrappedValue.frequency {
        case .daily:
            Text("Every due day")
                .font(AwradTheme.bodyFont(.subheadline))
                .foregroundStyle(.secondary)
        case .weekly:
            GoalWeekdaySelector(selection: draft.selectedWeekdays)
        case .monthly:
            Picker("Calendar", selection: draft.calendar) {
                ForEach(CalendarSystem.allCases) { Text($0.rawValue.capitalized).tag($0) }
            }
            TextField("Days of month, e.g. 1, 15, 29", text: draft.monthDaysText)
                .keyboardType(.numbersAndPunctuation)
                .textFieldStyle(.roundedBorder)
        case .interval:
            HStack {
                Text("Every")
                TextField("1", text: draft.intervalDaysText)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 88)
                Text("days")
            }
        case .yearly:
            Picker("Calendar", selection: draft.calendar) {
                ForEach(CalendarSystem.allCases) { Text($0.rawValue.capitalized).tag($0) }
            }
            Picker("Month", selection: draft.yearlyMonth) {
                ForEach(1...12, id: \.self) { Text("\($0)").tag($0) }
            }
            TextField("Days, e.g. 1, 10", text: draft.monthDaysText)
                .keyboardType(.numbersAndPunctuation)
                .textFieldStyle(.roundedBorder)
        case .season:
            Picker("Islamic season", selection: draft.seasonTemplate) {
                ForEach(SeasonTemplateCode.allCases) { Text($0.title).tag($0) }
            }
        case .specificDates:
            TextField("YYYY-MM-DD, one or more", text: draft.specificDatesText, axis: .vertical)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .lineLimit(3...6)
                .textFieldStyle(.roundedBorder)
        }
    }

    private func sessionCard(_ draft: Binding<GoalScheduleDraft>) -> some View {
        AwradCard(padding: 16) {
            VStack(alignment: .leading, spacing: 16) {
                Label("Sessions", systemImage: "clock")
                    .font(AwradTheme.bodyFont(.headline, weight: .semibold))

                Picker("Timing", selection: Binding(
                    get: { draft.wrappedValue.timingMode },
                    set: { newMode in draft.wrappedValue.applyTimingMode(newMode) }
                )) {
                    ForEach([GoalTimingMode.anytime, .prayerBased, .timeWindow]) { Text($0.title).tag($0) }
                }
                .pickerStyle(.menu)

                Text(draft.wrappedValue.timingMode.detail)
                    .font(AwradTheme.bodyFont(.caption))
                    .foregroundStyle(.secondary)

                ForEach(Array(draft.wrappedValue.slots.enumerated()), id: \.element.id) { index, element in
                    GoalScheduleSlotEditor(
                        slot: draft.slots[index],
                        canRemove: draft.wrappedValue.slots.count > 1,
                        canMoveUp: index > 0,
                        canMoveDown: index < draft.wrappedValue.slots.count - 1,
                        onMoveUp: { draft.wrappedValue.moveSlot(id: element.id, offset: -1) },
                        onMoveDown: { draft.wrappedValue.moveSlot(id: element.id, offset: 1) },
                        onRemove: { draft.wrappedValue.removeSlot(id: element.id) }
                    )
                }

                if draft.wrappedValue.timingMode == .prayerBased || draft.wrappedValue.timingMode == .timeWindow {
                    Button {
                        draft.wrappedValue.addSlot()
                    } label: {
                        Label("Add session", systemImage: "plus.circle.fill")
                            .frame(minHeight: 44)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(AwradTheme.sage)
                }
            }
        }
    }

    private func hydrateIfNeeded() {
        guard draft == nil, let goal else { return }
        let hydrated = GoalScheduleDraft(goal: goal)
        draft = hydrated
        original = hydrated
    }

    private func save() {
        guard !isSaving else { return }
        guard let goal, let draft, let recurrence = draft.recurrence, let slots = draft.builtSlots,
              let updated = store.updateGoalSchedule(goalID: goal.id, recurrence: recurrence, slots: slots) else {
            saveError = draft?.validationMessage ?? "Review the schedule and try again."
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
                saveError = result.localizedFailureMessage(language: store.preferences.appLanguage)
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
            language: store.preferences.appLanguage,
            prayerTimes: prayerTimes
        )
    }
}

private struct GoalWeekdaySelector: View {
    @Binding var selection: Set<Int>

    private let labels = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(1...7, id: \.self) { weekday in
                Button {
                    if selection.contains(weekday) {
                        selection.remove(weekday)
                    } else {
                        selection.insert(weekday)
                    }
                } label: {
                    Text(LocalizedStringKey(labels[weekday - 1]))
                        .font(AwradTheme.bodyFont(.caption, weight: .semibold))
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .foregroundStyle(selection.contains(weekday) ? Color.white : AwradTheme.ink)
                        .background(selection.contains(weekday) ? AwradTheme.sage : AwradTheme.surface, in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selection.contains(weekday) ? .isSelected : [])
            }
        }
    }
}

private struct GoalScheduleSlotEditor: View {
    @Binding var slot: GoalScheduleSlotDraft
    let canRemove: Bool
    let canMoveUp: Bool
    let canMoveDown: Bool
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void
    let onRemove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(title, systemImage: symbol)
                    .font(AwradTheme.bodyFont(.subheadline, weight: .semibold))
                Spacer()
                Button(action: onMoveUp) {
                    Image(systemName: "chevron.up")
                        .frame(width: 44, height: 44)
                }
                .disabled(!canMoveUp)
                .accessibilityLabel("Move session up")
                Button(action: onMoveDown) {
                    Image(systemName: "chevron.down")
                        .frame(width: 44, height: 44)
                }
                .disabled(!canMoveDown)
                .accessibilityLabel("Move session down")
                if canRemove {
                    Button(role: .destructive, action: onRemove) {
                        Image(systemName: "trash")
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Remove session")
                }
            }

            switch slot.slotType {
            case .anytime:
                Text("Available whenever this goal is due.")
                    .font(AwradTheme.bodyFont(.caption))
                    .foregroundStyle(.secondary)
            case .prayer:
                TextField("Session name", text: $slot.label)
                    .textFieldStyle(.roundedBorder)
                Picker("Prayer", selection: $slot.prayerName) {
                    ForEach(Prayer.allCases) { Text($0.title).tag(Optional($0)) }
                }
                Picker("Relation", selection: $slot.prayerRelation) {
                    ForEach(PrayerRelation.allCases) { Text($0.rawValue.capitalized).tag(Optional($0)) }
                }
                .pickerStyle(.segmented)
                if slot.prayerRelation == .before {
                    Stepper(value: $slot.beforeLeadMinutes, in: 0...180, step: 5) {
                        Text("Begin \(slot.beforeLeadMinutes) minutes before")
                    }
                }
            case .timeWindow:
                TextField("Session name", text: $slot.label)
                    .textFieldStyle(.roundedBorder)
                DatePicker("Starts", selection: minuteBinding(\.startMinute), displayedComponents: .hourAndMinute)
                DatePicker("Ends", selection: minuteBinding(\.endMinute), displayedComponents: .hourAndMinute)
            }
        }
        .padding(14)
        .background(AwradTheme.surface.opacity(0.72), in: RoundedRectangle(cornerRadius: 18))
    }

    private var title: LocalizedStringKey {
        switch slot.slotType {
        case .anytime: "Anytime"
        case .prayer: "Prayer session"
        case .timeWindow: "Time window"
        }
    }

    private var symbol: String {
        switch slot.slotType {
        case .anytime: "clock"
        case .prayer: "sun.horizon"
        case .timeWindow: "calendar.badge.clock"
        }
    }

    private func minuteBinding(_ keyPath: WritableKeyPath<GoalScheduleSlotDraft, Int>) -> Binding<Date> {
        Binding(
            get: {
                let minute = slot[keyPath: keyPath]
                return Calendar.current.date(from: DateComponents(hour: minute / 60, minute: minute % 60)) ?? Date()
            },
            set: { value in
                let components = Calendar.current.dateComponents([.hour, .minute], from: value)
                slot[keyPath: keyPath] = (components.hour ?? 0) * 60 + (components.minute ?? 0)
            }
        )
    }
}

private enum GoalScheduleLabels {
    static func frequency(_ frequency: RecurrenceFrequency) -> LocalizedStringKey {
        switch frequency {
        case .daily: "Daily"
        case .weekly: "Weekly"
        case .monthly: "Monthly"
        case .interval: "Interval"
        case .yearly: "Yearly"
        case .season: "Islamic season"
        case .specificDates: "Specific dates"
        }
    }
}

private extension String {
    var trimmedOrNil: String? {
        let value = trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}
