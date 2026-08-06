import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Shared helpers

enum WirdDisplay {
    static func occasionLabel(_ occasion: WirdOccasion, language: AppLanguage) -> String {
        switch occasion {
        case .anytime:
            return AwradLocalizer.localized("Anytime", language: language)
        case .afterPrayer(let prayer):
            return AwradLocalizer.format("After %@", language: language, AwradLocalizer.localized(prayer.title, language: language))
        case .morning:
            return AwradLocalizer.localized("Morning", language: language)
        case .evening:
            return AwradLocalizer.localized("Evening", language: language)
        case .beforeSleep:
            return AwradLocalizer.localized("Before sleep", language: language)
        case .timeWindow(let start, let end):
            return "\(minuteLabel(start)) – \(minuteLabel(end))"
        }
    }

    static func cadenceLabel(_ cadence: WirdCadence, language: AppLanguage) -> String {
        switch cadence {
        case .everyDay:
            return AwradLocalizer.localized("Every day", language: language)
        case .rotation:
            return AwradLocalizer.localized("Rotating", language: language)
        case .daysOfWeek(let days):
            let names = days.sorted().compactMap { weekdaySymbol($0) }
            return names.isEmpty ? AwradLocalizer.localized("Every day", language: language) : names.joined(separator: ", ")
        case .interval(let n, _):
            return AwradLocalizer.format("Every %d days", language: language, n)
        }
    }

    static func scheduleLabel(_ schedule: WirdSchedule, language: AppLanguage) -> String {
        if schedule.partsByWeekday != nil {
            return AwradLocalizer.localized("Sections by weekday", language: language)
        }
        return cadenceLabel(schedule.cadence, language: language)
    }

    static func weekdaySymbol(_ weekday: Int) -> String? {
        let symbols = Calendar.current.shortWeekdaySymbols // index 0 = Sunday
        let index = weekday - 1
        guard symbols.indices.contains(index) else { return nil }
        return symbols[index]
    }

    static func weekdayName(_ weekday: Int) -> String {
        let symbols = Calendar.current.weekdaySymbols
        let index = weekday - 1
        guard symbols.indices.contains(index) else { return "" }
        return symbols[index]
    }

    private static func minuteLabel(_ minutes: Int) -> String {
        let hour = (minutes / 60) % 24
        let minute = minutes % 60
        return String(format: "%02d:%02d", hour, minute)
    }
}

// MARK: - List

struct WirdListView: View {
    @Environment(AwradStore.self) private var store
    @Environment(AppRouter.self) private var router
    @Environment(AppServices.self) private var services
    @State private var pendingDeletion: Wird?
    var showsCreateButton = true
    private var language: AppLanguage { store.preferences.appLanguage }
    private var effectiveToday: Date { WirdLifecycleLogic.date(from: store.todayKey) ?? Date() }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                if store.sortedWirds.isEmpty && store.resumableLegacyWirds.isEmpty {
                    EmptyStateView(
                        symbol: "book.pages",
                        title: "No wirds yet",
                        message: "Create a personal wird to begin a recurring reading practice."
                    )
                    .padding(.top, 44)
                } else {
                    if !store.resumableLegacyWirds.isEmpty {
                        Text(LocalizedStringKey("Continue previous version"))
                            .font(AwradTheme.bodyFont(.subheadline, weight: .semibold))
                            .foregroundStyle(.secondary)
                        ForEach(store.resumableLegacyWirds) { wird in
                            wirdButton(wird, isCustom: false)
                        }
                        Text("This saved cycle uses its original text and will be removed after completion.")
                            .font(AwradTheme.bodyFont(.footnote))
                            .foregroundStyle(.secondary)
                            .padding(.bottom, 6)
                    }

                    if !store.customWirds.isEmpty {
                    Text(LocalizedStringKey("Your wirds"))
                        .font(AwradTheme.bodyFont(.subheadline, weight: .semibold))
                        .foregroundStyle(.secondary)
                    ForEach(store.customWirds) { wird in
                        wirdButton(wird, isCustom: true)
                    }
                    Text(LocalizedStringKey("Library"))
                        .font(AwradTheme.bodyFont(.subheadline, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .padding(.top, 6)
                    }
                }
                ForEach(store.libraryWirds) { wird in
                    wirdButton(wird, isCustom: false)
                }
            }
            .padding(20)
            .padding(.bottom, 96)
        }
        .background(AwradTheme.background)
        .navigationTitle("Wirds")
        .toolbar {
            if showsCreateButton {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        router.navigate(.createWird, in: store.selectedTab)
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel(Text(LocalizedStringKey("Create wird")))
                }
            }
        }
        .confirmationDialog(
            LocalizedStringKey("Delete this wird?"),
            isPresented: Binding(
                get: { pendingDeletion != nil },
                set: { if !$0 { pendingDeletion = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button(LocalizedStringKey("Delete wird"), role: .destructive) {
                guard let wird = pendingDeletion else { return }
                guard store.wird(id: wird.id)?.isCustom == true else { return }
                Task {
                    _ = await services.refreshNotificationsAfterWirdMutation(store: store)
                    guard store.deleteWird(wird.id) else {
                        _ = await services.refreshNotificationsAfterWirdMutation(store: store)
                        return
                    }
                    pendingDeletion = nil
                }
            }
            Button(LocalizedStringKey("Cancel"), role: .cancel) { pendingDeletion = nil }
        } message: {
            Text(LocalizedStringKey("Its reading progress and reminders will also be removed."))
        }
    }

    @ViewBuilder
    private func wirdButton(_ wird: Wird, isCustom: Bool) -> some View {
        let activeParts = store.todayParts(for: wird, now: effectiveToday)
        let summary = store.progressSummary(for: wird, now: effectiveToday)
        Button {
            router.navigate(.wirdDetail(wird.id), in: store.selectedTab)
        } label: {
            WirdCatalogCard(
                wird: wird,
                summary: summary,
                isActiveToday: !activeParts.isEmpty,
                language: language
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("wird.collection.\(wird.id.uuidString)")
        .contextMenu {
            if isCustom {
                Button {
                    router.navigate(.editWird(wird.id), in: store.selectedTab)
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
                Button(role: .destructive) {
                    pendingDeletion = wird
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }
}

// MARK: - Detail

struct WirdDetailView: View {
    @Environment(AwradStore.self) private var store
    @Environment(AppRouter.self) private var router
    @Environment(AppServices.self) private var services
    let wirdID: AwradID
    @State private var showDeleteConfirmation = false
    @State private var showReminderPicker = false
    @State private var reminderDraft = Date()
    @State private var reminderError: String?
    @State private var notificationRetry: (() -> Void)?
    private var language: AppLanguage { store.preferences.appLanguage }
    private var effectiveToday: Date { WirdLifecycleLogic.date(from: store.todayKey) ?? Date() }

    var body: some View {
        Group {
            if let wird = store.wird(id: wirdID) {
                detail(for: wird)
                    .toolbar { detailToolbar(for: wird) }
                    .safeAreaInset(edge: .bottom) {
                        if let part = preferredPart(in: wird) {
                            Button {
                                openReader(wird: wird, part: part)
                            } label: {
                                Label("Begin recitation", systemImage: "book.pages.fill")
                                    .frame(maxWidth: .infinity)
                            }
                            .awradPrimaryButton()
                            .accessibilityIdentifier("wird.detail.begin")
                            .padding(.horizontal, 20)
                            .padding(.top, 18)
                            .padding(.bottom, 10)
                            .background(.ultraThinMaterial)
                        }
                    }
            } else {
                EmptyStateView(symbol: "book.closed", title: "Wird Missing", message: "This collection is no longer available.")
                    .padding(20)
            }
        }
        .background(AwradTheme.background)
        .navigationTitle(store.wird(id: wirdID)?.displayName(language: language) ?? AwradLocalizer.localized("Wird", language: language))
        .navigationBarTitleDisplayMode(.inline)
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
        .sheet(isPresented: $showReminderPicker) {
            WirdReminderTimeSheet(time: $reminderDraft) {
                saveQuickReminder(at: reminderDraft)
                showReminderPicker = false
            }
            .presentationDetents([.medium])
            .awradSheetStyle()
        }
        .alert("Couldn’t update reminder", isPresented: Binding(
            get: { reminderError != nil },
            set: { if !$0 { reminderError = nil } }
        )) {
            if notificationRetry != nil {
                Button("Retry") {
                    let retry = notificationRetry
                    notificationRetry = nil
                    retry?()
                }
            }
            Button("Cancel", role: .cancel) { notificationRetry = nil }
        } message: {
            Text(reminderError ?? "")
        }
    }

    private func detail(for wird: Wird) -> some View {
        let activeParts = store.todayParts(for: wird, now: effectiveToday)
        let summaries = Dictionary(uniqueKeysWithValues: wird.parts.map { part in
            let occasionKey = store.occasionKey(for: part, in: wird)
            return (part.id, store.progressSummary(for: part, wirdID: wird.id, occasionKey: occasionKey))
        })
        let completedToday = activeParts.filter { summaries[$0.id]?.isComplete == true }.count
        let recitations = wird.parts.reduce(0) { $0 + $1.countableSegments.count }
        let recentWeek = WirdLifecycleLogic.recentWeek(
            for: wird,
            sessions: store.wirdSessions,
            today: effectiveToday
        )

        return ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                WirdDetailHeader(wird: wird, language: language)
                WirdStatRow(
                    sectionCount: wird.parts.count,
                    estimatedMinutes: wird.estimatedMinutes,
                    streak: store.wirdStreak(for: wird),
                    language: language
                )
                WirdTodayCard(
                    days: recentWeek,
                    completed: completedToday,
                    total: activeParts.count,
                    language: language
                )

                HStack(alignment: .firstTextBaseline) {
                    Text(AwradLocalizer.format("%d sections", language: language, wird.parts.count))
                        .font(AwradTheme.bodyFont(.headline, weight: .bold))
                    Spacer()
                    Text(AwradLocalizer.format("%d recitations", language: language, recitations))
                        .font(AwradTheme.bodyFont(.caption, weight: .semibold))
                        .foregroundStyle(AwradTheme.sage)
                }
                .padding(.horizontal, 4)

                ForEach(wird.parts) { part in
                    Button {
                        openReader(wird: wird, part: part)
                    } label: {
                        WirdPartRow(
                            wird: wird,
                            part: part,
                            summary: summaries[part.id] ?? WirdProgressSummary(completedItems: 0, totalItems: 0),
                            isToday: activeParts.contains(where: { $0.id == part.id }),
                            language: language
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(20)
            .padding(.bottom, 24)
        }
    }

    @ToolbarContentBuilder
    private func detailToolbar(for wird: Wird) -> some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button {
                    prepareReminderDraft(for: wird)
                } label: {
                    Label(reminderLabel(for: wird), systemImage: "bell.fill")
                }
                if quickReminder(in: wird) != nil {
                    Button {
                        turnOffQuickReminder(in: wird)
                    } label: {
                        Label("Turn off reminder", systemImage: "bell.slash")
                    }
                }
                if wird.isCustom {
                    Divider()
                    Button {
                        router.navigate(.editWird(wird.id), in: store.selectedTab)
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }
    }

    private func quickReminder(in wird: Wird) -> WirdReminder? {
        wird.reminders.first {
            $0.id == WirdLifecycleLogic.quickReminderID &&
            $0.enabled &&
            $0.reminderType == .fixedTime &&
            $0.hour != nil &&
            $0.minute != nil
        }
    }

    private func reminderLabel(for wird: Wird) -> String {
        guard let reminder = quickReminder(in: wird),
              let hour = reminder.hour,
              let minute = reminder.minute else {
            return AwradLocalizer.localized("Remind me", language: language)
        }
        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        let date = Calendar.current.date(from: components) ?? Date()
        return date.formatted(date: .omitted, time: .shortened)
    }

    private func prepareReminderDraft(for wird: Wird) {
        var components = DateComponents()
        components.hour = quickReminder(in: wird)?.hour ?? 7
        components.minute = quickReminder(in: wird)?.minute ?? 0
        reminderDraft = Calendar.current.date(from: components) ?? Date()
        showReminderPicker = true
    }

    private func saveQuickReminder(at time: Date) {
        guard let wird = store.wird(id: wirdID) else { return }
        let components = Calendar.current.dateComponents([.hour, .minute], from: time)
        var reminders = wird.reminders
        if let existing = quickReminder(in: wird),
           let index = reminders.firstIndex(where: { $0.id == existing.id }) {
            reminders[index].hour = components.hour
            reminders[index].minute = components.minute
            reminders[index].enabled = true
        } else {
            reminders.append(
                WirdReminder(
                    id: WirdLifecycleLogic.quickReminderID,
                    reminderType: .fixedTime,
                    hour: components.hour ?? 7,
                    minute: components.minute ?? 0,
                    enabled: true
                )
            )
        }
        guard let saved = store.setWirdReminders(wirdID: wird.id, reminders: reminders) else { return }
        Task {
            let result = await services.refreshNotificationsAfterWirdMutation(store: store)
            guard !result.succeeded else { return }
            if let restored = store.setWirdReminders(wirdID: wird.id, reminders: wird.reminders) {
                _ = await services.refreshNotificationsAfterWirdMutation(store: store)
            }
            reminderError = result.localizedFailureMessage(language: language)
            notificationRetry = { saveQuickReminder(at: time) }
        }
    }

    private func turnOffQuickReminder(in wird: Wird) {
        guard let quick = quickReminder(in: wird) else { return }
        let reminders = wird.reminders.filter { $0.id != quick.id }
        guard let saved = store.setWirdReminders(wirdID: wird.id, reminders: reminders) else { return }
        Task {
            let result = await services.refreshNotificationsAfterWirdMutation(store: store)
            guard !result.succeeded else { return }
            if let restored = store.setWirdReminders(wirdID: wird.id, reminders: wird.reminders) {
                _ = await services.refreshNotificationsAfterWirdMutation(store: store)
            }
            reminderError = result.localizedFailureMessage(language: language)
            notificationRetry = { turnOffQuickReminder(in: wird) }
        }
    }

    private func preferredPart(in wird: Wird) -> WirdPart? {
        let active = store.todayParts(for: wird, now: effectiveToday)
        return WirdLifecycleLogic.preferredTodayPart(
            in: wird,
            activeParts: active,
            sessions: store.wirdSessions,
            dateKey: store.todayKey
        ) ?? wird.parts.first
    }

    private func openReader(wird: Wird, part: WirdPart) {
        router.navigate(.wirdReader(wirdID: wird.id, partID: part.id), in: store.selectedTab)
    }

    private func deleteWird() {
        guard store.wird(id: wirdID)?.isCustom == true else { return }
        guard let wird = store.wird(id: wirdID) else { return }
        Task {
            _ = await services.refreshNotificationsAfterWirdMutation(store: store)
            guard store.deleteWird(wirdID) else {
                _ = await services.refreshNotificationsAfterWirdMutation(store: store)
                return
            }
            router.pop(in: store.selectedTab)
        }
    }
}

private struct WirdReminderTimeSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var time: Date
    let onSave: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "bell.badge.fill")
                    .font(AwradTheme.bodyFont(38, weight: .semibold))
                    .foregroundStyle(AwradTheme.sage)
                    .awradGlassIconButton(size: 68, tint: AwradTheme.mint.opacity(0.54))
                DatePicker(
                    LocalizedStringKey("Time"),
                    selection: $time,
                    displayedComponents: .hourAndMinute
                )
                .datePickerStyle(.wheel)
                .labelsHidden()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(24)
            .background(AwradTheme.background)
            .navigationTitle(LocalizedStringKey("Wird reminder"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(LocalizedStringKey("Cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(LocalizedStringKey("Save reminder"), action: onSave)
                        .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - Cards

struct WirdCatalogCard: View {
    let wird: Wird
    let summary: WirdProgressSummary
    let isActiveToday: Bool
    let language: AppLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(wird.displayName(language: language))
                .font(AwradTheme.bodyFont(.title3, weight: .bold))
                .foregroundStyle(AwradTheme.ink)
                .lineLimit(2)

            if !metadata.isEmpty {
                Text(metadata)
                    .font(AwradTheme.bodyFont(.footnote))
                    .foregroundStyle(AwradTheme.subdued)
                    .lineLimit(1)
                    .padding(.top, 6)
            }

            if let tag {
                Text(tag)
                    .font(AwradTheme.bodyFont(.subheadline, weight: .semibold))
                    .foregroundStyle(AwradTheme.sage)
                    .lineLimit(1)
                    .padding(.top, 6)
            }

            if isActiveToday, summary.totalItems > 0 {
                if summary.isComplete {
                    Label {
                        Text(LocalizedStringKey("Done today"))
                    } icon: {
                        Image(systemName: "checkmark")
                    }
                    .font(AwradTheme.bodyFont(.subheadline, weight: .semibold))
                    .foregroundStyle(AwradTheme.sage)
                    .padding(.top, 14)
                } else if summary.progress > 0 {
                    AwradProgressBar(value: summary.progress, height: 6)
                        .padding(.top, 14)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(AwradTheme.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var metadata: String {
        var parts: [String] = []
        let author = wird.author.trimmingCharacters(in: .whitespacesAndNewlines)
        if !author.isEmpty {
            parts.append(author)
        }
        if !wird.parts.isEmpty {
            parts.append(AwradLocalizer.format("%d sections", language: language, wird.parts.count))
        }
        if let minutes = wird.estimatedMinutes, minutes > 0 {
            parts.append(AwradLocalizer.format("%d min", language: language, minutes))
        }
        return parts.joined(separator: " · ")
    }

    private var tag: String? {
        if let tag = wird.tags.first {
            return AwradLocalizer.localized(tag.title, language: language)
        }
        guard wird.schedule.defaultOccasion != .anytime else { return nil }
        return WirdDisplay.occasionLabel(wird.schedule.defaultOccasion, language: language)
    }
}

private struct WirdDetailHeader: View {
    let wird: Wird
    let language: AppLanguage

    var body: some View {
        AwradCard {
            VStack(spacing: 14) {
                if !wird.arabicName.isEmpty {
                    Text(wird.arabicName)
                        .font(AwradTheme.arabicFont(32))
                        .foregroundStyle(AwradTheme.sageDark)
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                        .environment(\.layoutDirection, .rightToLeft)
                }
                Text(wird.displayName(language: language))
                    .font(AwradTheme.displayFont(26))
                    .multilineTextAlignment(.center)
                Text(wird.displayDescription(language: language))
                    .font(AwradTheme.bodyFont(.subheadline))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                if let source = wird.sourceAttribution, !source.isEmpty {
                    Text(source)
                        .font(AwradTheme.bodyFont(.caption, weight: .semibold))
                        .foregroundStyle(AwradTheme.gold)
                        .multilineTextAlignment(.center)
                } else if !wird.author.isEmpty {
                    Text(wird.author)
                        .font(AwradTheme.bodyFont(.caption, weight: .semibold))
                        .foregroundStyle(AwradTheme.gold)
                        .multilineTextAlignment(.center)
                }
                if wird.schedule.defaultOccasion != .anytime {
                    Text(WirdDisplay.occasionLabel(wird.schedule.defaultOccasion, language: language))
                        .font(AwradTheme.bodyFont(.caption, weight: .semibold))
                        .foregroundStyle(AwradTheme.sage)
                }
            }
        }
    }
}

private struct WirdStatRow: View {
    let sectionCount: Int
    let estimatedMinutes: Int?
    let streak: Int
    let language: AppLanguage

    var body: some View {
        HStack(spacing: 10) {
            stat(symbol: "book.pages", value: "\(sectionCount)", label: "Sections")
            stat(
                symbol: "clock",
                value: estimatedMinutes.map { AwradLocalizer.format("%d min", language: language, $0) } ?? "—",
                label: "To recite"
            )
            stat(symbol: "flame.fill", value: "\(streak)", label: "Day streak")
        }
    }

    private func stat(symbol: String, value: String, label: String) -> some View {
        VStack(spacing: 7) {
            Image(systemName: symbol)
                .font(AwradTheme.bodyFont(.title3, weight: .semibold))
                .foregroundStyle(AwradTheme.sage)
            Text(value)
                .font(AwradTheme.bodyFont(.headline, weight: .bold))
                .foregroundStyle(AwradTheme.ink)
                .lineLimit(1)
            Text(LocalizedStringKey(label))
                .font(AwradTheme.bodyFont(.caption2))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .awradGlassSurface(cornerRadius: 18, tint: AwradTheme.surface.opacity(0.68))
    }
}

private struct WirdTodayCard: View {
    let days: [WirdRecentDay]
    let completed: Int
    let total: Int
    let language: AppLanguage

    var body: some View {
        AwradCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text(LocalizedStringKey("Today"))
                        .font(AwradTheme.bodyFont(.headline, weight: .bold))
                    Spacer()
                    Text(AwradLocalizer.format("%d of %d sections", language: language, completed, total))
                        .font(AwradTheme.bodyFont(.caption, weight: .semibold))
                        .foregroundStyle(AwradTheme.sage)
                }
                HStack(spacing: 6) {
                    ForEach(days) { day in
                        VStack(spacing: 8) {
                            Text(day.date.formatted(.dateTime.weekday(.narrow)))
                                .font(AwradTheme.bodyFont(.caption2, weight: .semibold))
                                .foregroundStyle(.secondary)
                            ZStack {
                                Circle()
                                    .fill(day.isComplete ? AwradTheme.sage : Color.clear)
                                    .overlay {
                                        Circle().stroke(
                                            day.isToday ? AwradTheme.gold : AwradTheme.sage.opacity(day.isScheduled ? 0.42 : 0.18),
                                            lineWidth: day.isToday ? 2 : 1
                                        )
                                    }
                                if day.isComplete {
                                    Image(systemName: "checkmark")
                                        .font(AwradTheme.bodyFont(.caption, weight: .bold))
                                        .foregroundStyle(.white)
                                }
                            }
                            .frame(width: 34, height: 34)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }
}

private struct WirdPartRow: View {
    let wird: Wird
    let part: WirdPart
    let summary: WirdProgressSummary
    let isToday: Bool
    let language: AppLanguage

    var body: some View {
        AwradCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(part.displayTitle(language: language))
                            .font(AwradTheme.bodyFont(.headline, weight: .semibold))
                            .foregroundStyle(AwradTheme.ink)
                        Text(part.displaySubtitle(language: language)
                             ?? WirdDisplay.occasionLabel(wird.occasion(for: part), language: language))
                            .font(AwradTheme.bodyFont(.caption))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 6) {
                        if isToday {
                            StatusPill(title: "Today", symbol: "calendar", tint: AwradTheme.gold)
                        }
                        if summary.isComplete {
                            StatusPill(title: "Complete", symbol: "checkmark.circle.fill", tint: AwradTheme.sage)
                        }
                    }
                    Image(systemName: "chevron.right")
                        .font(AwradTheme.bodyFont(.caption, weight: .bold))
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                }

                if summary.totalItems > 0 {
                    AwradProgressBar(value: summary.progress, height: 7)
                    Text(AwradLocalizer.readingProgress(
                        completed: summary.completedItems,
                        total: summary.totalItems,
                        language: language
                    ))
                    .font(AwradTheme.bodyFont(.caption))
                    .foregroundStyle(.secondary)
                }
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(isToday ? AwradTheme.gold.opacity(0.65) : .clear, lineWidth: 1.5)
        }
    }
}


private struct StatusPill: View {
    let titleKey: String?
    let titleText: String?
    let symbol: String
    let tint: Color

    init(title: String, symbol: String, tint: Color) {
        self.titleKey = title
        self.titleText = nil
        self.symbol = symbol
        self.tint = tint
    }

    init(titleText: String, symbol: String, tint: Color) {
        self.titleKey = nil
        self.titleText = titleText
        self.symbol = symbol
        self.tint = tint
    }

    var body: some View {
        Label {
            if let titleKey {
                Text(LocalizedStringKey(titleKey))
            } else {
                Text(titleText ?? "")
            }
        } icon: {
            Image(systemName: symbol)
        }
        .font(AwradTheme.bodyFont(.caption2, weight: .semibold))
        .lineLimit(1)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .foregroundStyle(tint)
        .background(tint.opacity(0.14), in: Capsule())
    }
}
