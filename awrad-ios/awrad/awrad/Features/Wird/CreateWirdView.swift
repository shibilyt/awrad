import SwiftUI

// MARK: - Builder root

struct CreateWirdView: View {
    @Environment(AwradStore.self) private var store
    @Environment(AppRouter.self) private var router
    @Environment(AppServices.self) private var services

    var editingWirdID: AwradID?

    @State private var nameEn = ""
    @State private var nameAr = ""
    @State private var descEn = ""
    @State private var author = ""
    @State private var sourceAttribution = ""
    @State private var cadence: CadenceKind = .everyDay
    @State private var weekdays: Set<Int> = [2, 5] // Mon, Thu
    @State private var partsByWeekday: [Int: [Int]] = [:]
    @State private var intervalDays = 2
    @State private var hijri: HijriKind = .none
    @State private var defaultOccasion = WirdOccasion.anytime
    @State private var parts: [WirdPart] = [WirdPart(localizedTitle: ["en": "Part 1"], segments: [])]
    @State private var reminders: [WirdReminder] = []
    @State private var didHydrate = false
    @State private var showDeleteConfirmation = false
    @State private var isSaving = false
    @State private var saveError: String?

    private var language: AppLanguage { store.preferences.appLanguage }

    private var isEditing: Bool { editingWirdID != nil }

    private var canSave: Bool {
        !nameEn.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        parts.contains { part in part.segments.contains { $0.isCountable && !$0.arabic.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } } &&
        (cadence != .partsByWeekday || !normalizedWeekdayAssignments.isEmpty)
    }

    var body: some View {
        Form {
            detailsSection
            scheduleSection
            partsSection
            remindersSection
            saveSection
        }
        .navigationTitle(isEditing ? "Edit Wird" : "Create Wird")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                EditButton()
                if isEditing {
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Image(systemName: "trash")
                    }
                    .accessibilityLabel(Text(LocalizedStringKey("Delete wird")))
                }
            }
        }
        .onAppear(perform: hydrateIfNeeded)
        .confirmationDialog(
            LocalizedStringKey("Delete this wird?"),
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button(LocalizedStringKey("Delete wird"), role: .destructive, action: deleteWird)
            Button(LocalizedStringKey("Cancel"), role: .cancel) {}
        } message: {
            Text(LocalizedStringKey("Its reading progress and reminders will also be removed."))
        }
        .alert("Couldn’t save wird", isPresented: Binding(
            get: { saveError != nil },
            set: { if !$0 { saveError = nil } }
        )) {
            Button("Retry", action: save)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(saveError ?? "")
        }
    }

    // MARK: Sections

    private var detailsSection: some View {
        Section(header: Text(LocalizedStringKey("Details"))) {
            TextField(LocalizedStringKey("Name (English)"), text: $nameEn)
            TextField(LocalizedStringKey("Name (Arabic)"), text: $nameAr)
                .multilineTextAlignment(.trailing)
                .environment(\.layoutDirection, .rightToLeft)
            TextField(LocalizedStringKey("Description"), text: $descEn, axis: .vertical)
                .lineLimit(2...4)
            TextField(LocalizedStringKey("Source (book / compiler)"), text: $sourceAttribution)
        }
    }

    private var scheduleSection: some View {
        Section(header: Text(LocalizedStringKey("Schedule"))) {
            Picker(LocalizedStringKey("Repeats"), selection: $cadence) {
                ForEach(CadenceKind.allCases) { kind in
                    Text(LocalizedStringKey(kind.title)).tag(kind)
                }
            }
            if cadence == .daysOfWeek {
                weekdayPicker
            }
            if cadence == .partsByWeekday {
                weekdayPartPicker
            }
            if cadence == .interval {
                Stepper(value: $intervalDays, in: 1...60) {
                    Text(AwradLocalizer.format("Every %d days", language: language, intervalDays))
                }
            }
            if cadence == .rotation {
                Text(LocalizedStringKey("One section per day, cycling through your sections."))
                    .font(AwradTheme.bodyFont(.caption))
                    .foregroundStyle(.secondary)
            }
            if cadence == .partsByWeekday {
                Text(LocalizedStringKey("Choose one or more sections for each weekday. Unassigned days are skipped."))
                    .font(AwradTheme.bodyFont(.caption))
                    .foregroundStyle(.secondary)
            }
            Picker(LocalizedStringKey("Season"), selection: $hijri) {
                ForEach(HijriKind.allCases) { kind in
                    Text(LocalizedStringKey(kind.title)).tag(kind)
                }
            }
            OccasionPicker(title: "Default time", occasion: $defaultOccasion)
        }
    }

    private var weekdayPicker: some View {
        HStack {
            ForEach(1...7, id: \.self) { weekday in
                let on = weekdays.contains(weekday)
                Button {
                    if on { weekdays.remove(weekday) } else { weekdays.insert(weekday) }
                } label: {
                    Text(WirdDisplay.weekdaySymbol(weekday) ?? "")
                        .font(AwradTheme.bodyFont(.caption, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(on ? AwradTheme.sage : AwradTheme.surface, in: RoundedRectangle(cornerRadius: 8))
                        .foregroundStyle(on ? .white : AwradTheme.ink)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var weekdayPartPicker: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(1...7, id: \.self) { weekday in
                VStack(alignment: .leading, spacing: 8) {
                    Text(WirdDisplay.weekdayName(weekday))
                        .font(AwradTheme.bodyFont(.caption, weight: .semibold))
                        .foregroundStyle(.secondary)
                    if parts.isEmpty {
                        Text(LocalizedStringKey("Add a section before assigning weekdays."))
                            .font(AwradTheme.bodyFont(.caption))
                            .foregroundStyle(.secondary)
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(parts.indices, id: \.self) { index in
                                    let selected = partsByWeekday[weekday, default: []].contains(index)
                                    Button {
                                        togglePart(index, for: weekday)
                                    } label: {
                                        Label {
                                            Text(partLabel(at: index))
                                                .lineLimit(1)
                                        } icon: {
                                            if selected { Image(systemName: "checkmark") }
                                        }
                                        .font(AwradTheme.bodyFont(.caption, weight: .semibold))
                                        .padding(.horizontal, 11)
                                        .padding(.vertical, 8)
                                        .foregroundStyle(selected ? Color.white : AwradTheme.ink)
                                        .background(selected ? AwradTheme.sage : AwradTheme.surface, in: Capsule())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var partsSection: some View {
        Section(header: Text(LocalizedStringKey("Sections"))) {
            ForEach($parts) { $part in
                NavigationLink {
                    WirdPartEditorView(part: $part, dhikrs: store.dhikrs, language: language)
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(part.displayTitle(language: language).isEmpty ? "Untitled section" : part.displayTitle(language: language))
                            .foregroundStyle(AwradTheme.ink)
                        Text(AwradLocalizer.format("%d items", language: language, part.segments.count))
                            .font(AwradTheme.bodyFont(.caption))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .onDelete(perform: deleteParts)
            .onMove(perform: moveParts)

            Button {
                parts.append(WirdPart(localizedTitle: ["en": "Part \(parts.count + 1)"], segments: []))
            } label: {
                Label("Add section", systemImage: "plus.circle")
            }
        }
    }

    private var remindersSection: some View {
        Section(header: Text(LocalizedStringKey("Reminders"))) {
            ForEach($reminders) { $reminder in
                ReminderEditorRow(reminder: $reminder)
            }
            .onDelete { reminders.remove(atOffsets: $0) }
            Button {
                reminders.append(WirdReminder(reminderType: .fixedTime, hour: 7, minute: 0))
            } label: {
                Label("Add reminder", systemImage: "bell.badge.plus")
            }
        }
    }

    private var saveSection: some View {
        Section {
            Button {
                save()
            } label: {
                Text(LocalizedStringKey(isEditing ? "Save changes" : "Create wird"))
                    .frame(maxWidth: .infinity)
                    .fontWeight(.semibold)
            }
            .disabled(!canSave || isSaving)
        }
    }

    // MARK: Build / save

    private func resolvedCadence() -> WirdCadence {
        switch cadence {
        case .everyDay: return .everyDay
        case .rotation: return .rotation
        case .daysOfWeek: return .daysOfWeek(weekdays)
        case .interval: return .interval(days: intervalDays, anchor: Date().dateKey)
        case .partsByWeekday: return .everyDay
        }
    }

    private var normalizedWeekdayAssignments: [Int: [Int]] {
        WirdLifecycleLogic.normalizedWeekdayAssignments(partsByWeekday, partCount: parts.count)
    }

    private func save() {
        guard !isSaving else { return }
        let previous = editingWirdID.flatMap { store.wird(id: $0) }
        var wird = isEditing ? (store.wird(id: editingWirdID!) ?? Wird(slug: "")) : Wird(slug: "")
        wird.localizedName = compact(["en": nameEn, "ar": nameAr])
        wird.localizedDescription = compact(["en": descEn])
        wird.author = author.isEmpty ? (store.preferences.userName.isEmpty ? "You" : store.preferences.userName) : author
        wird.sourceAttribution = sourceAttribution.isEmpty ? nil : sourceAttribution
        wird.schedule = WirdSchedule(
            cadence: resolvedCadence(),
            partsByWeekday: cadence == .partsByWeekday ? normalizedWeekdayAssignments : nil,
            hijriAnchor: hijri.anchor,
            defaultOccasion: defaultOccasion
        )
        wird.parts = parts
        wird.reminders = reminders

        let saved: Wird?
        if isEditing {
            saved = store.updateWird(wird)
        } else {
            saved = store.createWird(wird)
        }
        guard let saved else { return }
        isSaving = true
        Task {
            let result = await services.rescheduleWirdReminders(for: saved, store: store)
            isSaving = false
            if result.succeeded {
                router.replaceLast(with: .wirdDetail(saved.id), in: store.selectedTab)
            } else {
                if let previous {
                    if let restored = store.updateWird(previous) {
                        _ = await services.rescheduleWirdReminders(for: restored, store: store)
                    }
                } else {
                    _ = store.deleteWird(saved.id)
                    _ = await services.cancelWirdReminders(wirdID: saved.id)
                }
                saveError = result.localizedFailureMessage(language: language)
            }
        }
    }

    private func compact(_ map: [String: String]) -> [String: String] {
        map.filter { !$0.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    private func hydrateIfNeeded() {
        guard !didHydrate else { return }
        didHydrate = true
        guard let id = editingWirdID, let wird = store.wird(id: id), wird.isCustom else { return }
        nameEn = wird.localizedName["en"] ?? ""
        nameAr = wird.localizedName["ar"] ?? ""
        descEn = wird.localizedDescription["en"] ?? ""
        author = wird.author
        sourceAttribution = wird.sourceAttribution ?? ""
        defaultOccasion = wird.schedule.defaultOccasion
        hijri = HijriKind(anchor: wird.schedule.hijriAnchor)
        if let assignments = wird.schedule.partsByWeekday {
            cadence = .partsByWeekday
            partsByWeekday = assignments
        } else {
            switch wird.schedule.cadence {
            case .everyDay: cadence = .everyDay
            case .rotation: cadence = .rotation
            case .daysOfWeek(let days): cadence = .daysOfWeek; weekdays = days
            case .interval(let days, _): cadence = .interval; intervalDays = days
            }
        }
        parts = wird.parts
        reminders = wird.reminders
    }

    private func togglePart(_ index: Int, for weekday: Int) {
        var indexes = partsByWeekday[weekday, default: []]
        if let position = indexes.firstIndex(of: index) {
            indexes.remove(at: position)
        } else {
            indexes.append(index)
        }
        if indexes.isEmpty {
            partsByWeekday.removeValue(forKey: weekday)
        } else {
            partsByWeekday[weekday] = indexes
        }
    }

    private func partLabel(at index: Int) -> String {
        guard parts.indices.contains(index) else { return "" }
        let title = parts[index].displayTitle(language: language)
        return title.isEmpty ? AwradLocalizer.format("Section %d", language: language, index + 1) : title
    }

    private func deleteParts(at offsets: IndexSet) {
        let assignmentIDs = WirdLifecycleLogic.assignmentIDs(from: partsByWeekday, parts: parts)
        parts.remove(atOffsets: offsets)
        partsByWeekday = WirdLifecycleLogic.assignments(from: assignmentIDs, parts: parts)
    }

    private func moveParts(from offsets: IndexSet, to destination: Int) {
        let assignmentIDs = WirdLifecycleLogic.assignmentIDs(from: partsByWeekday, parts: parts)
        parts.move(fromOffsets: offsets, toOffset: destination)
        partsByWeekday = WirdLifecycleLogic.assignments(from: assignmentIDs, parts: parts)
    }

    private func deleteWird() {
        guard let editingWirdID, store.wird(id: editingWirdID)?.isCustom == true else { return }
        guard let wird = store.wird(id: editingWirdID) else { return }
        Task {
            _ = await services.cancelWirdReminders(wirdID: editingWirdID)
            guard store.deleteWird(editingWirdID) else {
                _ = await services.rescheduleWirdReminders(for: wird, store: store)
                return
            }
            router.pop(in: store.selectedTab)
            router.pop(in: store.selectedTab)
        }
    }
}

// MARK: - Part editor

struct WirdPartEditorView: View {
    @Binding var part: WirdPart
    let dhikrs: [Dhikr]
    let language: AppLanguage

    @State private var showDhikrPicker = false

    private var titleEn: Binding<String> {
        Binding(get: { part.localizedTitle["en"] ?? "" }, set: { part.localizedTitle["en"] = $0 })
    }
    private var titleAr: Binding<String> {
        Binding(get: { part.localizedTitle["ar"] ?? "" }, set: { part.localizedTitle["ar"] = $0 })
    }
    private var subtitleEn: Binding<String> {
        Binding(get: { part.localizedSubtitle["en"] ?? "" }, set: { part.localizedSubtitle["en"] = $0 })
    }
    private var occasionBinding: Binding<WirdOccasion> {
        Binding(get: { part.occasion ?? .anytime }, set: { part.occasion = $0 })
    }
    private var usesOwnOccasion: Binding<Bool> {
        Binding(get: { part.occasion != nil }, set: { part.occasion = $0 ? (part.occasion ?? .anytime) : nil })
    }

    var body: some View {
        Form {
            Section(header: Text(LocalizedStringKey("Section title"))) {
                TextField(LocalizedStringKey("Title (English)"), text: titleEn)
                TextField(LocalizedStringKey("Title (Arabic)"), text: titleAr)
                    .multilineTextAlignment(.trailing)
                    .environment(\.layoutDirection, .rightToLeft)
                TextField(LocalizedStringKey("Subtitle"), text: subtitleEn)
            }
            Section(header: Text(LocalizedStringKey("Timing"))) {
                Toggle(LocalizedStringKey("Custom time for this section"), isOn: usesOwnOccasion)
                if part.occasion != nil {
                    OccasionPicker(title: "Time", occasion: occasionBinding)
                }
                Stepper(value: $part.blockRepeat, in: 1...20) {
                    Text(AwradLocalizer.format("Repeat section %d times", language: language, part.blockRepeat))
                }
            }
            Section(header: Text(LocalizedStringKey("Items"))) {
                ForEach($part.segments) { $segment in
                    NavigationLink {
                        WirdSegmentEditorView(segment: $segment, language: language)
                    } label: {
                        segmentRow($segment.wrappedValue)
                    }
                }
                .onDelete { part.segments.remove(atOffsets: $0) }
                .onMove { part.segments.move(fromOffsets: $0, toOffset: $1) }

                Button {
                    part.segments.append(WirdSegment(kind: .dhikr, repeatSpec: RepeatSpec(count: 1)))
                } label: {
                    Label("Type a new item", systemImage: "plus.circle")
                }
                Button {
                    showDhikrPicker = true
                } label: {
                    Label("Add from library", systemImage: "books.vertical")
                }
            }
        }
        .navigationTitle(part.displayTitle(language: language).isEmpty ? "Section" : part.displayTitle(language: language))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .topBarTrailing) { EditButton() } }
        .sheet(isPresented: $showDhikrPicker) {
            DhikrPickerView(dhikrs: dhikrs, language: language) { dhikr in
                part.segments.append(segment(from: dhikr))
            }
            .awradSheetStyle()
        }
    }

    private func segmentRow(_ segment: WirdSegment) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(rowTitle(segment))
                .lineLimit(1)
                .foregroundStyle(AwradTheme.ink)
            Text(LocalizedStringKey(segment.kind.rawValue.capitalized))
                .font(AwradTheme.bodyFont(.caption))
                .foregroundStyle(.secondary)
        }
    }

    private func rowTitle(_ segment: WirdSegment) -> String {
        if segment.kind.isCountable {
            if !segment.arabic.isEmpty { return segment.arabic }
            return segment.translationText(language: language) ?? "New item"
        }
        return segment.headingText(language: language) ?? "Heading"
    }

    private func segment(from dhikr: Dhikr) -> WirdSegment {
        WirdSegment(
            kind: dhikr.category == .swalaths ? .salah : .dhikr,
            arabic: dhikr.arabic,
            transliteration: dhikr.transliteration.isEmpty ? [:] : ["en": dhikr.transliteration],
            translation: dhikr.translation.isEmpty ? [:] : ["en": dhikr.translation],
            repeatSpec: RepeatSpec(count: 1),
            sourceDhikrID: dhikr.id,
            audioFileName: dhikr.audioFileName,
            audioURL: dhikr.audioURL
        )
    }
}

// MARK: - Segment editor

struct WirdSegmentEditorView: View {
    @Binding var segment: WirdSegment
    let language: AppLanguage

    @State private var useRange = false

    private func text(_ key: String, in keyPath: WritableKeyPath<WirdSegment, [String: String]>) -> Binding<String> {
        Binding(
            get: { segment[keyPath: keyPath][key] ?? "" },
            set: { segment[keyPath: keyPath][key] = $0 }
        )
    }

    var body: some View {
        Form {
            Section {
                Picker(LocalizedStringKey("Type"), selection: $segment.kind) {
                    ForEach(SegmentKind.allCases) { kind in
                        Text(LocalizedStringKey(kind.rawValue.capitalized)).tag(kind)
                    }
                }
            }
            if segment.kind.isCountable {
                Section(header: Text(LocalizedStringKey("Text"))) {
                    TextField(LocalizedStringKey("Arabic"), text: $segment.arabic, axis: .vertical)
                        .lineLimit(2...8)
                        .multilineTextAlignment(.trailing)
                        .environment(\.layoutDirection, .rightToLeft)
                    TextField(LocalizedStringKey("Transliteration"), text: text("en", in: \.transliteration))
                    TextField(LocalizedStringKey("Translation"), text: text("en", in: \.translation), axis: .vertical)
                        .lineLimit(1...4)
                    TextField(LocalizedStringKey("Benefit (optional)"), text: text("en", in: \.fadl), axis: .vertical)
                        .lineLimit(1...3)
                }
                Section(header: Text(LocalizedStringKey("Repetitions"))) {
                    Toggle(LocalizedStringKey("Use a range"), isOn: $useRange)
                    if useRange {
                        Stepper(value: rangeMin, in: 1...990) { Text(AwradLocalizer.format("Minimum %d", language: language, rangeMin.wrappedValue)) }
                        Stepper(value: rangeMax, in: rangeMin.wrappedValue...1000) { Text(AwradLocalizer.format("Maximum %d", language: language, rangeMax.wrappedValue)) }
                    } else {
                        Stepper(value: $segment.repeatSpec.count, in: 1...1000) {
                            Text(AwradLocalizer.format("Repeat %d times", language: language, segment.repeatSpec.count))
                        }
                    }
                }
            } else {
                Section(header: Text(LocalizedStringKey("Text"))) {
                    TextField(LocalizedStringKey("Heading / instruction"), text: text("en", in: \.localizedText), axis: .vertical)
                        .lineLimit(1...4)
                }
            }
        }
        .navigationTitle(LocalizedStringKey(segment.kind.rawValue.capitalized))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { useRange = segment.repeatSpec.isRange }
        .onChange(of: useRange) { _, on in
            if !on { segment.repeatSpec.min = nil; segment.repeatSpec.max = nil }
            else if segment.repeatSpec.min == nil {
                segment.repeatSpec.min = segment.repeatSpec.count
                segment.repeatSpec.max = segment.repeatSpec.count
            }
        }
    }

    private var rangeMin: Binding<Int> {
        Binding(get: { segment.repeatSpec.min ?? segment.repeatSpec.count }, set: { segment.repeatSpec.min = $0; segment.repeatSpec.count = $0 })
    }
    private var rangeMax: Binding<Int> {
        Binding(get: { segment.repeatSpec.max ?? segment.repeatSpec.count }, set: { segment.repeatSpec.max = $0 })
    }
}

// MARK: - Occasion picker

struct OccasionPicker: View {
    let title: String
    @Binding var occasion: WirdOccasion

    private var kind: Binding<OccasionKind> {
        Binding(
            get: { OccasionKind(occasion) },
            set: { occasion = $0.toOccasion(existing: occasion) }
        )
    }
    private var prayer: Binding<Prayer> {
        Binding(
            get: { if case .afterPrayer(let p) = occasion { return p } else { return .fajr } },
            set: { occasion = .afterPrayer($0) }
        )
    }

    var body: some View {
        Picker(LocalizedStringKey(title), selection: kind) {
            ForEach(OccasionKind.allCases) { k in
                Text(LocalizedStringKey(k.title)).tag(k)
            }
        }
        if case .afterPrayer = occasion {
            Picker(LocalizedStringKey("Prayer"), selection: prayer) {
                ForEach(Prayer.allCases) { p in
                    Text(LocalizedStringKey(p.title)).tag(p)
                }
            }
        }
    }
}

// MARK: - Reminder row

private struct ReminderEditorRow: View {
    @Binding var reminder: WirdReminder

    private var timeBinding: Binding<Date> {
        Binding(
            get: {
                var comps = DateComponents()
                comps.hour = reminder.hour ?? 7
                comps.minute = reminder.minute ?? 0
                return Calendar.current.date(from: comps) ?? Date()
            },
            set: {
                let comps = Calendar.current.dateComponents([.hour, .minute], from: $0)
                reminder.hour = comps.hour
                reminder.minute = comps.minute
            }
        )
    }
    private var prayer: Binding<Prayer> {
        Binding(get: { reminder.prayer ?? .fajr }, set: { reminder.prayer = $0 })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(LocalizedStringKey("Enabled"), isOn: $reminder.enabled)
            Picker(LocalizedStringKey("Type"), selection: $reminder.reminderType) {
                Text(LocalizedStringKey("Fixed time")).tag(ReminderType.fixedTime)
                Text(LocalizedStringKey("After prayer")).tag(ReminderType.prayerOffset)
            }
            .pickerStyle(.segmented)
            if reminder.reminderType == .prayerOffset {
                Picker(LocalizedStringKey("Prayer"), selection: prayer) {
                    ForEach(Prayer.allCases) { p in Text(LocalizedStringKey(p.title)).tag(p) }
                }
                Stepper(value: Binding(get: { reminder.offsetMinutes ?? 0 }, set: { reminder.offsetMinutes = $0 }), in: 0...120, step: 5) {
                    Text("+\(reminder.offsetMinutes ?? 0) min")
                }
            } else {
                DatePicker(LocalizedStringKey("Time"), selection: timeBinding, displayedComponents: .hourAndMinute)
            }
        }
    }
}

// MARK: - Dhikr picker

struct DhikrPickerView: View {
    @Environment(\.dismiss) private var dismiss
    let dhikrs: [Dhikr]
    let language: AppLanguage
    let onSelect: (Dhikr) -> Void

    @State private var query = ""

    private var filtered: [Dhikr] {
        guard !query.isEmpty else { return dhikrs }
        return dhikrs.filter {
            $0.title.localizedCaseInsensitiveContains(query) ||
            $0.transliteration.localizedCaseInsensitiveContains(query) ||
            $0.arabic.contains(query)
        }
    }

    var body: some View {
        NavigationStack {
            List(filtered) { dhikr in
                Button {
                    onSelect(dhikr)
                    dismiss()
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(dhikr.displayTitle(language: language))
                            .foregroundStyle(AwradTheme.ink)
                        if !dhikr.arabic.isEmpty {
                            Text(dhikr.arabic)
                                .font(AwradTheme.arabicFont(20))
                                .foregroundStyle(AwradTheme.sageDark)
                                .lineLimit(1)
                        }
                    }
                }
            }
            .searchable(text: $query)
            .navigationTitle("Add from library")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(LocalizedStringKey("Cancel")) { dismiss() }
                }
            }
        }
    }
}

// MARK: - UI enums

private enum CadenceKind: String, CaseIterable, Identifiable {
    case everyDay, rotation, daysOfWeek, interval, partsByWeekday
    var id: String { rawValue }
    var title: String {
        switch self {
        case .everyDay: "Every day"
        case .rotation: "Rotating sections"
        case .daysOfWeek: "Specific days"
        case .interval: "Every N days"
        case .partsByWeekday: "Sections by weekday"
        }
    }
}

private enum HijriKind: String, CaseIterable, Identifiable {
    case none, ramadan, lastTenNights
    var id: String { rawValue }
    var title: String {
        switch self {
        case .none: "All year"
        case .ramadan: "Ramadan only"
        case .lastTenNights: "Last ten nights"
        }
    }
    var anchor: HijriAnchor? {
        switch self {
        case .none: nil
        case .ramadan: .ramadan
        case .lastTenNights: .lastTenNights
        }
    }
    init(anchor: HijriAnchor?) {
        switch anchor {
        case .ramadan: self = .ramadan
        case .lastTenNights: self = .lastTenNights
        default: self = .none
        }
    }
}

enum OccasionKind: String, CaseIterable, Identifiable {
    case anytime, morning, evening, beforeSleep, afterPrayer, timeWindow
    var id: String { rawValue }
    var title: String {
        switch self {
        case .anytime: "Anytime"
        case .morning: "Morning"
        case .evening: "Evening"
        case .beforeSleep: "Before sleep"
        case .afterPrayer: "After prayer"
        case .timeWindow: "Time window"
        }
    }
    init(_ occasion: WirdOccasion) {
        switch occasion {
        case .anytime: self = .anytime
        case .morning: self = .morning
        case .evening: self = .evening
        case .beforeSleep: self = .beforeSleep
        case .afterPrayer: self = .afterPrayer
        case .timeWindow: self = .timeWindow
        }
    }
    func toOccasion(existing: WirdOccasion) -> WirdOccasion {
        switch self {
        case .anytime: return .anytime
        case .morning: return .morning
        case .evening: return .evening
        case .beforeSleep: return .beforeSleep
        case .afterPrayer:
            if case .afterPrayer = existing { return existing }
            return .afterPrayer(.fajr)
        case .timeWindow:
            if case .timeWindow = existing { return existing }
            return .timeWindow(startMinute: 5 * 60, endMinute: 7 * 60)
        }
    }
}
