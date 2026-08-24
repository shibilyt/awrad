import SwiftUI

struct CreateGoalView: View {
    @Environment(AwradStore.self) private var store
    @Environment(AppServices.self) private var services
    @Environment(\.dismiss) private var dismiss

    let defaultDhikrID: AwradID?

    @State private var selectedDhikrID: AwradID?
    @State private var searchText = ""
    @State private var draft = GoalDraft()
    @State private var showDhikrPicker = false
    @State private var isSaving = false
    @State private var saveError: String?

    init(defaultDhikrID: AwradID?) {
        self.defaultDhikrID = defaultDhikrID
        _selectedDhikrID = State(initialValue: defaultDhikrID)
    }

    private var selectedDhikr: Dhikr? {
        selectedDhikrID.flatMap { store.dhikr(id: $0) }
    }

    private var filteredDhikrs: [Dhikr] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let language = store.preferences.appLanguage
        let dhikrs = store.dhikrs.sorted { $0.displayTitle(language: language) < $1.displayTitle(language: language) }
        guard !query.isEmpty else { return dhikrs }
        return dhikrs.filter { dhikr in
            dhikr.localizedSearchText(language: language).contains {
                $0.lowercased().contains(query)
            }
        }
    }

    private var language: AppLanguage { store.preferences.appLanguage }

    private var isCreateEnabled: Bool {
        selectedDhikr != nil && draft.configuration != nil && !isSaving
    }

    var body: some View {
        Group {
            if selectedDhikr == nil {
                dhikrSelectionList
            } else {
                detailsPage
            }
        }
        .background(AwradTheme.background)
        .navigationTitle(selectedDhikr == nil ? "Choose Dhikr" : "Create goal")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                createGoalBackButton
            }
        }
        .safeAreaInset(edge: .bottom) {
            if selectedDhikr != nil, draft.preset == .custom {
                GoalCreateBar(
                    sentence: goalSentence,
                    isEnabled: isCreateEnabled,
                    message: validationHint,
                    onCreate: createGoal
                )
            }
        }
        .sheet(isPresented: $showDhikrPicker) {
            NavigationStack {
                ScrollView {
                    GoalDhikrPickerStep(
                        dhikrs: filteredDhikrs,
                        language: language,
                        searchText: $searchText,
                        onSelect: selectDhikr
                    )
                    .padding(20)
                }
                .background(AwradTheme.background)
                .navigationTitle("Choose Dhikr")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { showDhikrPicker = false }
                    }
                }
            }
            .awradSheetStyle()
        }
        .alert("Couldn’t create goal", isPresented: Binding(
            get: { saveError != nil },
            set: { if !$0 { saveError = nil } }
        )) {
            Button("Retry", action: createGoal)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(saveError ?? "")
        }
    }

    @ViewBuilder
    private var createGoalBackButton: some View {
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
        .accessibilityIdentifier("goal-create-back-button")
    }

    /// Step 1 — pick the dhikr to create a goal for (shown when none chosen yet).
    private var dhikrSelectionList: some View {
        ScrollView(.vertical, showsIndicators: true) {
            GoalDhikrPickerStep(
                dhikrs: filteredDhikrs,
                language: language,
                searchText: $searchText,
                onSelect: selectInitialDhikr
            )
            .padding(20)
        }
    }

    /// Step 2 — quick presets for the chosen dhikr. Advanced keeps the
    /// existing editor below this entry point.
    @ViewBuilder
    private var detailsPage: some View {
        if draft.preset == .custom {
            advancedDetailsPage
        } else {
            quickDetailsPage
        }
    }

    private var quickDetailsPage: some View {
        ScrollView(.vertical, showsIndicators: true) {
            if let selectedDhikr {
                GoalQuickCreateStep(
                    dhikr: selectedDhikr,
                    language: language,
                    draft: $draft,
                    onCreate: createGoal,
                    onAdvanced: enterAdvanced
                )
                .padding(20)
                .padding(.bottom, 28)
            }
        }
    }

    private var advancedDetailsPage: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 18) {
                dhikrSection

                GoalTypeSection(selection: typeBinding)

                perTypeConfiguration

                GoalFineTuneSection(draft: $draft, language: language)
            }
            .padding(20)
            .padding(.bottom, 112)
            .animation(.spring(response: 0.4, dampingFraction: 0.86), value: draft.preset)
            .animation(.spring(response: 0.4, dampingFraction: 0.86), value: draft.timingMode)
            .animation(.spring(response: 0.4, dampingFraction: 0.86), value: draft.countRuleMode)
        }
    }

    @ViewBuilder
    private var dhikrSection: some View {
        if let selectedDhikr {
            Button {
                showDhikrPicker = true
            } label: {
                GoalSelectedDhikrCard(dhikr: selectedDhikr, language: language, showsChange: true)
            }
            .buttonStyle(.plain)
        } else {
            Button {
                showDhikrPicker = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "text.book.closed.fill")
                        .font(AwradTheme.bodyFont(.title3))
                        .foregroundStyle(AwradTheme.sage)
                    Text("Select dhikr")
                        .font(AwradTheme.bodyFont(.headline, weight: .semibold))
                        .foregroundStyle(AwradTheme.ink)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(AwradTheme.bodyFont(.caption, weight: .bold))
                        .foregroundStyle(.secondary)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .awradGlassSurface(cornerRadius: 24, tint: AwradTheme.surface.opacity(0.7), interactive: true)
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var perTypeConfiguration: some View {
        switch typeBinding.wrappedValue {
        case .daily:
            GoalTimingEditor(draft: $draft)
            SlotConfigurationSection(option: .daily, draft: $draft)
        case .oneTime:
            TargetCountControl(
                title: "Total target count",
                text: $draft.targetText,
                presets: [100, 1_000, 10_000]
            )
        case .tracker:
            TrackerExplanationCard()
        case .advanced:
            GoalScheduleEditor(draft: $draft)
            GoalTimingEditor(draft: $draft)
            SlotConfigurationSection(option: .daily, draft: $draft)
            GoalCountRuleEditor(draft: $draft)
        }
    }

    private var typeBinding: Binding<GoalTypeChoice> {
        Binding(
            get: { GoalTypeChoice(preset: draft.preset) },
            set: { selectType($0) }
        )
    }

    private func selectType(_ choice: GoalTypeChoice) {
        let timing = draft.timingMode
        let prayerTiming = draft.prayerTiming
        let prayers = draft.selectedPrayers
        draft = GoalDraft.defaults(for: choice.preset)
        if choice == .daily || choice == .advanced {
            draft.timingMode = timing
            draft.prayerTiming = prayerTiming
            draft.selectedPrayers = prayers
        }
    }

    /// Initial pick from the step-1 list, advancing to the creation page.
    private func selectInitialDhikr(_ dhikr: Dhikr) {
        selectedDhikrID = dhikr.id
        searchText = ""
        draft = GoalDraft.defaults(for: .daily)
    }

    private func enterAdvanced() {
        draft = GoalDraft.defaults(for: .custom)
    }

    /// Re-pick from the "Change" sheet on the creation page.
    private func selectDhikr(_ dhikr: Dhikr) {
        let isChanging = selectedDhikrID != nil && selectedDhikrID != dhikr.id
        selectedDhikrID = dhikr.id
        searchText = ""
        showDhikrPicker = false
        // Changing the dhikr resets goal config to defaults (PRD §3.1).
        if isChanging {
            draft = GoalDraft.defaults(for: .daily)
        }
    }

    private var validationHint: String? {
        guard selectedDhikr != nil else { return "Select a dhikr to continue." }
        return draft.validationMessage
    }

    private var goalSentence: String {
        GoalSentenceBuilder.sentence(
            draft: draft,
            dhikr: selectedDhikr,
            language: language
        )
    }

    private func createGoal() {
        guard !isSaving else { return }
        guard let selectedDhikrID,
              let configuration = draft.configuration,
              let goal = store.createConfiguredGoal(
                dhikrID: selectedDhikrID,
                targetPolicy: configuration.targetPolicy,
                recurrence: configuration.recurrence(forStartDate: store.todayKey),
                slots: configuration.slots,
                reminders: configuration.reminders,
                countPolicy: configuration.countPolicy,
                slotCountingPolicy: configuration.slotCountingPolicy,
                completionPolicy: configuration.completionPolicy,
                durationDays: configuration.durationDays,
                minimumStreakCount: configuration.minimumStreakCount,
                autoCompleteOnTarget: configuration.autoCompleteOnTarget
              ) else {
            return
        }
        isSaving = true
        Task {
            let result = await scheduleGoalReminders(for: goal)
            isSaving = false
            if result.succeeded {
                dismiss()
            } else {
                _ = store.deleteGoal(goal.id)
                _ = await services.refreshNotificationsAfterGoalMutation(goalID: goal.id, store: store)
                saveError = result.localizedFailureMessage(language: language)
            }
        }
    }

    private func scheduleGoalReminders(for goal: Goal) async -> NotificationSchedulingResult {
        await services.refreshNotificationsAfterGoalMutation(goalID: goal.id, store: store)
    }
}

/// The four goal types on the single-page creator. "Advanced" reveals the
/// schedule + count-rule sections inline (it is not a separate screen).
enum GoalTypeChoice: String, CaseIterable, Identifiable {
    case daily
    case oneTime
    case tracker
    case advanced

    var id: String { rawValue }

    init(preset: GoalPreset) {
        switch preset {
        case .oneTime: self = .oneTime
        case .tracker: self = .tracker
        case .custom: self = .advanced
        default: self = .daily
        }
    }

    var preset: GoalPreset {
        switch self {
        case .daily: .daily
        case .oneTime: .oneTime
        case .tracker: .tracker
        case .advanced: .custom
        }
    }

    var title: String {
        switch self {
        case .daily: "Daily"
        case .oneTime: "One-time total"
        case .tracker: "Tracker"
        case .advanced: "Advanced"
        }
    }

    var subtitle: String {
        switch self {
        case .daily: "Repeat a count every day."
        case .oneTime: "Reach a big total over time."
        case .tracker: "Count freely, no target."
        case .advanced: "Full control over schedule & rules."
        }
    }

    var symbol: String {
        switch self {
        case .daily: "calendar"
        case .oneTime: "target"
        case .tracker: "infinity"
        case .advanced: "slider.horizontal.3"
        }
    }
}

private enum QuickGoalOption: String, CaseIterable, Identifiable {
    case daily
    case oneTime
    case tracker

    var id: String { rawValue }

    var title: String {
        switch self {
        case .daily: "Daily"
        case .oneTime: "One-time"
        case .tracker: "Track only"
        }
    }

    var shortTitle: String {
        switch self {
        case .daily: "Daily"
        case .oneTime: "Total"
        case .tracker: "Tracker"
        }
    }

    var subtitle: String {
        switch self {
        case .daily: "Set a daily target and minimum for your streak."
        case .oneTime: "Reach a total once; it does not repeat."
        case .tracker: "Record counts without a completion target."
        }
    }

    var preset: GoalPreset {
        switch self {
        case .daily: .daily
        case .oneTime: .oneTime
        case .tracker: .tracker
        }
    }

    var symbol: String {
        switch self {
        case .daily: "calendar"
        case .oneTime: "target"
        case .tracker: "infinity"
        }
    }

    var targetTitle: String {
        switch self {
        case .daily: "Daily target"
        case .oneTime: "Total target"
        case .tracker: "Target count"
        }
    }

    var presets: [Int] {
        switch self {
        case .daily: [33, 70, 100, 313]
        case .oneTime: [100, 1_000, 10_000]
        case .tracker: []
        }
    }

    var slotPresets: [Int] {
        switch self {
        case .daily: [33, 70, 100]
        case .oneTime: [100, 1_000, 10_000]
        case .tracker: []
        }
    }

    var createTitle: String {
        "Create goal"
    }
}

private struct GoalDhikrPickerStep: View {
    let dhikrs: [Dhikr]
    let language: AppLanguage
    @Binding var searchText: String
    let onSelect: (Dhikr) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            TextField("Search dhikr", text: $searchText)
                .textInputAutocapitalization(.never)
                .padding(.horizontal, 14)
                .frame(minHeight: 46)
                .awradGlassSurface(cornerRadius: 18, tint: AwradTheme.surface.opacity(0.68), interactive: true)

            if dhikrs.isEmpty {
                EmptyStateView(
                    symbol: "text.magnifyingglass",
                    title: "No dhikr found",
                    message: "Try another title, translation, transliteration, or Arabic phrase."
                )
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(dhikrs) { dhikr in
                        GoalDhikrPickerRow(dhikr: dhikr, language: language) {
                            onSelect(dhikr)
                        }
                    }
                }
            }
        }
    }
}

private struct GoalDhikrPickerRow: View {
    let dhikr: Dhikr
    let language: AppLanguage
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 14) {
                Image(systemName: dhikr.category.symbol)
                    .font(AwradTheme.bodyFont(18, weight: .semibold))
                    .foregroundStyle(AwradTheme.sage)
                    .frame(width: 42, height: 42)
                    .background(AwradTheme.mint.opacity(0.24), in: Circle())

                VStack(alignment: .leading, spacing: 5) {
                    Text(dhikr.arabic)
                        .font(AwradTheme.arabicFont(24))
                        .lineLimit(1)
                        .environment(\.layoutDirection, .rightToLeft)
                    Text(dhikr.transliteration.isEmpty ? dhikr.displayTitle(language: language) : dhikr.transliteration)
                        .font(AwradTheme.bodyFont(.subheadline, weight: .semibold))
                        .foregroundStyle(AwradTheme.ink)
                        .lineLimit(1)
                    Text(dhikr.displayTranslation(language: language).isEmpty ? dhikr.category.title : dhikr.displayTranslation(language: language))
                        .font(AwradTheme.bodyFont(.caption))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(AwradTheme.bodyFont(.caption, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .awradGlassSurface(cornerRadius: 22, tint: AwradTheme.surface.opacity(0.72), interactive: true)
        }
        .buttonStyle(.plain)
    }
}

private struct GoalQuickCreateStep: View {
    let dhikr: Dhikr
    let language: AppLanguage
    @Binding var draft: GoalDraft
    let onCreate: () -> Void
    let onAdvanced: () -> Void

    @State private var selectedOption: QuickGoalOption = .daily

    private var isCreateEnabled: Bool {
        draft.configuration != nil
    }

    var body: some View {
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: 18) {
                contentStack
            }
        } else {
            contentStack
        }
    }

    private var contentStack: some View {
        VStack(alignment: .leading, spacing: 16) {
            GoalSelectedDhikrCard(dhikr: dhikr, language: language)

            VStack(alignment: .leading, spacing: 10) {
                Text("Choose goal type")
                    .font(AwradTheme.displayFont(23, weight: .bold))
                    .foregroundStyle(AwradTheme.ink)

                Text("Start with a simple setup. You can add more control later.")
                    .font(AwradTheme.bodyFont(.subheadline))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                quickOptions
            }

            quickConfiguration

            QuickGoalPreviewCard(text: previewText)

            Button(action: onCreate) {
                Text(LocalizedStringKey(selectedOption.createTitle))
                    .font(AwradTheme.bodyFont(.headline, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .foregroundStyle(isCreateEnabled ? .white : AwradTheme.subdued)
                    .awradGlassSurface(
                        cornerRadius: 24,
                        tint: isCreateEnabled ? AwradTheme.sage : AwradTheme.surface.opacity(0.7),
                        interactive: isCreateEnabled
                    )
            }
            .buttonStyle(.plain)
            .disabled(!isCreateEnabled)
            .accessibilityIdentifier("quick-goal-create-button")
        }
    }

    @ViewBuilder
    private var quickOptions: some View {
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: 12) {
                quickOptionsGrid
            }
        } else {
            quickOptionsGrid
        }
    }

    private var quickOptionsGrid: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ],
            spacing: 12
        ) {
            ForEach(QuickGoalOption.allCases) { option in
                QuickGoalOptionCard(
                    option: option,
                    isSelected: selectedOption == option
                ) {
                    selectedOption = option
                    let currentTimingMode = draft.timingMode
                    let currentPrayerTiming = draft.prayerTiming
                    let currentPrayers = draft.selectedPrayers
                    draft = GoalDraft.defaults(for: option.preset)
                    draft.timingMode = currentTimingMode
                    draft.prayerTiming = currentPrayerTiming
                    draft.selectedPrayers = currentPrayers
                }
            }

            AdvancedGoalOptionCard(action: onAdvanced)
        }
    }

    @ViewBuilder
    private var quickConfiguration: some View {
        switch selectedOption {
        case .daily:
            TargetCountControl(
                title: selectedOption.targetTitle,
                text: $draft.targetText,
                presets: selectedOption.presets
            )
            QuickStreakRequirementSection(
                isEnabled: .constant(true),
                minimumText: $draft.minimumStreakText,
                allowsToggle: false
            )
        case .oneTime:
            TargetCountControl(
                title: selectedOption.targetTitle,
                text: $draft.targetText,
                presets: selectedOption.presets
            )
            QuickStreakRequirementSection(
                isEnabled: $draft.minimumStreakEnabled,
                minimumText: $draft.minimumStreakText,
                allowsToggle: true
            )
        case .tracker:
            TrackerExplanationCard()
            QuickStreakRequirementSection(
                isEnabled: $draft.minimumStreakEnabled,
                minimumText: $draft.minimumStreakText,
                allowsToggle: true
            )
        }
    }

    private var previewText: String {
        let title = dhikr.transliteration.isEmpty ? dhikr.displayTitle(language: language) : dhikr.transliteration
        let streak = streakPreview
        if selectedOption == .tracker {
            return AwradLocalizer.format(
                "Track every time you recite %@.",
                language: language,
                title
            ) + streak
        }

        if selectedOption == .oneTime {
            return AwradLocalizer.format(
                "Complete %@ recitations of %@.",
                language: language,
                draft.targetText,
                title
            ) + streak
        }

        switch draft.resolvedTimingMode {
        case .anytime:
            return AwradLocalizer.format(
                "Recite %@ %@ times every day.",
                language: language,
                title,
                draft.targetText
            ) + streak
        case .prayerBased:
            let slotCount = draft.selectedPrayers.count * (draft.prayerTiming == .beforeAndAfter ? 2 : 1)
            return AwradLocalizer.format(
                "Create %d prayer slots for %@, each with its own target.",
                language: language,
                slotCount,
                title
            )
        case .morningEvening:
            return AwradLocalizer.format(
                "Create morning and evening slots for %@.",
                language: language,
                title
            )
        case .timeWindow:
            return AwradLocalizer.format(
                "Create %d time slots for %@, each with its own target.",
                language: language,
                draft.timeSlots.count,
                title
            )
        }
    }

    private var streakPreview: String {
        guard draft.minimumStreakEnabled,
              let minimum = Int(draft.minimumStreakText.trimmingCharacters(in: .whitespacesAndNewlines)),
              minimum > 0 else {
            return ""
        }
        return " " + AwradLocalizer.format(
            "At least %d each day protects your streak.",
            language: language,
            minimum
        )
    }
}

private enum QuickTimingChoice: CaseIterable, Identifiable {
    case anytime
    case prayerSlots
    case timeSlots

    var id: String { title }

    var mode: GoalTimingMode {
        switch self {
        case .anytime: .anytime
        case .prayerSlots: .prayerBased
        case .timeSlots: .timeWindow
        }
    }

    var title: String {
        switch self {
        case .anytime: "Anytime"
        case .prayerSlots: "Prayer slots"
        case .timeSlots: "Time slots"
        }
    }

    var subtitle: String {
        switch self {
        case .anytime: "One flexible slot."
        case .prayerSlots: "Around prayers."
        case .timeSlots: "Custom windows."
        }
    }

    var symbol: String {
        switch self {
        case .anytime: "clock"
        case .prayerSlots: "sun.horizon"
        case .timeSlots: "timer"
        }
    }
}

private struct QuickGoalTimingSection: View {
    @Binding var timingMode: GoalTimingMode

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("When will you count?")
                .font(AwradTheme.displayFont(22, weight: .bold))
                .foregroundStyle(AwradTheme.ink)

            Text("Choose the slots first. Each slot can then carry its own target.")
                .font(AwradTheme.bodyFont(.subheadline))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            timingGrid
        }
    }

    @ViewBuilder
    private var timingGrid: some View {
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: 12) {
                timingGridContent
            }
        } else {
            timingGridContent
        }
    }

    private var timingGridContent: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ],
            spacing: 12
        ) {
            ForEach(QuickTimingChoice.allCases) { choice in
                QuickTimingChoiceCard(
                    choice: choice,
                    isSelected: timingMode == choice.mode
                ) {
                    timingMode = choice.mode
                }
            }
        }
    }
}

private struct GlassSelectionMark: View {
    let isSelected: Bool

    var body: some View {
        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
            .font(AwradTheme.bodyFont(20, weight: .semibold))
            .foregroundStyle(isSelected ? .white : AwradTheme.subdued.opacity(0.72))
            .symbolRenderingMode(.hierarchical)
    }
}

private struct GlassOptionIcon: View {
    let symbol: String
    let isSelected: Bool

    var body: some View {
        Image(systemName: symbol)
            .font(AwradTheme.bodyFont(17, weight: .semibold))
            .foregroundStyle(isSelected ? .white : AwradTheme.sageDark)
            .frame(width: 38, height: 38)
            .awradGlassSurface(
                cornerRadius: 19,
                tint: isSelected ? Color.white.opacity(0.18) : AwradTheme.mint.opacity(0.44),
                interactive: false
            )
    }
}

private struct QuickTimingChoiceCard: View {
    let choice: QuickTimingChoice
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 9) {
                HStack(alignment: .top) {
                    GlassOptionIcon(symbol: choice.symbol, isSelected: isSelected)
                    Spacer(minLength: 0)
                    GlassSelectionMark(isSelected: isSelected)
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text(LocalizedStringKey(choice.title))
                        .font(AwradTheme.bodyFont(.headline, weight: .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)

                    Text(LocalizedStringKey(choice.subtitle))
                        .font(AwradTheme.bodyFont(.caption, weight: .medium))
                        .foregroundStyle(isSelected ? .white.opacity(0.84) : .secondary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.82)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .foregroundStyle(isSelected ? .white : AwradTheme.ink)
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 108, alignment: .topLeading)
            .awradGlassSurface(
                cornerRadius: 24,
                tint: isSelected ? AwradTheme.sage.opacity(0.94) : AwradTheme.surface.opacity(0.58),
                interactive: true
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(choice.title)
    }
}

private struct SlotConfigurationSection: View {
    let option: QuickGoalOption
    @Binding var draft: GoalDraft

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("How many times?")
                .font(AwradTheme.displayFont(22, weight: .bold))
                .foregroundStyle(AwradTheme.ink)

            Text(sectionSubtitle)
                .font(AwradTheme.bodyFont(.subheadline))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            switch draft.resolvedTimingMode {
            case .anytime:
                anytimeSlot
            case .prayerBased:
                prayerSlots
            case .morningEvening:
                timeSlots
            case .timeWindow:
                timeSlots
            }
        }
    }

    private var sectionSubtitle: String {
        option == .tracker
            ? "Every recitation is counted — no target to reach."
            : "Set how many times you'll recite for each session."
    }

    @ViewBuilder
    private var anytimeSlot: some View {
        if option == .tracker {
            NoTargetSlotCard(title: "Anytime")
        } else {
            SlotTargetCard(
                title: "Anytime",
                text: $draft.targetText,
                presets: option.presets
            )
        }
    }

    private var prayerSlots: some View {
        VStack(alignment: .leading, spacing: 12) {
            AwradBottomSheetPicker(
                title: "Prayer timing",
                selection: $draft.prayerTiming,
                options: PrayerTiming.allCases
            ) { $0.title }
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, minHeight: 50)
            .awradGlassSurface(cornerRadius: 18, tint: AwradTheme.surface.opacity(0.62), interactive: true)

            PrayerPicker(selectedPrayers: $draft.selectedPrayers)

            if draft.selectedPrayers.isEmpty {
                Text("Select at least one prayer.")
                    .font(AwradTheme.bodyFont(.footnote, weight: .semibold))
                    .foregroundStyle(.red)
            } else {
                ForEach(Prayer.allCases.filter { draft.selectedPrayers.contains($0) }) { prayer in
                    if option == .tracker {
                        NoTargetSlotCard(title: slotTitle(for: prayer))
                    } else {
                        SlotTargetCard(
                            title: slotTitle(for: prayer),
                            text: prayerTargetBinding(for: prayer),
                            presets: option.slotPresets
                        )
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var timeSlots: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(draft.timeSlots) { timeSlot in
                if let index = draft.timeSlots.firstIndex(where: { $0.id == timeSlot.id }) {
                    TimeSlotEditorCard(
                        title: timeSlot.displayLabel(fallbackIndex: index + 1),
                        slot: $draft.timeSlots[index],
                        showsTarget: option != .tracker,
                        presets: option.slotPresets,
                        canRemove: draft.timeSlots.count > 1
                    ) {
                        draft.removeTimeSlot(id: timeSlot.id)
                    }
                }
            }

            Button {
                draft.addTimeSlot()
            } label: {
                Label("Add Time Slot", systemImage: "plus.circle.fill")
                    .font(AwradTheme.bodyFont(.subheadline, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .foregroundStyle(AwradTheme.sageDark)
                    .awradGlassSurface(cornerRadius: 18, tint: AwradTheme.mint.opacity(0.48), interactive: true)
            }
            .buttonStyle(.plain)
        }
    }

    private func slotTitle(for prayer: Prayer) -> String {
        switch draft.prayerTiming {
        case .before:
            return "Before \(prayer.title)"
        case .after:
            return "After \(prayer.title)"
        case .beforeAndAfter:
            return "\(prayer.title) slots"
        }
    }

    private func prayerTargetBinding(for prayer: Prayer) -> Binding<String> {
        Binding(
            get: {
                draft.prayerTargetText(for: prayer)
            },
            set: { newValue in
                draft.setPrayerTargetText(newValue, for: prayer)
            }
        )
    }
}

private struct SlotTargetCard: View {
    let title: String
    @Binding var text: String
    let presets: [Int]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TargetCountControl(
                title: "\(title) target",
                text: $text,
                presets: presets
            )
        }
        .padding(16)
        .awradGlassSurface(cornerRadius: 24, tint: AwradTheme.surface.opacity(0.68))
    }
}

private struct NoTargetSlotCard: View {
    let title: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "infinity")
                .font(AwradTheme.bodyFont(20, weight: .semibold))
                .foregroundStyle(AwradTheme.sage)
                .frame(width: 42, height: 42)
                .background(AwradTheme.mint.opacity(0.22), in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(LocalizedStringKey(title))
                    .font(AwradTheme.bodyFont(.headline, weight: .semibold))
                    .foregroundStyle(AwradTheme.ink)
                Text("No target. Every count is recorded.")
                    .font(AwradTheme.bodyFont(.subheadline))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .awradGlassSurface(cornerRadius: 24, tint: AwradTheme.surface.opacity(0.68))
    }
}

private struct TimeSlotEditorCard: View {
    let title: String
    @Binding var slot: GoalTimeSlotDraft
    let showsTarget: Bool
    let presets: [Int]
    let canRemove: Bool
    let onRemove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                GoalTextField(title: "Slot name", text: $slot.labelText, prompt: title)

                Button(action: onRemove) {
                    Image(systemName: "trash")
                        .font(AwradTheme.bodyFont(16, weight: .semibold))
                        .foregroundStyle(canRemove ? AwradTheme.subdued : AwradTheme.subdued.opacity(0.35))
                        .frame(width: 42, height: 44)
                        .awradGlassSurface(cornerRadius: 16, tint: AwradTheme.surface.opacity(0.58), interactive: canRemove)
                }
                .buttonStyle(.plain)
                .disabled(!canRemove)
                .accessibilityLabel("Remove \(title)")
            }

            TimeSlotTimingControls(slot: $slot)

            if showsTarget {
                TargetCountControl(
                    title: "\(slot.displayLabel(fallbackIndex: 1)) target",
                    text: $slot.targetText,
                    presets: presets
                )
            } else {
                Text("No target. Every count is recorded.")
                    .font(AwradTheme.bodyFont(.subheadline))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .awradGlassSurface(cornerRadius: 24, tint: AwradTheme.surface.opacity(0.68))
    }
}

private struct TimeSlotTimingCard: View {
    let title: String
    @Binding var slot: GoalTimeSlotDraft
    var language: AppLanguage = .english
    let canRemove: Bool
    let onRemove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                GoalTextField(title: "Slot name", text: $slot.labelText, prompt: title)

                Button(action: onRemove) {
                    Image(systemName: "trash")
                        .font(AwradTheme.bodyFont(16, weight: .semibold))
                        .foregroundStyle(canRemove ? AwradTheme.subdued : AwradTheme.subdued.opacity(0.35))
                        .frame(width: 42, height: 44)
                        .awradGlassSurface(cornerRadius: 16, tint: AwradTheme.surface.opacity(0.58), interactive: canRemove)
                }
                .buttonStyle(.plain)
                .disabled(!canRemove)
                .accessibilityLabel("Remove \(title)")
            }

            TimeSlotTimingControls(slot: $slot, language: language)
        }
        .padding(.vertical, 4)
    }
}

private struct TimeSlotTimingControls: View {
    @Binding var slot: GoalTimeSlotDraft
    var language: AppLanguage = .english

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Window")
                    .font(AwradTheme.bodyFont(.subheadline, weight: .semibold))
                    .foregroundStyle(AwradTheme.ink)
                Spacer()
                Text(slot.timeRangeText)
                    .font(AwradTheme.bodyFont(.subheadline).monospacedDigit().weight(.semibold))
                    .foregroundStyle(AwradTheme.sage)
            }

            Stepper(value: $slot.startHour, in: 0...23) {
                Text(AwradLocalizer.format("Start hour %d", language: language, slot.startHour))
            }

            Stepper(value: $slot.startMinute, in: 0...59, step: 5) {
                Text(AwradLocalizer.format("Start minute %d", language: language, slot.startMinute))
            }

            Stepper(value: $slot.durationMinutes, in: 15...360, step: 15) {
                Text(AwradLocalizer.format("%d minutes", language: language, slot.durationMinutes))
            }
        }
    }
}

private struct QuickGoalOptionCard: View {
    let option: QuickGoalOption
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    GlassOptionIcon(symbol: option.symbol, isSelected: isSelected)
                    Spacer(minLength: 0)
                    GlassSelectionMark(isSelected: isSelected)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(LocalizedStringKey(option.title))
                        .font(AwradTheme.bodyFont(.headline, weight: .semibold))
                        .lineLimit(2)
                        .minimumScaleFactor(0.82)

                    Text(LocalizedStringKey(option.subtitle))
                        .font(AwradTheme.bodyFont(.caption, weight: .medium))
                        .foregroundStyle(isSelected ? .white.opacity(0.84) : .secondary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.82)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .foregroundStyle(isSelected ? .white : AwradTheme.ink)
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 118, alignment: .topLeading)
            .awradGlassSurface(
                cornerRadius: 26,
                tint: isSelected ? AwradTheme.sage.opacity(0.94) : AwradTheme.surface.opacity(0.58),
                interactive: true
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(option.title)
        .accessibilityIdentifier("quick-goal-option-\(option.rawValue)")
    }
}

private struct AdvancedGoalOptionCard: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    GlassOptionIcon(symbol: "slider.horizontal.3", isSelected: false)
                    Spacer(minLength: 0)

                    Image(systemName: "chevron.right")
                        .font(AwradTheme.bodyFont(.caption, weight: .bold))
                        .foregroundStyle(AwradTheme.sage)
                        .frame(width: 30, height: 30)
                        .awradGlassSurface(cornerRadius: 15, tint: AwradTheme.surface.opacity(0.52), interactive: false)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Advanced")
                        .font(AwradTheme.bodyFont(.headline, weight: .semibold))
                        .lineLimit(2)

                    Text("Configure schedule, slots, and reminders.")
                        .font(AwradTheme.bodyFont(.caption, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.82)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .foregroundStyle(AwradTheme.ink)
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 118, alignment: .topLeading)
            .awradGlassSurface(cornerRadius: 26, tint: AwradTheme.surface.opacity(0.58), interactive: true)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Advanced")
        .accessibilityIdentifier("quick-goal-option-advanced")
    }
}

private struct TargetCountControl: View {
    let title: String
    @Binding var text: String
    let presets: [Int]

    private var count: Int {
        Int(text.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(LocalizedStringKey(title))
                .font(AwradTheme.bodyFont(.headline, weight: .semibold))
                .foregroundStyle(AwradTheme.ink)

            HStack(spacing: 10) {
                CountStepperButton(symbol: "minus") {
                    setCount(max(count - 1, 1))
                }
                .disabled(count <= 1)

                TextField("0", text: $text)
                    .keyboardType(.numberPad)
                    .font(AwradTheme.displayFont(36, weight: .semibold))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(AwradTheme.ink)
                    .frame(maxWidth: .infinity, minHeight: 58)
                    .padding(.horizontal, 12)
                    .awradGlassSurface(cornerRadius: 20, tint: AwradTheme.surface.opacity(0.62), interactive: true)
                    .onChange(of: text) { _, newValue in
                        text = newValue.filter(\.isNumber)
                    }

                CountStepperButton(symbol: "plus") {
                    setCount(count + 1)
                }
            }

            HStack {
                Spacer(minLength: 0)
                HStack(spacing: 8) {
                    ForEach(presets, id: \.self) { preset in
                        Button {
                            setCount(preset)
                        } label: {
                            Text(preset.formatted())
                                .font(AwradTheme.bodyFont(.subheadline, weight: .semibold))
                                .foregroundStyle(count == preset ? .white : AwradTheme.ink)
                                .padding(.horizontal, 14)
                                .frame(height: 38)
                                .awradGlassSurface(
                                    cornerRadius: 16,
                                    tint: count == preset ? AwradTheme.sage : AwradTheme.surface.opacity(0.62),
                                    interactive: true
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                Spacer(minLength: 0)
            }
        }
    }

    private func setCount(_ value: Int) {
        text = "\(max(value, 1))"
    }
}

private struct CountStepperButton: View {
    let symbol: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(AwradTheme.bodyFont(20, weight: .bold))
                .foregroundStyle(AwradTheme.sageDark)
                .frame(width: 54, height: 58)
                .awradGlassSurface(cornerRadius: 20, tint: AwradTheme.mint.opacity(0.58), interactive: true)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(symbol == "plus" ? "Increase count" : "Decrease count")
    }
}

private struct TrackerExplanationCard: View {
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "infinity")
                .font(AwradTheme.bodyFont(24, weight: .semibold))
                .foregroundStyle(AwradTheme.sage)
                .frame(width: 48, height: 48)
                .background(AwradTheme.mint.opacity(0.22), in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text("Track only")
                    .font(AwradTheme.bodyFont(.headline, weight: .semibold))
                    .foregroundStyle(AwradTheme.ink)
                Text("This goal has no completion target. Every count is recorded.")
                    .font(AwradTheme.bodyFont(.subheadline))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .awradGlassSurface(cornerRadius: 24, tint: AwradTheme.surface.opacity(0.7))
    }
}

private struct QuickStreakRequirementSection: View {
    @Binding var isEnabled: Bool
    @Binding var minimumText: String
    let allowsToggle: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if allowsToggle {
                Toggle("Build a daily streak", isOn: $isEnabled)
                    .tint(AwradTheme.sage)
                    .accessibilityIdentifier("quick-goal-streak-toggle")
            } else {
                Text("Minimum for streak")
                    .font(AwradTheme.bodyFont(.headline, weight: .semibold))
                    .foregroundStyle(AwradTheme.ink)
            }

            if isEnabled {
                GoalNumberField(
                    title: allowsToggle ? "Minimum per day" : "Minimum for streak",
                    text: $minimumText
                )
                .accessibilityIdentifier("quick-goal-minimum-streak-field")

                Text("A day counts toward your streak after this many recitations.")
                    .font(AwradTheme.bodyFont(.caption))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .awradGlassSurface(cornerRadius: 24, tint: AwradTheme.surface.opacity(0.7))
    }
}

private struct QuickGoalPreviewCard: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Preview")
                .font(AwradTheme.bodyFont(.subheadline, weight: .semibold))
                .foregroundStyle(AwradTheme.sage)
            Text(text)
                .font(AwradTheme.bodyFont(.headline, weight: .semibold))
                .foregroundStyle(AwradTheme.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .awradGlassSurface(cornerRadius: 24, tint: AwradTheme.surface.opacity(0.68))
    }
}

private struct AdvancedGoalFooter: View {
    let primaryTitle: String
    let isPrimaryEnabled: Bool
    let onBack: () -> Void
    let onPrimary: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onBack) {
                Text("Back")
                    .font(AwradTheme.bodyFont(.subheadline, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .foregroundStyle(AwradTheme.ink)
                    .awradGlassSurface(cornerRadius: 22, tint: AwradTheme.surface.opacity(0.74), interactive: true)
            }
            .buttonStyle(.plain)

            Button(action: onPrimary) {
                Text(LocalizedStringKey(primaryTitle))
                    .font(AwradTheme.bodyFont(.headline, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .foregroundStyle(isPrimaryEnabled ? .white : AwradTheme.subdued)
                    .awradGlassSurface(
                        cornerRadius: 22,
                        tint: isPrimaryEnabled ? AwradTheme.sage : AwradTheme.surface.opacity(0.74),
                        interactive: isPrimaryEnabled
                    )
            }
            .buttonStyle(.plain)
            .disabled(!isPrimaryEnabled)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 10)
        .background(.ultraThinMaterial)
    }
}

private struct AdvancedStepShell<Content: View>: View {
    let stepIndex: Int
    let title: String
    let subtitle: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            AdvancedStepProgress(currentIndex: stepIndex)

            VStack(alignment: .leading, spacing: 6) {
                Text(LocalizedStringKey(title))
                    .font(AwradTheme.displayFont(30, weight: .bold))
                    .foregroundStyle(AwradTheme.ink)
                Text(LocalizedStringKey(subtitle))
                    .font(AwradTheme.bodyFont(.subheadline))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            content
        }
    }
}

private struct AdvancedStepProgress: View {
    let currentIndex: Int

    private let labels = ["Schedule", "Timing", "Targets", "Preview"]

    var body: some View {
        HStack(spacing: 8) {
            ForEach(labels.indices, id: \.self) { index in
                VStack(spacing: 6) {
                    Capsule()
                        .fill(index <= currentIndex ? AwradTheme.sage : AwradTheme.mint.opacity(0.3))
                        .frame(height: 5)
                    Text(labels[index])
                        .font(AwradTheme.bodyFont(.caption2, weight: .semibold))
                        .foregroundStyle(index == currentIndex ? AwradTheme.ink : .secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }
            }
        }
        .padding(.horizontal, 4)
    }
}

private struct AdvancedScheduleStep: View {
    let dhikr: Dhikr
    @Binding var draft: GoalDraft
    let language: AppLanguage

    var body: some View {
        AdvancedStepShell(
            stepIndex: 0,
            title: "Select schedule",
            subtitle: "Choose how often this goal should be due."
        ) {
            GoalSelectedDhikrCard(dhikr: dhikr, language: language, preset: .custom)

            AdvancedEditorSection(title: "Schedule", symbol: "calendar") {
                AdvancedPickerRow(
                    title: "Repeat",
                    value: draft.customFrequency.title,
                    selection: $draft.customFrequency
                ) {
                    ForEach(RecurrenceFrequency.allCases) { frequency in
                        Text(LocalizedStringKey(frequency.title)).tag(frequency)
                    }
                }

                if showsCalendarRow {
                    AdvancedPickerRow(
                        title: "Calendar",
                        value: draft.customCalendar.title,
                        selection: $draft.customCalendar
                    ) {
                        ForEach(CalendarSystem.allCases) { calendar in
                            Text(LocalizedStringKey(calendar.title)).tag(calendar)
                        }
                    }
                }

                scheduleDetails
            }
        }
    }

    private var showsCalendarRow: Bool {
        switch draft.customFrequency {
        case .monthly, .yearly:
            true
        case .daily, .weekly, .interval, .season, .specificDates:
            false
        }
    }

    @ViewBuilder
    private var scheduleDetails: some View {
        switch draft.customFrequency {
        case .daily:
            AdvancedInfoRow(title: "Due", value: "Every day")
        case .weekly:
            WeekdaySelectRow(selectedWeekdays: $draft.selectedWeekdays)
        case .monthly:
            GoalTextField(title: "Days of month", text: $draft.monthDaysText, prompt: "1, 15, 29")
        case .interval:
            GoalNumberField(title: "Every N days", text: $draft.intervalDaysText)
        case .yearly:
            AdvancedPickerRow(
                title: "Month",
                value: Calendar.current.monthSymbols[(draft.yearlyMonth - 1).clamped(to: 0...11)],
                selection: $draft.yearlyMonth
            ) {
                ForEach(1...12, id: \.self) { month in
                    Text(Calendar.current.monthSymbols[month - 1]).tag(month)
                }
            }
            GoalTextField(title: "Days", text: $draft.monthDaysText, prompt: "1, 10")
        case .season:
            AdvancedPickerRow(
                title: "Season",
                value: draft.seasonTemplate.title,
                selection: $draft.seasonTemplate
            ) {
                ForEach(SeasonTemplateCode.allCases) { season in
                    Text(LocalizedStringKey(season.title)).tag(season)
                }
            }
        case .specificDates:
            GoalTextField(title: "Specific dates", text: $draft.specificDatesText, prompt: "2026-06-01, 2026-06-15")
        }
    }
}

private enum AdvancedTimingChoice: CaseIterable, Identifiable {
    case anytime
    case prayerBased
    case morningEvening
    case customSlots

    var id: String { title }

    var mode: GoalTimingMode {
        switch self {
        case .anytime: .anytime
        case .prayerBased: .prayerBased
        case .morningEvening: .morningEvening
        case .customSlots: .timeWindow
        }
    }

    var title: String {
        switch self {
        case .anytime: "Anytime"
        case .prayerBased: "Prayer-based"
        case .morningEvening: "Morning/evening"
        case .customSlots: "Custom slots"
        }
    }

    var subtitle: String {
        switch self {
        case .anytime: "One flexible slot."
        case .prayerBased: "Before or after prayers."
        case .morningEvening: "Two daily windows."
        case .customSlots: "Set your own windows."
        }
    }

    var symbol: String {
        switch self {
        case .anytime: "clock"
        case .prayerBased: "sun.horizon"
        case .morningEvening: "sunrise"
        case .customSlots: "timer"
        }
    }
}

private struct AdvancedTimingStep: View {
    let dhikr: Dhikr
    @Binding var draft: GoalDraft
    let language: AppLanguage

    var body: some View {
        AdvancedStepShell(
            stepIndex: 1,
            title: "Choose timing",
            subtitle: "Timing creates the count slots for this goal."
        ) {
            GoalSelectedDhikrCard(dhikr: dhikr, language: language, preset: .custom)

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12)
                ],
                spacing: 12
            ) {
                ForEach(AdvancedTimingChoice.allCases) { choice in
                    AdvancedTimingChoiceCard(
                        choice: choice,
                        isSelected: draft.timingMode == choice.mode
                    ) {
                        draft.timingMode = choice.mode
                    }
                }
            }

            AdvancedEditorSection(title: "Slots", symbol: "clock") {
                switch draft.resolvedTimingMode {
                case .anytime:
                    AdvancedInfoRow(title: "Anytime", value: "Open all day")
                case .prayerBased:
                    AdvancedPickerRow(
                        title: "Relation",
                        value: draft.prayerTiming.title,
                        selection: $draft.prayerTiming
                    ) {
                        ForEach(PrayerTiming.allCases) { timing in
                            Text(LocalizedStringKey(timing.title)).tag(timing)
                        }
                    }
                    PrayerPicker(selectedPrayers: $draft.selectedPrayers)
                case .morningEvening:
                    AdvancedInfoRow(title: "Morning", value: "05:00-11:00")
                    AdvancedInfoRow(title: "Evening", value: "17:00-22:00")
                case .timeWindow:
                    AdvancedTimeSlotRows(draft: $draft, language: language)
                }
            }
        }
    }
}

private struct AdvancedTimingChoiceCard: View {
    let choice: AdvancedTimingChoice
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: choice.symbol)
                        .font(AwradTheme.bodyFont(17, weight: .semibold))
                        .frame(width: 34, height: 34)
                        .background((isSelected ? Color.white : AwradTheme.mint).opacity(0.22), in: Circle())
                    Spacer(minLength: 0)
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(AwradTheme.bodyFont(18, weight: .semibold))
                        .foregroundStyle(isSelected ? .white : AwradTheme.subdued.opacity(0.72))
                }
                Text(LocalizedStringKey(choice.title))
                    .font(AwradTheme.bodyFont(.subheadline, weight: .semibold))
                    .lineLimit(2)
                    .minimumScaleFactor(0.78)
                Text(LocalizedStringKey(choice.subtitle))
                    .font(AwradTheme.bodyFont(.caption))
                    .foregroundStyle(isSelected ? .white.opacity(0.84) : .secondary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.78)
            }
            .foregroundStyle(isSelected ? .white : AwradTheme.ink)
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 124, alignment: .topLeading)
            .awradGlassSurface(
                cornerRadius: 22,
                tint: isSelected ? AwradTheme.sage : AwradTheme.surface.opacity(0.72),
                interactive: true
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(choice.title)
    }
}

private struct TimeSlotEditorSelection: Identifiable {
    let id: AwradID
}

private struct AdvancedTimeSlotRows: View {
    @Binding var draft: GoalDraft
    let language: AppLanguage
    @State private var editingSelection: TimeSlotEditorSelection?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(draft.timeSlots) { timeSlot in
                if let index = draft.timeSlots.firstIndex(where: { $0.id == timeSlot.id }) {
                    HStack(spacing: 8) {
                        Button {
                            editingSelection = TimeSlotEditorSelection(id: timeSlot.id)
                        } label: {
                            AdvancedTimeSlotRow(
                                title: draft.timeSlots[index].displayLabel(fallbackIndex: index + 1),
                                range: draft.timeSlots[index].timeRangeText
                            )
                        }
                        .buttonStyle(.plain)

                        Button {
                            draft.removeTimeSlot(id: timeSlot.id)
                        } label: {
                            Image(systemName: "trash")
                                .font(AwradTheme.bodyFont(15, weight: .semibold))
                                .foregroundStyle(draft.timeSlots.count > 1 ? AwradTheme.subdued : AwradTheme.subdued.opacity(0.35))
                                .frame(width: 42, height: 44)
                                .awradGlassSurface(cornerRadius: 16, tint: AwradTheme.surface.opacity(0.58), interactive: draft.timeSlots.count > 1)
                        }
                        .buttonStyle(.plain)
                        .disabled(draft.timeSlots.count <= 1)
                        .accessibilityLabel("Remove \(timeSlot.displayLabel(fallbackIndex: index + 1))")
                    }
                }
            }

            Button {
                draft.addTimeSlot()
            } label: {
                Label("Add Time Slot", systemImage: "plus.circle.fill")
                    .font(AwradTheme.bodyFont(.subheadline, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .foregroundStyle(AwradTheme.sageDark)
                    .awradGlassSurface(cornerRadius: 16, tint: AwradTheme.mint.opacity(0.48), interactive: true)
            }
            .buttonStyle(.plain)
        }
        .sheet(item: $editingSelection) { selection in
            if let binding = slotBinding(for: selection.id) {
                AdvancedTimeSlotEditorSheet(slot: binding)
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
                    .awradSheetStyle()
            }
        }
    }

    private func slotBinding(for id: AwradID) -> Binding<GoalTimeSlotDraft>? {
        guard let index = draft.timeSlots.firstIndex(where: { $0.id == id }) else { return nil }
        return $draft.timeSlots[index]
    }
}

private struct AdvancedTimeSlotRow: View {
    let title: String
    let range: String

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(LocalizedStringKey(title))
                    .font(AwradTheme.bodyFont(.subheadline, weight: .semibold))
                    .foregroundStyle(AwradTheme.ink)
                Text("Time window")
                    .font(AwradTheme.bodyFont(.caption))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Text(range)
                .font(AwradTheme.bodyFont(.subheadline).monospacedDigit().weight(.semibold))
                .foregroundStyle(AwradTheme.sage)
            Image(systemName: "chevron.right")
                .font(AwradTheme.bodyFont(.caption, weight: .bold))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, minHeight: 58)
        .awradGlassSurface(cornerRadius: 18, tint: AwradTheme.surface.opacity(0.62), interactive: true)
    }
}

private struct AdvancedTimeSlotEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var slot: GoalTimeSlotDraft

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                GoalTextField(title: "Slot name", text: $slot.labelText, prompt: "Morning")

                DatePicker("Starts", selection: startDateBinding, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.compact)
                DatePicker("Ends", selection: endDateBinding, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.compact)

                AdvancedInfoRow(title: "Window", value: slot.timeRangeText)

                Spacer(minLength: 0)
            }
            .padding(20)
            .background(AwradTheme.background)
            .navigationTitle("Edit Slot")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var startDateBinding: Binding<Date> {
        Binding(
            get: { date(for: slot.startMinuteOfDay) },
            set: { date in
                let minute = minuteOfDay(for: date)
                slot.startHour = minute / 60
                slot.startMinute = minute % 60
                if slot.endMinuteOfDay <= slot.startMinuteOfDay {
                    slot.durationMinutes = 60
                }
            }
        )
    }

    private var endDateBinding: Binding<Date> {
        Binding(
            get: { date(for: max(slot.endMinuteOfDay, slot.startMinuteOfDay + 15)) },
            set: { date in
                let minute = minuteOfDay(for: date)
                slot.durationMinutes = max(minute - slot.startMinuteOfDay, 15)
            }
        )
    }

    private func date(for minute: Int) -> Date {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        let clampedMinute = minute.clamped(to: 0...1439)
        components.hour = clampedMinute / 60
        components.minute = clampedMinute % 60
        return Calendar.current.date(from: components) ?? Date()
    }

    private func minuteOfDay(for date: Date) -> Int {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (components.hour ?? 0) * 60 + (components.minute ?? 0)
    }
}

private struct AdvancedTargetsStep: View {
    let dhikr: Dhikr
    @Binding var draft: GoalDraft
    let language: AppLanguage

    var body: some View {
        AdvancedStepShell(
            stepIndex: 2,
            title: "Set targets",
            subtitle: "Use one target everywhere, or tune each slot."
        ) {
            GoalSelectedDhikrCard(dhikr: dhikr, language: language, preset: .custom)

            AdvancedEditorSection(title: "Targets", symbol: "target") {
                AdvancedPickerRow(
                    title: "Policy",
                    value: draft.selectedTargetPolicy.title,
                    selection: $draft.selectedTargetPolicy
                ) {
                    ForEach(TargetPolicy.allCases) { policy in
                        Text(LocalizedStringKey(policy.title)).tag(policy)
                    }
                }

                if draft.resolvedTargetPolicy == .none {
                    AdvancedNoTargetRow(title: "Tracker")
                } else {
                    if showsSlotTargetMode {
                        Toggle("Same target for all slots", isOn: sameTargetBinding)
                            .tint(AwradTheme.sage)
                            .padding(.horizontal, 14)
                            .frame(minHeight: 50)
                            .awradGlassSurface(cornerRadius: 18, tint: AwradTheme.surface.opacity(0.62), interactive: true)
                    }

                    if draft.slotTargetMode == .same || !showsSlotTargetMode {
                        CompactTargetInputRow(
                            title: sameTargetTitle,
                            subtitle: sameTargetSubtitle,
                            text: $draft.targetText
                        )
                    } else {
                        perSlotTargets
                    }
                }
            }

            if draft.showsCountRuleControls {
                countRuleSection
            }
        }
    }

    @ViewBuilder
    private var countRuleSection: some View {
        AdvancedEditorSection(title: "Count rule", symbol: "slider.horizontal.3") {
            AdvancedPickerRow(
                title: "Rule",
                value: draft.resolvedCountRuleMode.title,
                selection: $draft.countRuleMode
            ) {
                ForEach(CountRuleMode.allCases) { mode in
                    Text(LocalizedStringKey(mode.title)).tag(mode)
                }
            }

            Text(LocalizedStringKey(draft.countRuleMode.detail))
                .font(AwradTheme.bodyFont(.caption))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 4)

            if countRuleUsesMinimum {
                CompactTargetInputRow(
                    title: "Minimum count",
                    subtitle: "Counts toward your streak",
                    text: $draft.minimumText
                )
            }

            if draft.countRuleMode == .bounded {
                CompactTargetInputRow(
                    title: "Maximum count",
                    subtitle: "Hard ceiling",
                    text: $draft.maximumText
                )
            }

            if countRuleUsesCapBehavior {
                AdvancedPickerRow(
                    title: "When target reached",
                    value: draft.capBehavior.title,
                    selection: $draft.capBehavior
                ) {
                    ForEach(CapBehavior.allCases) { behavior in
                        Text(LocalizedStringKey(behavior.title)).tag(behavior)
                    }
                }
            }

        }
    }

    private var countRuleUsesMinimum: Bool {
        switch draft.countRuleMode {
        case .minimum, .stretch, .bounded: return true
        default: return false
        }
    }

    private var countRuleUsesCapBehavior: Bool {
        switch draft.countRuleMode {
        case .target, .stretch, .bounded: return true
        case .tracker, .minimum, .exact: return false
        }
    }

    private var sameTargetBinding: Binding<Bool> {
        Binding(
            get: { draft.slotTargetMode == .same },
            set: { draft.slotTargetMode = $0 ? .same : .perSlot }
        )
    }

    private var showsSlotTargetMode: Bool {
        advancedSlotCount > 1
    }

    private var advancedSlotCount: Int {
        switch draft.resolvedTimingMode {
        case .anytime:
            return 1
        case .prayerBased:
            return draft.selectedPrayerSlotTargets.count
        case .morningEvening:
            return 2
        case .timeWindow:
            return draft.timeSlots.count
        }
    }

    private var sameTargetTitle: String {
        switch draft.resolvedTargetPolicy {
        case .cumulativeTotal: "Total target"
        case .periodTotal: "Period target"
        case .perDueDate: advancedSlotCount > 1 ? "Each slot target" : "Target"
        case .none: "No target"
        }
    }

    private var sameTargetSubtitle: String {
        advancedSlotCount > 1 ? "\(advancedSlotCount) slots" : draft.resolvedTimingMode.title
    }

    @ViewBuilder
    private var perSlotTargets: some View {
        switch draft.resolvedTimingMode {
        case .anytime:
            CompactTargetInputRow(title: "Anytime", subtitle: "Open all day", text: $draft.targetText)
        case .prayerBased:
            if draft.selectedPrayerSlotTargets.isEmpty {
                Text("Select at least one prayer.")
                    .font(AwradTheme.bodyFont(.footnote, weight: .semibold))
                    .foregroundStyle(.red)
            } else {
                ForEach(draft.selectedPrayerSlotTargets) { slotTarget in
                    CompactTargetInputRow(
                        title: prayerSlotTitle(prayer: slotTarget.prayer, relation: slotTarget.relation),
                        subtitle: "Prayer slot",
                        text: prayerSlotBinding(prayer: slotTarget.prayer, relation: slotTarget.relation)
                    )
                }
            }
        case .morningEvening:
            CompactTargetInputRow(title: "Morning", subtitle: "05:00-11:00", text: $draft.morningTargetText)
            CompactTargetInputRow(title: "Evening", subtitle: "17:00-22:00", text: $draft.eveningTargetText)
        case .timeWindow:
            ForEach(draft.timeSlots) { timeSlot in
                if let index = draft.timeSlots.firstIndex(where: { $0.id == timeSlot.id }) {
                    CompactTargetInputRow(
                        title: draft.timeSlots[index].displayLabel(fallbackIndex: index + 1),
                        subtitle: draft.timeSlots[index].timeRangeText,
                        text: $draft.timeSlots[index].targetText
                    )
                }
            }
        }
    }

    private func prayerSlotTitle(prayer: Prayer, relation: PrayerRelation) -> String {
        switch relation {
        case .before:
            return "Before \(prayer.title)"
        case .after:
            return "After \(prayer.title)"
        }
    }

    private func prayerSlotBinding(prayer: Prayer, relation: PrayerRelation) -> Binding<String> {
        Binding(
            get: { draft.prayerTargetText(for: prayer, relation: relation) },
            set: { draft.setPrayerTargetText($0, for: prayer, relation: relation) }
        )
    }
}

private struct CompactTargetInputRow: View {
    let title: String
    let subtitle: String
    @Binding var text: String

    private var count: Int {
        Int(text.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(LocalizedStringKey(title))
                    .font(AwradTheme.bodyFont(.subheadline, weight: .semibold))
                    .foregroundStyle(AwradTheme.ink)
                Text(LocalizedStringKey(subtitle))
                    .font(AwradTheme.bodyFont(.caption))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Button {
                setCount(max(count - 1, 1))
            } label: {
                Image(systemName: "minus")
                    .font(AwradTheme.bodyFont(14, weight: .bold))
                    .frame(width: 34, height: 34)
                    .foregroundStyle(AwradTheme.sageDark)
                    .background(AwradTheme.mint.opacity(0.38), in: Circle())
            }
            .buttonStyle(.plain)
            .disabled(count <= 1)

            TextField("0", text: $text)
                .keyboardType(.numberPad)
                .font(AwradTheme.bodyFont(.title3).monospacedDigit().weight(.bold))
                .multilineTextAlignment(.center)
                .frame(width: 78, height: 42)
                .awradGlassSurface(cornerRadius: 16, tint: AwradTheme.surface.opacity(0.58), interactive: true)
                .onChange(of: text) { _, newValue in
                    text = newValue.filter(\.isNumber)
                }

            Button {
                setCount(count + 1)
            } label: {
                Image(systemName: "plus")
                    .font(AwradTheme.bodyFont(14, weight: .bold))
                    .frame(width: 34, height: 34)
                    .foregroundStyle(AwradTheme.sageDark)
                    .background(AwradTheme.mint.opacity(0.38), in: Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, minHeight: 62)
        .awradGlassSurface(cornerRadius: 18, tint: AwradTheme.surface.opacity(0.62), interactive: true)
    }

    private func setCount(_ value: Int) {
        text = "\(max(value, 1))"
    }
}

private struct AdvancedGoalPreviewStep: View {
    let dhikr: Dhikr
    @Binding var draft: GoalDraft
    let language: AppLanguage
    let hasPrayerLocation: Bool

    var body: some View {
        AdvancedStepShell(
            stepIndex: 3,
            title: "Preview goal",
            subtitle: "Review the full setup before creating it."
        ) {
            GoalSelectedDhikrCard(dhikr: dhikr, language: language, preset: .custom)

            if let configuration = draft.configuration {
                AdvancedEditorSection(title: "Slots", symbol: "rectangle.stack") {
                    ForEach(configuration.slots.sorted { $0.sortOrder < $1.sortOrder }) { slot in
                        AdvancedInfoRow(
                            title: slot.displayLabel(language: language),
                            value: slotPreviewDetail(for: slot)
                        )
                    }
                }
            }

            AdvancedEditorSection(title: "Summary", symbol: "checkmark.seal") {
                AdvancedInfoRow(title: "Schedule", value: draft.scheduleSummary)
                AdvancedInfoRow(title: "Timing", value: draft.timingSummary)
                AdvancedInfoRow(title: "Targets", value: draft.targetSummary)
                AdvancedInfoRow(title: "Reminders", value: draft.reminderSummary)
                AdvancedInfoRow(title: "Duration", value: draft.durationSummary)
            }

            if let validationMessage = draft.validationMessage {
                Text(LocalizedStringKey(validationMessage))
                    .font(AwradTheme.bodyFont(.footnote, weight: .semibold))
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            ReminderCard(
                draft: $draft,
                language: language,
                hasPrayerLocation: hasPrayerLocation
            )
            DurationCard(draft: $draft)
        }
    }

    private func slotPreviewDetail(for slot: GoalSlot) -> String {
        var parts: [String] = []
        if let start = slot.startMinute, let end = slot.endMinute {
            parts.append("\(formattedMinute(start))-\(formattedMinute(end))")
        }
        if let target = slot.targetCount {
            parts.append("\(target.formatted()) target")
        } else {
            parts.append("No target")
        }
        return parts.joined(separator: " · ")
    }

    private func formattedMinute(_ minute: Int) -> String {
        let clampedMinute = minute.clamped(to: 0...(24 * 60))
        return String(format: "%02d:%02d", clampedMinute / 60, clampedMinute % 60)
    }
}

private struct AdvancedEditorSection<Content: View>: View {
    let title: String
    let symbol: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(LocalizedStringKey(title), systemImage: symbol)
                .font(AwradTheme.bodyFont(.headline, weight: .semibold))
                .foregroundStyle(AwradTheme.ink)

            VStack(alignment: .leading, spacing: 10) {
                content
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .awradGlassSurface(cornerRadius: 24, tint: AwradTheme.surface.opacity(0.7))
    }
}

/// A select row that opens its options in a bottom sheet (instead of a system
/// menu). Keeps the existing `content`-based call sites unchanged — the same
/// `Picker` option tags are rendered inline inside the sheet.
private struct AdvancedPickerRow<Selection: Hashable, Content: View>: View {
    let title: String
    let value: String
    @Binding var selection: Selection
    @ViewBuilder var content: Content

    @State private var isPresented = false

    var body: some View {
        Button {
            isPresented = true
        } label: {
            HStack(spacing: 12) {
                Text(LocalizedStringKey(title))
                    .font(AwradTheme.bodyFont(.subheadline, weight: .semibold))
                    .foregroundStyle(AwradTheme.ink)
                Spacer(minLength: 0)
                Text(LocalizedStringKey(value))
                    .font(AwradTheme.bodyFont(.subheadline, weight: .semibold))
                    .foregroundStyle(AwradTheme.sage)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                Image(systemName: "chevron.up.chevron.down")
                    .font(AwradTheme.bodyFont(.caption, weight: .bold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, minHeight: 50)
            .contentShape(Rectangle())
            .awradGlassSurface(cornerRadius: 18, tint: AwradTheme.surface.opacity(0.62), interactive: true)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $isPresented) {
            NavigationStack {
                List {
                    Picker(selection: $selection) {
                        content
                    } label: {
                        EmptyView()
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }
                .navigationTitle(LocalizedStringKey(title))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { isPresented = false }
                    }
                }
            }
            .presentationDetents([.fraction(0.7), .large])
            .presentationDragIndicator(.visible)
            .awradSheetStyle()
            .onChange(of: selection) { _, _ in isPresented = false }
        }
    }
}

private struct AdvancedInfoRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 12) {
            Text(LocalizedStringKey(title))
                .font(AwradTheme.bodyFont(.subheadline, weight: .semibold))
                .foregroundStyle(AwradTheme.ink)
            Spacer(minLength: 0)
            Text(LocalizedStringKey(value))
                .font(AwradTheme.bodyFont(.subheadline, weight: .semibold))
                .foregroundStyle(AwradTheme.sage)
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
                .minimumScaleFactor(0.76)
        }
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, minHeight: 50)
        .awradGlassSurface(cornerRadius: 18, tint: AwradTheme.surface.opacity(0.58))
    }
}

private struct GoalReviewStep: View {
    let dhikr: Dhikr
    @Binding var draft: GoalDraft
    let language: AppLanguage
    let hasPrayerLocation: Bool
    let onCreate: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            GoalSelectedDhikrCard(dhikr: dhikr, language: language, preset: draft.preset)
            ScheduleCard(draft: $draft, language: language)
            TimingCard(draft: $draft, language: language)
            TargetCard(draft: $draft)
            ReminderCard(
                draft: $draft,
                language: language,
                hasPrayerLocation: hasPrayerLocation
            )
            DurationCard(draft: $draft)

            if let validationMessage = draft.validationMessage {
                Text(LocalizedStringKey(validationMessage))
                    .font(AwradTheme.bodyFont(.footnote, weight: .semibold))
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button(action: onCreate) {
                Label("Create Goal", systemImage: "checkmark.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .awradPrimaryButton()
            .disabled(draft.configuration == nil)
        }
    }
}

private struct GoalSelectedDhikrCard: View {
    let dhikr: Dhikr
    var language: AppLanguage = .english
    var preset: GoalPreset?
    var showsChange: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: dhikr.category.symbol)
                    .foregroundStyle(AwradTheme.gold)
                    .frame(width: 36, height: 36)
                    .background(AwradTheme.gold.opacity(0.14), in: Circle())
                VStack(alignment: .leading, spacing: 5) {
                    Text(dhikr.displayTitle(language: language))
                        .font(AwradTheme.bodyFont(.headline, weight: .semibold))
                    Text(dhikr.arabic)
                        .font(AwradTheme.arabicFont(25))
                        .lineLimit(2)
                        .environment(\.layoutDirection, .rightToLeft)
                }
                Spacer(minLength: 0)
                if showsChange {
                    HStack(spacing: 3) {
                        Text("Change")
                            .font(AwradTheme.bodyFont(.subheadline, weight: .semibold))
                        Image(systemName: "chevron.right")
                            .font(AwradTheme.bodyFont(.caption, weight: .bold))
                    }
                    .foregroundStyle(AwradTheme.sage)
                }
            }
            if let preset {
                Label(LocalizedStringKey(preset.title), systemImage: preset.symbol)
                    .font(AwradTheme.bodyFont(.caption, weight: .semibold))
                    .foregroundStyle(AwradTheme.sage)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .awradGlassSurface(cornerRadius: 24, tint: AwradTheme.surface.opacity(0.72))
    }
}

private struct TargetCard: View {
    @Binding var draft: GoalDraft

    var body: some View {
        GoalEditorCard(title: "Targets", symbol: "target") {
            if draft.preset == .custom {
                Picker("Policy", selection: $draft.selectedTargetPolicy) {
                    ForEach(TargetPolicy.allCases) { policy in
                        Text(LocalizedStringKey(policy.title)).tag(policy)
                    }
                }
            }

            if draft.resolvedTargetPolicy == .none {
                noTargetSlots
            } else {
                targetSlots
            }
        }
    }

    @ViewBuilder
    private var targetSlots: some View {
        switch draft.resolvedTimingMode {
        case .anytime:
            TargetCountControl(
                title: targetTitle,
                text: $draft.targetText,
                presets: targetPresets
            )
        case .prayerBased:
            if draft.selectedPrayers.isEmpty {
                Text("Select at least one prayer.")
                    .font(AwradTheme.bodyFont(.footnote, weight: .semibold))
                    .foregroundStyle(.red)
            } else {
                ForEach(draft.selectedPrayerSlotTargets) { slotTarget in
                    TargetCountControl(
                        title: "\(slotTitle(for: slotTarget.prayer, relation: slotTarget.relation)) target",
                        text: prayerTargetBinding(for: slotTarget.prayer, relation: slotTarget.relation),
                        presets: slotPresets
                    )
                }
            }
        case .morningEvening:
            TargetCountControl(
                title: "Morning target",
                text: $draft.morningTargetText,
                presets: slotPresets
            )
            TargetCountControl(
                title: "Evening target",
                text: $draft.eveningTargetText,
                presets: slotPresets
            )
        case .timeWindow:
            if draft.usesMorningEveningSlots {
                TargetCountControl(
                    title: "Morning target",
                    text: $draft.morningTargetText,
                    presets: slotPresets
                )
                TargetCountControl(
                    title: "Evening target",
                    text: $draft.eveningTargetText,
                    presets: slotPresets
                )
            } else {
                customTimeSlotTargets
            }
        }
    }

    @ViewBuilder
    private var noTargetSlots: some View {
        switch draft.resolvedTimingMode {
        case .anytime:
            AdvancedNoTargetRow(title: "Anytime")
        case .prayerBased:
            if draft.selectedPrayers.isEmpty {
                Text("Select at least one prayer.")
                    .font(AwradTheme.bodyFont(.footnote, weight: .semibold))
                    .foregroundStyle(.red)
            } else {
                ForEach(draft.selectedPrayerSlotTargets) { slotTarget in
                    AdvancedNoTargetRow(title: slotTitle(for: slotTarget.prayer, relation: slotTarget.relation))
                }
            }
        case .morningEvening:
            AdvancedNoTargetRow(title: "Morning")
            AdvancedNoTargetRow(title: "Evening")
        case .timeWindow:
            if draft.usesMorningEveningSlots {
                AdvancedNoTargetRow(title: "Morning")
                AdvancedNoTargetRow(title: "Evening")
            } else {
                customNoTargetTimeSlots
            }
        }
    }

    @ViewBuilder
    private var customTimeSlotTargets: some View {
        ForEach(draft.timeSlots) { timeSlot in
            if let index = draft.timeSlots.firstIndex(where: { $0.id == timeSlot.id }) {
                TargetCountControl(
                    title: "\(timeSlot.displayLabel(fallbackIndex: index + 1)) target",
                    text: $draft.timeSlots[index].targetText,
                    presets: slotPresets
                )
            }
        }
    }

    @ViewBuilder
    private var customNoTargetTimeSlots: some View {
        ForEach(draft.timeSlots) { timeSlot in
            if let index = draft.timeSlots.firstIndex(where: { $0.id == timeSlot.id }) {
                AdvancedNoTargetRow(title: timeSlot.displayLabel(fallbackIndex: index + 1))
            }
        }
    }

    private var targetTitle: String {
        switch draft.resolvedTargetPolicy {
        case .cumulativeTotal: "Total target count"
        case .periodTotal: "Period target"
        case .perDueDate: "Anytime target"
        case .none: "No target"
        }
    }

    private var targetPresets: [Int] {
        switch draft.resolvedTargetPolicy {
        case .cumulativeTotal:
            [100, 1_000, 10_000]
        case .periodTotal:
            [100, 1_000, 10_000]
        case .perDueDate:
            [33, 70, 100, 313]
        case .none:
            []
        }
    }

    private var slotPresets: [Int] {
        [33, 100, 300]
    }

    private func slotTitle(for prayer: Prayer, relation: PrayerRelation) -> String {
        switch relation {
        case .before:
            return "Before \(prayer.title)"
        case .after:
            return "After \(prayer.title)"
        }
    }

    private func prayerTargetBinding(for prayer: Prayer, relation: PrayerRelation) -> Binding<String> {
        Binding(
            get: {
                draft.prayerTargetText(for: prayer, relation: relation)
            },
            set: { newValue in
                draft.setPrayerTargetText(newValue, for: prayer, relation: relation)
            }
        )
    }
}

private struct AdvancedNoTargetRow: View {
    let title: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "infinity")
                .font(AwradTheme.bodyFont(17, weight: .semibold))
                .foregroundStyle(AwradTheme.sage)
                .frame(width: 34, height: 34)
                .background(AwradTheme.mint.opacity(0.22), in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(LocalizedStringKey(title))
                    .font(AwradTheme.bodyFont(.subheadline, weight: .semibold))
                    .foregroundStyle(AwradTheme.ink)
                Text("No target")
                    .font(AwradTheme.bodyFont(.caption))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
    }
}

private struct ScheduleCard: View {
    @Binding var draft: GoalDraft
    let language: AppLanguage

    var body: some View {
        GoalEditorCard(title: "Schedule", symbol: "calendar") {
            if draft.preset == .custom {
                Picker("Repeats", selection: $draft.customFrequency) {
                    ForEach(RecurrenceFrequency.allCases) { frequency in
                        Text(LocalizedStringKey(frequency.title)).tag(frequency)
                    }
                }
                Picker("Calendar", selection: $draft.customCalendar) {
                    ForEach(CalendarSystem.allCases) { calendar in
                        Text(LocalizedStringKey(calendar.title)).tag(calendar)
                    }
                }
            }

            switch draft.resolvedFrequency {
            case .daily:
                Text("Every day")
                    .font(AwradTheme.bodyFont(.subheadline))
                    .foregroundStyle(.secondary)
            case .weekly:
                WeekdayPicker(selectedWeekdays: $draft.selectedWeekdays)
            case .monthly:
                GoalTextField(title: "Days of month", text: $draft.monthDaysText, prompt: "1, 15, 29")
            case .interval:
                GoalNumberField(title: "Every N days", text: $draft.intervalDaysText)
            case .yearly:
                Stepper(value: $draft.yearlyMonth, in: 1...12) {
                    Text(AwradLocalizer.format("Month %d", language: language, draft.yearlyMonth))
                }
                GoalTextField(title: "Days", text: $draft.monthDaysText, prompt: "1, 10")
            case .season:
                Picker("Season", selection: $draft.seasonTemplate) {
                    ForEach(SeasonTemplateCode.allCases) { season in
                        Text(LocalizedStringKey(season.title)).tag(season)
                    }
                }
            case .specificDates:
                GoalTextField(title: "Specific dates", text: $draft.specificDatesText, prompt: "2026-06-01, 2026-06-15")
            }
        }
    }
}

private struct TimingCard: View {
    @Binding var draft: GoalDraft
    let language: AppLanguage

    var body: some View {
        GoalEditorCard(title: "Timing", symbol: "clock") {
            if draft.preset == .custom {
                Picker("Timing", selection: $draft.timingMode) {
                    ForEach(GoalTimingMode.allCases) { timing in
                        Text(LocalizedStringKey(timing.title)).tag(timing)
                    }
                }
            }

            switch draft.resolvedTimingMode {
            case .anytime:
                Text("Anytime")
                    .font(AwradTheme.bodyFont(.subheadline))
                    .foregroundStyle(.secondary)
            case .prayerBased:
                Picker("Prayer timing", selection: $draft.prayerTiming) {
                    ForEach(PrayerTiming.allCases) { timing in
                        Text(LocalizedStringKey(timing.title)).tag(timing)
                    }
                }
                PrayerPicker(selectedPrayers: $draft.selectedPrayers)
            case .morningEvening:
                TimeWindowSummary(label: "Morning", range: "05:00-11:00")
                TimeWindowSummary(label: "Evening", range: "17:00-22:00")
            case .timeWindow:
                if draft.preset == .morningEvening {
                    TimeWindowSummary(label: "Morning", range: "05:00-11:00")
                    TimeWindowSummary(label: "Evening", range: "17:00-22:00")
                } else {
                    TimeSlotsTimingList(draft: $draft, language: language)
                }
            }
        }
    }
}

private struct TimeSlotsTimingList: View {
    @Binding var draft: GoalDraft
    let language: AppLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(draft.timeSlots) { timeSlot in
                if let index = draft.timeSlots.firstIndex(where: { $0.id == timeSlot.id }) {
                    TimeSlotTimingCard(
                        title: timeSlot.displayLabel(fallbackIndex: index + 1),
                        slot: $draft.timeSlots[index],
                        language: language,
                        canRemove: draft.timeSlots.count > 1
                    ) {
                        draft.removeTimeSlot(id: timeSlot.id)
                    }
                }
            }

            Button {
                draft.addTimeSlot()
            } label: {
                Label("Add Time Slot", systemImage: "plus.circle.fill")
                    .font(AwradTheme.bodyFont(.subheadline, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .foregroundStyle(AwradTheme.sageDark)
                    .awradGlassSurface(cornerRadius: 16, tint: AwradTheme.mint.opacity(0.48), interactive: true)
            }
            .buttonStyle(.plain)
        }
    }
}

private struct ReminderCard: View {
    @Binding var draft: GoalDraft
    let language: AppLanguage
    let hasPrayerLocation: Bool

    var body: some View {
        GoalEditorCard(title: "Reminder", symbol: "bell") {
            Toggle("Goal reminder", isOn: $draft.remindersEnabled)
                .tint(AwradTheme.sage)

            if draft.remindersEnabled {
                switch draft.resolvedTimingMode {
                case .prayerBased:
                    Stepper(value: $draft.prayerReminderOffset, in: -30...90, step: 5) {
                        Text(prayerReminderLabel)
                    }
                    if !hasPrayerLocation {
                        Text("Set a prayer location to schedule prayer-based reminders.")
                            .font(AwradTheme.bodyFont(.footnote))
                            .foregroundStyle(.secondary)
                    }
                case .morningEvening, .timeWindow:
                    Text("At window start")
                        .font(AwradTheme.bodyFont(.subheadline))
                        .foregroundStyle(.secondary)
                case .anytime:
                    Stepper(value: $draft.fixedReminderHour, in: 0...23) {
                        Text(AwradLocalizer.format("Hour %d", language: language, draft.fixedReminderHour))
                    }
                    Stepper(value: $draft.fixedReminderMinute, in: 0...59, step: 5) {
                        Text(AwradLocalizer.format("Minute %d", language: language, draft.fixedReminderMinute))
                    }
                }
            }
        }
    }

    private var prayerReminderLabel: String {
        if draft.prayerReminderOffset == 0 {
            return AwradLocalizer.localized("At prayer time", language: language)
        }
        if draft.prayerReminderOffset > 0 {
            return AwradLocalizer.format("%d minutes after prayer", language: language, draft.prayerReminderOffset)
        }
        return AwradLocalizer.format("%d minutes before prayer", language: language, abs(draft.prayerReminderOffset))
    }
}

private struct DurationCard: View {
    @Binding var draft: GoalDraft

    var body: some View {
        GoalEditorCard(title: "Duration", symbol: "hourglass") {
            Toggle("End after a number of days", isOn: $draft.durationEnabled)
                .tint(AwradTheme.sage)
            if draft.durationEnabled {
                GoalNumberField(title: "Duration days", text: $draft.durationDaysText)
            }

            Toggle("Minimum streak count", isOn: $draft.minimumStreakEnabled)
                .tint(AwradTheme.sage)
            if draft.minimumStreakEnabled {
                GoalNumberField(title: "Streak count", text: $draft.minimumStreakText)
            }
        }
    }
}

private struct GoalEditorCard<Content: View>: View {
    let title: String
    let symbol: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(LocalizedStringKey(title), systemImage: symbol)
                .font(AwradTheme.bodyFont(.headline, weight: .semibold))
                .foregroundStyle(AwradTheme.ink)
            VStack(alignment: .leading, spacing: 12) {
                content
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .awradGlassSurface(cornerRadius: 24, tint: AwradTheme.surface.opacity(0.7))
    }
}

private struct GoalNumberField: View {
    let title: String
    @Binding var text: String

    var body: some View {
        GoalTextField(title: title, text: $text, prompt: "33")
            .keyboardType(.numberPad)
    }
}

private struct GoalTextField: View {
    let title: String
    @Binding var text: String
    var prompt: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(LocalizedStringKey(title))
                .font(AwradTheme.bodyFont(.caption, weight: .semibold))
                .foregroundStyle(.secondary)
            TextField(LocalizedStringKey(prompt), text: $text)
                .padding(.horizontal, 12)
                .frame(minHeight: 44)
                .awradGlassSurface(cornerRadius: 16, tint: AwradTheme.surface.opacity(0.58), interactive: true)
        }
    }
}

private struct WeekdayPicker: View {
    @Binding var selectedWeekdays: Set<Int>

    var body: some View {
        ChipGrid(options: weekdayOptions, selectedIDs: selectedWeekdays, toggle: toggle)
    }

    private func toggle(_ id: Int) {
        if selectedWeekdays.contains(id) {
            selectedWeekdays.remove(id)
        } else {
            selectedWeekdays.insert(id)
        }
    }

    private var weekdayOptions: [ChipOption<Int>] {
        [
            ChipOption(id: 1, title: "Mon"),
            ChipOption(id: 2, title: "Tue"),
            ChipOption(id: 3, title: "Wed"),
            ChipOption(id: 4, title: "Thu"),
            ChipOption(id: 5, title: "Fri"),
            ChipOption(id: 6, title: "Sat"),
            ChipOption(id: 7, title: "Sun")
        ]
    }
}

/// Weekday multi-select presented in a bottom sheet (with Select/Deselect all).
private struct WeekdaySelectRow: View {
    @Binding var selectedWeekdays: Set<Int>
    @State private var isPresented = false

    private let days: [(id: Int, name: String, short: String)] = [
        (1, "Monday", "Mon"), (2, "Tuesday", "Tue"), (3, "Wednesday", "Wed"),
        (4, "Thursday", "Thu"), (5, "Friday", "Fri"), (6, "Saturday", "Sat"),
        (7, "Sunday", "Sun")
    ]

    var body: some View {
        Button {
            isPresented = true
        } label: {
            HStack(spacing: 12) {
                Text("Days")
                    .font(AwradTheme.bodyFont(.subheadline, weight: .semibold))
                    .foregroundStyle(AwradTheme.ink)
                Spacer(minLength: 8)
                Text(summary)
                    .font(AwradTheme.bodyFont(.subheadline, weight: .semibold))
                    .foregroundStyle(AwradTheme.sage)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Image(systemName: "chevron.up.chevron.down")
                    .font(AwradTheme.bodyFont(.caption, weight: .bold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, minHeight: 50)
            .contentShape(Rectangle())
            .awradGlassSurface(cornerRadius: 18, tint: AwradTheme.surface.opacity(0.62), interactive: true)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $isPresented) {
            NavigationStack {
                List {
                    Section {
                        Button {
                            selectedWeekdays = allSelected ? [] : Set(1...7)
                        } label: {
                            Text(allSelected ? "Deselect all" : "Select all")
                                .foregroundStyle(AwradTheme.sage)
                        }
                    }
                    Section {
                        ForEach(days, id: \.id) { day in
                            Button {
                                toggle(day.id)
                            } label: {
                                HStack(spacing: 12) {
                                    Text(LocalizedStringKey(day.name))
                                        .foregroundStyle(AwradTheme.ink)
                                    Spacer(minLength: 8)
                                    if selectedWeekdays.contains(day.id) {
                                        Image(systemName: "checkmark")
                                            .font(AwradTheme.bodyFont(.body, weight: .semibold))
                                            .foregroundStyle(AwradTheme.sage)
                                    }
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .navigationTitle("Days")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { isPresented = false }
                    }
                }
            }
            .presentationDetents([.fraction(0.7), .large])
            .presentationDragIndicator(.visible)
            .awradSheetStyle()
        }
    }

    private var allSelected: Bool { selectedWeekdays.count == 7 }

    private func toggle(_ id: Int) {
        if selectedWeekdays.contains(id) {
            selectedWeekdays.remove(id)
        } else {
            selectedWeekdays.insert(id)
        }
    }

    private var summary: String {
        let selected = days.filter { selectedWeekdays.contains($0.id) }
        if selected.isEmpty { return "None" }
        if selected.count == 7 { return "Every day" }
        if selected.count == 1 { return selected[0].name }
        return selected.map(\.short).joined(separator: ", ")
    }
}

private struct PrayerPicker: View {
    @Binding var selectedPrayers: Set<Prayer>

    var body: some View {
        ChipGrid(
            options: Prayer.allCases.map { ChipOption(id: $0.rawValue, title: $0.title) },
            selectedIDs: Set(selectedPrayers.map(\.rawValue)),
            toggle: toggle
        )
    }

    private func toggle(_ rawValue: String) {
        guard let prayer = Prayer(rawValue: rawValue) else { return }
        if selectedPrayers.contains(prayer) {
            selectedPrayers.remove(prayer)
        } else {
            selectedPrayers.insert(prayer)
        }
    }
}

private struct ChipOption<ID: Hashable>: Identifiable {
    let id: ID
    let title: String
}

private struct ChipGrid<ID: Hashable>: View {
    let options: [ChipOption<ID>]
    let selectedIDs: Set<ID>
    let toggle: (ID) -> Void

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 76), spacing: 8)], spacing: 8) {
            ForEach(options) { option in
                Button {
                    toggle(option.id)
                } label: {
                    Text(LocalizedStringKey(option.title))
                        .font(AwradTheme.bodyFont(.caption, weight: .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .frame(maxWidth: .infinity, minHeight: 34)
                        .padding(.horizontal, 8)
                        .background(
                            selectedIDs.contains(option.id)
                                ? AwradTheme.sage.opacity(0.16)
                                : AwradTheme.mint.opacity(0.12),
                            in: Capsule()
                        )
                        .overlay(
                            Capsule()
                                .stroke(selectedIDs.contains(option.id) ? AwradTheme.sage.opacity(0.5) : .clear, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct TimeWindowSummary: View {
    let label: String
    let range: String

    var body: some View {
        HStack {
            Text(LocalizedStringKey(label))
                .font(AwradTheme.bodyFont(.subheadline, weight: .semibold))
            Spacer()
            Text(range)
                .font(AwradTheme.bodyFont(.subheadline).monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }
}

private extension GoalDraft {
    var scheduleSummary: String {
        switch resolvedFrequency {
        case .daily:
            return "Every day"
        case .weekly:
            let count = selectedWeekdays.count
            return count == 7 ? "Every day of week" : "\(count) weekdays"
        case .monthly:
            return "Monthly on \(monthDaysText)"
        case .interval:
            return "Every \(intervalDaysText) days"
        case .yearly:
            let monthName = Calendar.current.monthSymbols[(yearlyMonth - 1).clamped(to: 0...11)]
            return "\(monthName) \(monthDaysText)"
        case .season:
            return seasonTemplate.title
        case .specificDates:
            let count = specificDatesText.split { $0 == "," || $0 == "\n" || $0 == " " }.count
            return count == 1 ? "1 date" : "\(count) dates"
        }
    }

    var timingSummary: String {
        switch resolvedTimingMode {
        case .anytime:
            return "Anytime"
        case .prayerBased:
            return "\(selectedPrayerSlotTargets.count) prayer slots"
        case .morningEvening:
            return "Morning and evening"
        case .timeWindow:
            return timeSlots.count == 1 ? "1 custom slot" : "\(timeSlots.count) custom slots"
        }
    }

    var targetSummary: String {
        guard resolvedTargetPolicy != .none else { return "No target cap" }
        guard let configuration else { return "Needs target" }
        let slotCount = configuration.slots.count
        let total = configuration.slots.reduce(0) { $0 + ($1.targetCount ?? 0) }
        if slotCount <= 1 {
            return "\(total.formatted()) target"
        }
        if slotTargetMode == .same, let firstTarget = configuration.slots.first?.targetCount {
            return "\(firstTarget.formatted()) each · \(total.formatted()) total"
        }
        return "\(total.formatted()) total across \(slotCount) slots"
    }

    var reminderSummary: String {
        guard remindersEnabled else { return "Off" }
        switch resolvedTimingMode {
        case .anytime:
            return String(format: "%02d:%02d", fixedReminderHour, fixedReminderMinute)
        case .prayerBased:
            if prayerReminderOffset == 0 {
                return "At prayer time"
            }
            return prayerReminderOffset > 0
                ? "\(prayerReminderOffset) min after prayer"
                : "\(abs(prayerReminderOffset)) min before prayer"
        case .morningEvening, .timeWindow:
            return "At window start"
        }
    }

    var durationSummary: String {
        var parts: [String] = []
        if durationEnabled {
            parts.append("\(durationDaysText) days")
        }
        if minimumStreakEnabled {
            parts.append("\(minimumStreakText) streak")
        }
        return parts.isEmpty ? "No limit" : parts.joined(separator: " · ")
    }
}

private extension TargetPolicy {
    var title: String {
        switch self {
        case .perDueDate: "Daily target"
        case .cumulativeTotal: "Cumulative"
        case .periodTotal: "Period total"
        case .none: "Tracker"
        }
    }
}

private extension RecurrenceFrequency {
    var title: String {
        switch self {
        case .daily: "Daily"
        case .weekly: "Weekly"
        case .monthly: "Monthly"
        case .interval: "Interval"
        case .yearly: "Yearly"
        case .season: "Season"
        case .specificDates: "Specific dates"
        }
    }
}

private extension CalendarSystem {
    var title: String {
        switch self {
        case .gregorian: "Gregorian"
        case .hijri: "Hijri"
        }
    }
}

// MARK: - Single-page goal creation sections

private struct GoalTypeSection: View {
    @Binding var selection: GoalTypeChoice

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("What kind of goal?")
                .font(AwradTheme.displayFont(20, weight: .bold))
                .foregroundStyle(AwradTheme.ink)

            grid
        }
    }

    @ViewBuilder
    private var grid: some View {
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: 12) { gridContent }
        } else {
            gridContent
        }
    }

    private var gridContent: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(GoalTypeChoice.allCases) { choice in
                GoalTypeCard(choice: choice, isSelected: selection == choice) {
                    selection = choice
                }
            }
        }
    }
}

private struct GoalTypeCard: View {
    let choice: GoalTypeChoice
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    GlassOptionIcon(symbol: choice.symbol, isSelected: isSelected)
                    Spacer(minLength: 0)
                    GlassSelectionMark(isSelected: isSelected)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(LocalizedStringKey(choice.title))
                        .font(AwradTheme.bodyFont(.headline, weight: .semibold))
                        .lineLimit(2)
                        .minimumScaleFactor(0.82)

                    Text(LocalizedStringKey(choice.subtitle))
                        .font(AwradTheme.bodyFont(.caption, weight: .medium))
                        .foregroundStyle(isSelected ? .white.opacity(0.84) : .secondary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.82)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .foregroundStyle(isSelected ? .white : AwradTheme.ink)
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 118, alignment: .topLeading)
            .awradGlassSurface(
                cornerRadius: 26,
                tint: isSelected ? AwradTheme.sage.opacity(0.94) : AwradTheme.surface.opacity(0.58),
                interactive: true
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(choice.title)
        .accessibilityIdentifier("goal-type-\(choice.rawValue)")
    }
}

private struct GoalTimingEditor: View {
    @Binding var draft: GoalDraft

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("When will you count?")
                .font(AwradTheme.displayFont(20, weight: .bold))
                .foregroundStyle(AwradTheme.ink)
            AwradBottomSheetPicker(
                title: "Count timing",
                selection: $draft.timingMode,
                options: GoalTimingMode.allCases,
                description: { $0.detail }
            ) { $0.title }
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, minHeight: 54)
            .awradGlassSurface(cornerRadius: 18, tint: AwradTheme.surface.opacity(0.7), interactive: true)
        }
    }
}

private struct GoalScheduleEditor: View {
    @Binding var draft: GoalDraft

    var body: some View {
        AdvancedEditorSection(title: "Schedule", symbol: "calendar") {
            AdvancedPickerRow(
                title: "Repeat",
                value: draft.customFrequency.title,
                selection: $draft.customFrequency
            ) {
                ForEach(RecurrenceFrequency.allCases) { frequency in
                    Text(LocalizedStringKey(frequency.title)).tag(frequency)
                }
            }

            if showsCalendarRow {
                AdvancedPickerRow(
                    title: "Calendar",
                    value: draft.customCalendar.title,
                    selection: $draft.customCalendar
                ) {
                    ForEach(CalendarSystem.allCases) { calendar in
                        Text(LocalizedStringKey(calendar.title)).tag(calendar)
                    }
                }
            }

            scheduleDetails
        }
    }

    private var showsCalendarRow: Bool {
        switch draft.customFrequency {
        case .monthly, .yearly: true
        case .daily, .weekly, .interval, .season, .specificDates: false
        }
    }

    @ViewBuilder
    private var scheduleDetails: some View {
        switch draft.customFrequency {
        case .daily:
            AdvancedInfoRow(title: "Due", value: "Every day")
        case .weekly:
            WeekdaySelectRow(selectedWeekdays: $draft.selectedWeekdays)
        case .monthly:
            GoalTextField(title: "Days of month", text: $draft.monthDaysText, prompt: "1, 15, 29")
        case .interval:
            GoalNumberField(title: "Every N days", text: $draft.intervalDaysText)
        case .yearly:
            AdvancedPickerRow(
                title: "Month",
                value: Calendar.current.monthSymbols[(draft.yearlyMonth - 1).clamped(to: 0...11)],
                selection: $draft.yearlyMonth
            ) {
                ForEach(1...12, id: \.self) { month in
                    Text(Calendar.current.monthSymbols[month - 1]).tag(month)
                }
            }
            GoalTextField(title: "Days", text: $draft.monthDaysText, prompt: "1, 10")
        case .season:
            AdvancedPickerRow(
                title: "Season",
                value: draft.seasonTemplate.title,
                selection: $draft.seasonTemplate
            ) {
                ForEach(SeasonTemplateCode.allCases) { season in
                    Text(LocalizedStringKey(season.title)).tag(season)
                }
            }
        case .specificDates:
            GoalTextField(title: "Specific dates", text: $draft.specificDatesText, prompt: "2026-06-01, 2026-06-15")
        }
    }
}

private struct GoalCountRuleEditor: View {
    @Binding var draft: GoalDraft

    var body: some View {
        AdvancedEditorSection(title: "How counting works", symbol: "slider.horizontal.3") {
            AwradBottomSheetPicker(
                title: "Counting rule",
                selection: $draft.countRuleMode,
                options: CountRuleMode.allCases,
                description: { $0.detail }
            ) { $0.title }
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, minHeight: 50)
            .awradGlassSurface(cornerRadius: 18, tint: AwradTheme.surface.opacity(0.62), interactive: true)

            Text(LocalizedStringKey(draft.countRuleMode.detail))
                .font(AwradTheme.bodyFont(.caption))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 4)

            if usesMinimum {
                CompactTargetInputRow(
                    title: "Least count that keeps your streak",
                    subtitle: "A day counts once you reach this",
                    text: $draft.minimumText
                )
            }

            if draft.countRuleMode == .bounded {
                CompactTargetInputRow(
                    title: "Most you can count",
                    subtitle: "Counting won't go past this",
                    text: $draft.maximumText
                )
            }

            if usesCapBehavior {
                AwradBottomSheetPicker(
                    title: "When you reach the goal",
                    selection: $draft.capBehavior,
                    options: CapBehavior.allCases,
                    description: { $0.detail }
                ) { $0.title }
                .padding(.horizontal, 14)
                .frame(maxWidth: .infinity, minHeight: 50)
                .awradGlassSurface(cornerRadius: 18, tint: AwradTheme.surface.opacity(0.62), interactive: true)
            }
        }
    }

    private var usesMinimum: Bool {
        switch draft.countRuleMode {
        case .minimum, .stretch, .bounded: return true
        default: return false
        }
    }

    private var usesCapBehavior: Bool {
        switch draft.countRuleMode {
        case .target, .stretch, .bounded: return true
        case .tracker, .minimum, .exact: return false
        }
    }
}

private struct GoalFineTuneSection: View {
    @Binding var draft: GoalDraft
    let language: AppLanguage

    var body: some View {
        AdvancedEditorSection(title: "Extra options", symbol: "dial.min") {
            Toggle("Remind me to count", isOn: $draft.remindersEnabled)
                .tint(AwradTheme.sage)

            Toggle("End the goal after a set time", isOn: $draft.durationEnabled)
                .tint(AwradTheme.sage)
            if draft.durationEnabled {
                GoalNumberField(title: "Number of days", text: $draft.durationDaysText)
            }

            Toggle("Require a daily minimum to keep a streak", isOn: $draft.minimumStreakEnabled)
                .tint(AwradTheme.sage)
            if draft.minimumStreakEnabled {
                GoalNumberField(title: "Minimum daily count", text: $draft.minimumStreakText)
            }

        }
    }
}

private struct GoalCreateBar: View {
    let sentence: String
    let isEnabled: Bool
    let message: String?
    let onCreate: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                Text("YOUR GOAL")
                    .font(AwradTheme.bodyFont(.caption2, weight: .bold))
                    .tracking(1.2)
                    .foregroundStyle(AwradTheme.sage)
                Text(sentence)
                    .font(AwradTheme.bodyFont(.subheadline, weight: .semibold))
                    .foregroundStyle(AwradTheme.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)

            if let message, !isEnabled {
                Text(LocalizedStringKey(message))
                    .font(AwradTheme.bodyFont(.caption, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)
            }
            Button(action: onCreate) {
                Text("Create goal")
                    .font(AwradTheme.bodyFont(.headline, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .foregroundStyle(isEnabled ? .white : AwradTheme.subdued)
                    .awradGlassSurface(
                        cornerRadius: 22,
                        tint: isEnabled ? AwradTheme.sage : AwradTheme.surface.opacity(0.74),
                        interactive: isEnabled
                    )
            }
            .buttonStyle(.plain)
            .disabled(!isEnabled)
            .accessibilityIdentifier("quick-goal-create-button")
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 10)
        .background(.ultraThinMaterial)
    }
}

/// Builds the live goal sentence shown in the hero from the current draft.
enum GoalSentenceBuilder {
    static func sentence(draft: GoalDraft, dhikr: Dhikr?, language: AppLanguage) -> String {
        let title = dhikr.map { $0.transliteration.isEmpty ? $0.displayTitle(language: language) : $0.transliteration }
            ?? "this dhikr"

        switch GoalTypeChoice(preset: draft.preset) {
        case .tracker:
            return "Track every time you recite \(title)."
        case .oneTime:
            let total = draft.targetText.isEmpty ? "" : "\(draft.targetText) "
            return "Complete \(total)recitations of \(title)."
        case .daily, .advanced:
            let count = draft.targetText.isEmpty ? "" : "\(draft.targetText)× "
            return "Recite \(count)\(title) \(frequencyPhrase(draft)), \(timingPhrase(draft))."
        }
    }

    private static func frequencyPhrase(_ draft: GoalDraft) -> String {
        switch draft.resolvedFrequency {
        case .daily: "every day"
        case .weekly: "every week"
        case .monthly: "every month"
        case .interval: "on a custom interval"
        case .yearly: "every year"
        case .season: "during the season"
        case .specificDates: "on chosen dates"
        }
    }

    private static func timingPhrase(_ draft: GoalDraft) -> String {
        switch draft.resolvedTimingMode {
        case .anytime: "anytime"
        case .prayerBased: "around prayers"
        case .morningEvening: "morning and evening"
        case .timeWindow: "in custom slots"
        }
    }
}
