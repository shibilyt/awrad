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
                    _ = await services.cancelWirdReminders(wirdID: wird.id)
                    guard store.deleteWird(wird.id) else {
                        _ = await services.rescheduleWirdReminders(for: wird, store: store)
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
        let todayPart = WirdLifecycleLogic.preferredTodayPart(
            in: wird,
            activeParts: activeParts,
            sessions: store.wirdSessions,
            dateKey: store.todayKey
        )
        let summary = store.progressSummary(for: wird, now: effectiveToday)
        let streak = store.wirdStreak(for: wird)
        Button {
            router.navigate(.wirdDetail(wird.id), in: store.selectedTab)
        } label: {
            WirdCollectionCard(
                wird: wird,
                todayPart: todayPart,
                summary: summary,
                streak: streak,
                isActiveToday: !activeParts.isEmpty,
                language: language
            )
        }
        .buttonStyle(.plain)
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
            let result = await services.rescheduleWirdReminders(for: saved, store: store)
            guard !result.succeeded else { return }
            if let restored = store.setWirdReminders(wirdID: wird.id, reminders: wird.reminders) {
                _ = await services.rescheduleWirdReminders(for: restored, store: store)
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
            let result = await services.rescheduleWirdReminders(for: saved, store: store)
            guard !result.succeeded else { return }
            if let restored = store.setWirdReminders(wirdID: wird.id, reminders: wird.reminders) {
                _ = await services.rescheduleWirdReminders(for: restored, store: store)
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
            _ = await services.cancelWirdReminders(wirdID: wirdID)
            guard store.deleteWird(wirdID) else {
                _ = await services.rescheduleWirdReminders(for: wird, store: store)
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

// MARK: - Reader

/// Full-screen reader with continuous and page presentations over the same persisted session.
struct WirdReaderView: View {
    @Environment(AwradStore.self) private var store
    @Environment(AppRouter.self) private var router
    let wirdID: AwradID
    let partID: AwradID

    @State private var page = 0
    @State private var finished = false
    @State private var didInit = false
    @State private var mode = WirdReaderMode.continuous

    private var language: AppLanguage { store.preferences.appLanguage }
    private var wird: Wird? { store.wird(id: wirdID) }
    private var part: WirdPart? { wird?.part(id: partID) }
    private var occasionKey: String {
        guard let wird, let part else { return "anytime" }
        return store.occasionKey(for: part, in: wird)
    }

    var body: some View {
        ZStack {
            CinematicBackground().ignoresSafeArea()

            if let wird, let part, !part.segments.isEmpty {
                let summary = store.progressSummary(for: part, wirdID: wird.id, occasionKey: occasionKey)
                let session = store.session(wirdID: wird.id, partID: part.id, occasionKey: occasionKey)

                Group {
                    switch mode {
                    case .continuous:
                        continuousReader(wird: wird, part: part, session: session, summary: summary)
                    case .pages:
                        pager(wird: wird, part: part, session: session)
                    }
                }

                VStack {
                    topBar(wird: wird, part: part, session: session)
                    Spacer()
                }

                if finished {
                    let continuation = continuationPart(in: wird)
                    CinematicCompletionView(
                        wird: wird,
                        streak: store.wirdStreak(for: wird),
                        language: language,
                        onClose: close,
                        onRepeat: { restart(part: part, wird: wird) },
                        nextPartTitle: continuation?.displayTitle(language: language),
                        onContinue: continuation.map { destination in
                            { navigate(to: destination, in: wird) }
                        }
                    )
                    .transition(.opacity.combined(with: .scale(scale: 1.05)))
                }
            } else {
                missing
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .statusBarHidden(true)
        .onAppear(perform: setupInitialPage)
        .onChange(of: partID) { _, _ in
            didInit = false
            finished = false
            page = 0
            setupInitialPage()
        }
    }

    private func continuousReader(
        wird: Wird,
        part: WirdPart,
        session: WirdSession?,
        summary: WirdProgressSummary
    ) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 16) {
                    Color.clear.frame(height: 132)
                    ForEach(Array(part.segments.enumerated()), id: \.element.id) { index, segment in
                        WirdContinuousSegmentCard(
                            segment: segment,
                            language: language,
                            count: session?.count(for: segment.id) ?? 0,
                            target: AwradStore.effectiveTarget(for: segment, in: part),
                            isCurrent: index == page
                        ) {
                            page = index
                            store.updateWirdReadingPosition(
                                wirdID: wird.id,
                                partID: part.id,
                                occasionKey: occasionKey,
                                segmentID: segment.id
                            )
                            tap(segment: segment, index: index, in: part, wird: wird)
                        }
                        .id(segment.id)
                    }

                    if summary.isComplete {
                        Button {
                            withAnimation(.spring(duration: 0.4)) { finished = true }
                        } label: {
                            Label("Finish section", systemImage: "checkmark.seal.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .awradPrimaryButton()
                        .padding(.top, 4)
                    }
                    Color.clear.frame(height: 54)
                }
                .padding(.horizontal, 18)
            }
            .scrollIndicators(.hidden)
            .onAppear { scroll(to: page, in: part, proxy: proxy, animated: false) }
            .onChange(of: page) { _, newValue in
                scroll(to: newValue, in: part, proxy: proxy, animated: true)
            }
        }
    }

    private func scroll(to index: Int, in part: WirdPart, proxy: ScrollViewProxy, animated: Bool) {
        guard let segment = part.segments[safe: index] else { return }
        DispatchQueue.main.async {
            if animated {
                withAnimation(.easeInOut(duration: 0.35)) { proxy.scrollTo(segment.id, anchor: .center) }
            } else {
                proxy.scrollTo(segment.id, anchor: .center)
            }
        }
    }

    private func pager(wird: Wird, part: WirdPart, session: WirdSession?) -> some View {
        TabView(selection: $page) {
            ForEach(Array(part.segments.enumerated()), id: \.element.id) { index, segment in
                CinematicSegmentPage(
                    segment: segment,
                    part: part,
                    language: language,
                    count: session?.count(for: segment.id) ?? 0,
                    target: AwradStore.effectiveTarget(for: segment, in: part)
                ) {
                    tap(segment: segment, index: index, in: part, wird: wird)
                }
                .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .ignoresSafeArea()
        .onChange(of: page) { _, newValue in
            if let segment = part.segments[safe: newValue] {
                store.updateWirdReadingPosition(
                    wirdID: wird.id, partID: part.id, occasionKey: occasionKey, segmentID: segment.id
                )
            }
        }
    }

    private func topBar(wird: Wird, part: WirdPart, session: WirdSession?) -> some View {
        VStack(spacing: 10) {
            HStack {
                Button(action: close) {
                    Image(systemName: "xmark")
                        .font(AwradTheme.bodyFont(.subheadline, weight: .bold))
                        .foregroundStyle(.white.opacity(0.85))
                        .frame(width: 38, height: 38)
                        .background(.white.opacity(0.12), in: Circle())
                }
                Spacer()
                VStack(spacing: 2) {
                    Text(part.displayTitle(language: language))
                        .font(AwradTheme.bodyFont(.subheadline, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))
                    Text("\(min(page + 1, part.segments.count)) / \(part.segments.count)")
                        .font(AwradTheme.bodyFont(.caption2, weight: .semibold))
                        .foregroundStyle(AwradTheme.gold)
                }
                Spacer()
                Menu {
                    ForEach(WirdReaderMode.allCases) { option in
                        Button {
                            mode = option
                        } label: {
                            Label {
                                Text(LocalizedStringKey(option.title))
                            } icon: {
                                Image(systemName: option == mode ? "checkmark" : option.symbol)
                            }
                        }
                    }
                } label: {
                    Image(systemName: mode.symbol)
                        .font(AwradTheme.bodyFont(.subheadline, weight: .bold))
                        .foregroundStyle(.white.opacity(0.85))
                }
                .awradGlassIconButton(size: 38, tint: .white.opacity(0.1))
                .accessibilityLabel(Text(LocalizedStringKey("Reading mode")))
            }
            ProgressView(value: repetitionProgress(for: part, session: session))
                .tint(AwradTheme.gold)
                .scaleEffect(x: 1, y: 0.8)
            HStack {
                if let previous = WirdLifecycleLogic.adjacentPart(
                    in: wird.parts,
                    currentPartID: part.id,
                    direction: .previous
                ) {
                    Button {
                        navigate(to: previous, in: wird)
                    } label: {
                        Label("Previous section", systemImage: "chevron.left")
                    }
                }
                Spacer()
                if let next = WirdLifecycleLogic.adjacentPart(
                    in: wird.parts,
                    currentPartID: part.id,
                    direction: .next
                ) {
                    Button {
                        navigate(to: next, in: wird)
                    } label: {
                        Label("Next section", systemImage: "chevron.right")
                            .labelStyle(.titleAndIcon)
                    }
                }
            }
            .font(AwradTheme.bodyFont(.caption, weight: .semibold))
            .foregroundStyle(.white.opacity(0.78))
        }
        .padding(.horizontal, 18)
        .padding(.top, 12)
    }

    private var missing: some View {
        VStack(spacing: 12) {
            Image(systemName: "book.closed").font(AwradTheme.bodyFont(.largeTitle)).foregroundStyle(.white.opacity(0.6))
            Text(LocalizedStringKey("This reading is no longer available."))
                .foregroundStyle(.white.opacity(0.8))
            Button(LocalizedStringKey("Close"), action: close)
                .foregroundStyle(AwradTheme.gold)
        }
    }

    // MARK: Interaction

    private func tap(segment: WirdSegment, index: Int, in part: WirdPart, wird: Wird) {
        guard segment.isCountable else {
            advance(from: index, in: part, wird: wird)
            return
        }
        let target = AwradStore.effectiveTarget(for: segment, in: part)
        let previous = store.session(wirdID: wird.id, partID: part.id, occasionKey: occasionKey)?.count(for: segment.id) ?? 0
        if previous >= target {
            advance(from: index, in: part, wird: wird)
            return
        }
        let newCount = store.incrementSegment(
            wirdID: wird.id, partID: part.id, occasionKey: occasionKey,
            segmentID: segment.id, target: target
        )
        guard newCount > previous else { return }
        if previous < target && newCount >= target {
            playCompletionHaptic()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                advance(from: index, in: part, wird: wird)
            }
        } else {
            playTapHaptic()
        }
    }

    private func advance(from index: Int, in part: WirdPart, wird: Wird) {
        if index + 1 < part.segments.count {
            withAnimation(.easeInOut(duration: 0.4)) { page = index + 1 }
        } else if store.progressSummary(
            for: part,
            wirdID: wird.id,
            occasionKey: occasionKey
        ).isComplete {
            withAnimation(.spring(duration: 0.4)) { finished = true }
        } else {
            let session = store.session(wirdID: wird.id, partID: part.id, occasionKey: occasionKey)
            withAnimation(.easeInOut(duration: 0.4)) {
                page = WirdLifecycleLogic.resumeIndex(in: part, session: session)
            }
        }
    }

    private func restart(part: WirdPart, wird: Wird) {
        guard store.resetSession(
            wirdID: wird.id,
            partID: part.id,
            occasionKey: occasionKey
        ) else { return }
        withAnimation { finished = false; page = 0 }
    }

    private func close() {
        router.pop(in: store.selectedTab)
    }

    private func setupInitialPage() {
        guard !didInit, let wird, let part else { return }
        didInit = true
        let session = store.session(wirdID: wird.id, partID: part.id, occasionKey: occasionKey)
        page = WirdLifecycleLogic.resumeIndex(in: part, session: session)
        finished = session?.isComplete == true
        if let segment = part.segments[safe: page] {
            store.updateWirdReadingPosition(
                wirdID: wird.id,
                partID: part.id,
                occasionKey: occasionKey,
                segmentID: segment.id
            )
        }
    }

    private func repetitionProgress(for part: WirdPart, session: WirdSession?) -> Double {
        let targets = part.countableSegments.map { segment in
            (segment, AwradStore.effectiveTarget(for: segment, in: part))
        }
        let total = targets.reduce(0) { $0 + $1.1 }
        guard total > 0 else { return 0 }
        let completed = targets.reduce(0) { partial, item in
            partial + min(session?.count(for: item.0.id) ?? 0, item.1)
        }
        return min(Double(completed) / Double(total), 1)
    }

    private func continuationPart(in wird: Wird) -> WirdPart? {
        let effectiveToday = WirdLifecycleLogic.date(from: store.todayKey) ?? Date()
        let activeParts = store.todayParts(for: wird, now: effectiveToday)
        return activeParts.first(where: { candidate in
            guard candidate.id != partID else { return false }
            let key = store.occasionKey(for: candidate, in: wird)
            return !store.progressSummary(for: candidate, wirdID: wird.id, occasionKey: key).isComplete
        })
    }

    private func navigate(to destination: WirdPart, in wird: Wird) {
        router.replaceLast(
            with: .wirdReader(wirdID: wird.id, partID: destination.id),
            in: store.selectedTab
        )
    }

    private func playCompletionHaptic() {
        guard store.preferences.vibrateOnCount else { return }
        #if canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
    }

    private func playTapHaptic() {
        guard store.preferences.vibrateOnCount else { return }
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// MARK: - Cards

private struct WirdCollectionCard: View {
    let wird: Wird
    let todayPart: WirdPart?
    let summary: WirdProgressSummary
    let streak: Int
    let isActiveToday: Bool
    let language: AppLanguage

    var body: some View {
        AwradCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 16) {
                    AwradBundleImage(name: "collection_daily_essentials_light")
                        .scaledToFill()
                        .frame(width: 76, height: 76)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    VStack(alignment: .leading, spacing: 6) {
                        Text(wird.displayName(language: language))
                            .font(AwradTheme.bodyFont(.headline, weight: .semibold))
                            .foregroundStyle(AwradTheme.ink)
                        if !wird.arabicName.isEmpty {
                            Text(wird.arabicName)
                                .font(AwradTheme.arabicFont(22))
                                .foregroundStyle(AwradTheme.sageDark)
                                .lineLimit(1)
                        }
                        Text(wird.displayDescription(language: language))
                            .font(AwradTheme.bodyFont(.caption))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                        if streak > 0 {
                            Label {
                                Text(AwradLocalizer.wirdStreak(streak, language: language))
                            } icon: {
                                Image(systemName: "flame.fill")
                            }
                            .font(AwradTheme.bodyFont(.caption2, weight: .semibold))
                            .foregroundStyle(AwradTheme.gold)
                        }
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(AwradTheme.bodyFont(.caption, weight: .bold))
                        .foregroundStyle(.secondary)
                }

                if let todayPart {
                    Divider()
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            StatusPill(title: "Today", symbol: "calendar", tint: AwradTheme.gold)
                            StatusPill(
                                titleText: WirdDisplay.occasionLabel(wird.occasion(for: todayPart), language: language),
                                symbol: "clock",
                                tint: AwradTheme.sage
                            )
                            if summary.isComplete {
                                StatusPill(title: "Complete", symbol: "checkmark.circle.fill", tint: AwradTheme.sage)
                            }
                            Spacer(minLength: 0)
                        }
                        Text(todayPart.displayTitle(language: language))
                            .font(AwradTheme.bodyFont(.subheadline, weight: .semibold))
                            .foregroundStyle(AwradTheme.ink)
                            .lineLimit(1)
                        AwradProgressBar(value: summary.progress, height: 7)
                        Text(AwradLocalizer.readingProgress(
                            completed: summary.completedItems,
                            total: summary.totalItems,
                            language: language
                        ))
                        .font(AwradTheme.bodyFont(.caption))
                        .foregroundStyle(.secondary)
                    }
                } else if !isActiveToday {
                    Divider()
                    HStack(spacing: 8) {
                        StatusPill(title: "Not scheduled today", symbol: "calendar.badge.minus", tint: .secondary)
                        Text(WirdDisplay.scheduleLabel(wird.schedule, language: language))
                            .font(AwradTheme.bodyFont(.caption))
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                }
            }
        }
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

// MARK: - Cinematic reader components

private struct WirdContinuousSegmentCard: View {
    let segment: WirdSegment
    let language: AppLanguage
    let count: Int
    let target: Int
    let isCurrent: Bool
    let onTap: () -> Void

    private let cream = Color(red: 0.97, green: 0.96, blue: 0.91)

    var body: some View {
        VStack(spacing: 18) {
            switch segment.kind {
            case .heading:
                Text(segment.headingText(language: language) ?? "")
                    .font(AwradTheme.displayFont(26))
                    .foregroundStyle(AwradTheme.gold)
                    .multilineTextAlignment(.center)
            case .instruction:
                Label {
                    Text(segment.headingText(language: language) ?? "")
                        .multilineTextAlignment(.leading)
                } icon: {
                    Image(systemName: "info.circle")
                        .foregroundStyle(AwradTheme.gold)
                }
                .font(AwradTheme.bodyFont(.body))
                .foregroundStyle(cream.opacity(0.82))
            default:
                recitationContent
            }

            if segment.isCountable {
                CountControl(
                    count: min(count, target),
                    target: target,
                    range: segment.repeatSpec.isRange ? segment.repeatSpec.displayText() : nil,
                    action: onTap
                )
            } else {
                Button(action: onTap) {
                    Label("Continue", systemImage: "arrow.down")
                        .font(AwradTheme.bodyFont(.subheadline, weight: .semibold))
                        .foregroundStyle(AwradTheme.gold)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 22)
        .padding(.vertical, 26)
        .background(Color(red: 0.035, green: 0.075, blue: 0.05).opacity(0.96), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(isCurrent ? AwradTheme.gold.opacity(0.75) : .white.opacity(0.08), lineWidth: isCurrent ? 1.5 : 1)
        }
    }

    private var recitationContent: some View {
        VStack(spacing: 16) {
            if let quran = segment.quranRef {
                Text(quran.displayText())
                    .font(AwradTheme.bodyFont(.caption, weight: .semibold))
                    .foregroundStyle(AwradTheme.gold)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(AwradTheme.gold.opacity(0.14), in: Capsule())
            } else if segment.hasAudio {
                Image(systemName: "speaker.wave.2.fill")
                    .foregroundStyle(AwradTheme.gold)
            }
            if !segment.arabic.isEmpty {
                Text(segment.arabic)
                    .font(AwradTheme.arabicFont(32))
                    .foregroundStyle(cream)
                    .multilineTextAlignment(.center)
                    .lineSpacing(12)
                    .environment(\.layoutDirection, .rightToLeft)
            }
            if let transliteration = segment.transliterationText(language: language) {
                Text(transliteration)
                    .font(AwradTheme.bodyFont(.headline, weight: .medium))
                    .foregroundStyle(AwradTheme.gold.opacity(0.95))
                    .multilineTextAlignment(.center)
            }
            if let translation = segment.translationText(language: language) {
                Text(translation)
                    .font(AwradTheme.bodyFont(.body))
                    .foregroundStyle(cream.opacity(0.72))
                    .multilineTextAlignment(.center)
            }
            if let fadl = segment.fadlText(language: language) {
                Text(fadl)
                    .font(AwradTheme.bodyFont(.footnote))
                    .italic()
                    .foregroundStyle(cream.opacity(0.55))
                    .multilineTextAlignment(.center)
            }
        }
    }
}

/// Fixed immersive background (theme-independent so the reader always feels cinematic).
private struct CinematicBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.11, blue: 0.07),
                    Color(red: 0.02, green: 0.05, blue: 0.035),
                    Color(red: 0.01, green: 0.02, blue: 0.015)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            RadialGradient(
                colors: [AwradTheme.sage.opacity(0.28), .clear],
                center: .top,
                startRadius: 0,
                endRadius: 460
            )
        }
    }
}

/// One segment, full-screen. Tapping the count ring (or anywhere in the lower half)
/// increments the count.
private struct CinematicSegmentPage: View {
    let segment: WirdSegment
    let part: WirdPart
    let language: AppLanguage
    let count: Int
    let target: Int
    let onTap: () -> Void

    private let cream = Color(red: 0.97, green: 0.96, blue: 0.91)

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 72)
            ScrollView(.vertical, showsIndicators: false) {
                content
                    .padding(.horizontal, 26)
                    .frame(maxWidth: .infinity)
            }
            Spacer(minLength: 8)
            if segment.isCountable {
                CountControl(count: min(count, target), target: target, range: segment.repeatSpec.isRange ? segment.repeatSpec.displayText() : nil, action: onTap)
                    .padding(.bottom, 54)
            } else {
                continueButton
                    .padding(.bottom, 54)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch segment.kind {
        case .heading:
            Text(segment.headingText(language: language) ?? "")
                .font(AwradTheme.displayFont(30))
                .foregroundStyle(AwradTheme.gold)
                .multilineTextAlignment(.center)
        case .instruction:
            VStack(spacing: 14) {
                Image(systemName: "info.circle").font(AwradTheme.bodyFont(.title2)).foregroundStyle(AwradTheme.gold)
                Text(segment.headingText(language: language) ?? "")
                    .font(AwradTheme.bodyFont(.title3))
                    .foregroundStyle(cream.opacity(0.85))
                    .multilineTextAlignment(.center)
            }
        default:
            VStack(spacing: 22) {
                if let quran = segment.quranRef {
                    pill(quran.displayText())
                } else if segment.hasAudio {
                    Image(systemName: "speaker.wave.2.fill").font(AwradTheme.bodyFont(.footnote)).foregroundStyle(AwradTheme.gold)
                }
                if !segment.arabic.isEmpty {
                    Text(segment.arabic)
                        .font(AwradTheme.arabicFont(36))
                        .foregroundStyle(cream)
                        .multilineTextAlignment(.center)
                        .lineSpacing(14)
                        .environment(\.layoutDirection, .rightToLeft)
                        .shadow(color: .black.opacity(0.35), radius: 12, y: 4)
                }
                if let transliteration = segment.transliterationText(language: language) {
                    Text(transliteration)
                        .font(AwradTheme.bodyFont(.title3, weight: .medium))
                        .foregroundStyle(AwradTheme.gold.opacity(0.95))
                        .multilineTextAlignment(.center)
                }
                if let translation = segment.translationText(language: language) {
                    Text(translation)
                        .font(AwradTheme.bodyFont(.body))
                        .foregroundStyle(cream.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
                if let fadl = segment.fadlText(language: language) {
                    Text(fadl)
                        .font(AwradTheme.bodyFont(.footnote))
                        .italic()
                        .foregroundStyle(cream.opacity(0.55))
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.vertical, 12)
        }
    }

    private func pill(_ text: String) -> some View {
        Text(text)
            .font(AwradTheme.bodyFont(.caption, weight: .semibold))
            .foregroundStyle(AwradTheme.gold)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(AwradTheme.gold.opacity(0.15), in: Capsule())
    }

    private var continueButton: some View {
        Button(action: onTap) {
            Label {
                Text(LocalizedStringKey("Continue"))
            } icon: {
                Image(systemName: "arrow.right")
            }
            .font(AwradTheme.bodyFont(.headline, weight: .semibold))
            .foregroundStyle(Color(red: 0.05, green: 0.11, blue: 0.07))
            .padding(.horizontal, 30)
            .padding(.vertical, 14)
            .background(AwradTheme.gold, in: Capsule())
        }
    }
}

/// Count progress readout sitting on top of a large Count button.
private struct CountControl: View {
    let count: Int
    let target: Int
    let range: String?
    let action: () -> Void

    private var progress: Double { target > 0 ? Double(count) / Double(target) : 0 }
    private var isDone: Bool { count >= target }
    /// A single-recitation item: the tap is a completion gesture, not a tally.
    private var isSingle: Bool { target <= 1 }

    private var buttonTitle: LocalizedStringKey {
        if isDone { return "Recited" }
        return isSingle ? "Mark as recited" : "Recite"
    }

    var body: some View {
        VStack(spacing: 18) {
            // Counter only makes sense for repeated items.
            if !isSingle {
                VStack(spacing: 8) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(count)")
                            .font(AwradTheme.bodyFont(44, weight: .bold))
                            .foregroundStyle(.white)
                            .contentTransition(.numericText())
                            .animation(.snappy(duration: 0.2), value: count)
                        Text("/ \(range ?? "\(target)")")
                            .font(AwradTheme.bodyFont(.title3, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    Capsule()
                        .fill(.white.opacity(0.12))
                        .frame(width: 200, height: 6)
                        .overlay(alignment: .leading) {
                            Capsule()
                                .fill(AwradTheme.gold)
                                .frame(width: 200 * progress, height: 6)
                                .animation(.snappy(duration: 0.25), value: progress)
                        }
                }
            }

            // The recite button.
            Button(action: action) {
                Group {
                    if isDone {
                        Label { Text(buttonTitle) } icon: { Image(systemName: "checkmark") }
                    } else {
                        Text(buttonTitle)
                    }
                }
                .font(AwradTheme.bodyFont(.headline, weight: .bold))
                .tracking(0.5)
                .foregroundStyle(isDone ? AwradTheme.gold : Color(red: 0.05, green: 0.11, blue: 0.07))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(
                    Capsule().fill(isDone ? Color.white.opacity(0.12) : AwradTheme.gold)
                )
                .overlay(
                    Capsule().stroke(AwradTheme.gold.opacity(isDone ? 0.6 : 0), lineWidth: 1.5)
                )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 40)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(buttonTitle)
        .accessibilityValue(isSingle ? Text("") : Text("\(count) of \(target)"))
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(.default, action)
    }
}

/// Shown after the final segment is completed.
private struct CinematicCompletionView: View {
    let wird: Wird
    let streak: Int
    let language: AppLanguage
    let onClose: () -> Void
    let onRepeat: () -> Void
    let nextPartTitle: String?
    let onContinue: (() -> Void)?

    var body: some View {
        ZStack {
            CinematicBackground().ignoresSafeArea()
            VStack(spacing: 22) {
                Image(systemName: "checkmark.seal.fill")
                    .font(AwradTheme.bodyFont(72, weight: .semibold))
                    .foregroundStyle(AwradTheme.gold)
                    .shadow(color: AwradTheme.gold.opacity(0.5), radius: 20)
                Text(LocalizedStringKey("Section Complete"))
                    .font(AwradTheme.bodyFont(.title, weight: .bold))
                    .foregroundStyle(.white)
                Text(wird.displayName(language: language))
                    .font(AwradTheme.bodyFont(.headline, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
                if streak > 0 {
                    Label {
                        Text(AwradLocalizer.wirdStreak(streak, language: language))
                    } icon: {
                        Image(systemName: "flame.fill")
                    }
                    .font(AwradTheme.bodyFont(.subheadline, weight: .semibold))
                    .foregroundStyle(AwradTheme.gold)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.white.opacity(0.08), in: Capsule())
                }
                VStack(spacing: 12) {
                    if let nextPartTitle, let onContinue {
                        Button(action: onContinue) {
                            Label {
                                VStack(spacing: 2) {
                                    Text(LocalizedStringKey("Continue to next section"))
                                    Text(nextPartTitle)
                                        .font(AwradTheme.bodyFont(.caption, weight: .medium))
                                        .opacity(0.72)
                                }
                            } icon: {
                                Image(systemName: "arrow.right.circle.fill")
                            }
                            .font(AwradTheme.bodyFont(.headline, weight: .semibold))
                            .foregroundStyle(Color(red: 0.05, green: 0.11, blue: 0.07))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(AwradTheme.gold, in: Capsule())
                        }
                    }
                    Button(action: onClose) {
                        Text(LocalizedStringKey("Done"))
                            .font(AwradTheme.bodyFont(.headline, weight: .semibold))
                            .foregroundStyle(nextPartTitle == nil ? Color(red: 0.05, green: 0.11, blue: 0.07) : .white.opacity(0.86))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(nextPartTitle == nil ? AwradTheme.gold : .white.opacity(0.1), in: Capsule())
                    }
                    Button(action: onRepeat) {
                        Label {
                            Text(LocalizedStringKey("Read again"))
                        } icon: {
                            Image(systemName: "arrow.counterclockwise")
                        }
                        .font(AwradTheme.bodyFont(.subheadline, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.8))
                    }
                }
                .padding(.top, 8)
                .padding(.horizontal, 40)
            }
            .padding(30)
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
