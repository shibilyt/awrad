import SwiftUI

struct GoalSlotRuleDraft: Identifiable, Hashable {
    let id: AwradID
    var title: String
    var minimumText: String
    var targetText: String
    var maximumText: String
    var capBehavior: CapBehavior

    init(slot: GoalSlot, language: AppLanguage) {
        id = slot.id
        title = slot.displayLabel(language: language)
        minimumText = slot.minimumCount.map(String.init) ?? ""
        targetText = slot.targetCount.map(String.init) ?? ""
        maximumText = slot.maximumCount.map(String.init) ?? ""
        capBehavior = slot.capBehavior
    }

    mutating func applyDefaults(for mode: CountRuleMode) {
        let fallback = targetText.nonEmpty ?? minimumText.nonEmpty ?? maximumText.nonEmpty ?? "100"
        switch mode {
        case .tracker:
            minimumText = ""
            targetText = ""
            maximumText = ""
            capBehavior = .allowOverTarget
        case .minimum:
            minimumText = minimumText.nonEmpty ?? fallback
            targetText = minimumText
            maximumText = ""
            capBehavior = .allowOverTarget
        case .target:
            minimumText = ""
            targetText = fallback
            maximumText = ""
            if capBehavior == .blockAtMaximum { capBehavior = .allowOverTarget }
        case .stretch:
            minimumText = minimumText.nonEmpty ?? "33"
            let currentTarget = Int(targetText) ?? 0
            targetText = currentTarget > (Int(minimumText) ?? 0) ? targetText : "100"
            maximumText = ""
            if capBehavior == .blockAtMaximum { capBehavior = .allowOverTarget }
        case .exact:
            let exact = maximumText.nonEmpty ?? targetText.nonEmpty ?? fallback
            minimumText = ""
            targetText = exact
            maximumText = exact
            capBehavior = .blockAtMaximum
        case .bounded:
            minimumText = minimumText.nonEmpty ?? "33"
            targetText = targetText.nonEmpty ?? "100"
            maximumText = maximumText.nonEmpty ?? "200"
            capBehavior = .blockAtMaximum
        }
    }

    func policy(for mode: CountRuleMode) -> CountPolicy? {
        let minimum = positive(minimumText)
        let target = positive(targetText)
        let maximum = positive(maximumText)
        switch mode {
        case .tracker:
            return CountPolicy(
                streakThreshold: .anyPositive,
                reminderThreshold: .anyPositive,
                completionThreshold: .anyPositive,
                capBehavior: .allowOverTarget
            )
        case .minimum:
            guard let minimum else { return nil }
            return CountPolicy(
                minimumCount: minimum,
                targetCount: minimum,
                streakThreshold: .minimum,
                reminderThreshold: .minimum,
                completionThreshold: .minimum,
                capBehavior: .allowOverTarget
            )
        case .target:
            guard let target else { return nil }
            return CountPolicy(targetCount: target, capBehavior: capBehavior)
        case .stretch:
            guard let minimum, let target, minimum < target else { return nil }
            return CountPolicy(
                minimumCount: minimum,
                targetCount: target,
                streakThreshold: .minimum,
                capBehavior: capBehavior
            )
        case .exact:
            guard let exact = maximum ?? target else { return nil }
            return CountPolicy(targetCount: exact, maximumCount: exact, capBehavior: .blockAtMaximum)
        case .bounded:
            guard let minimum, let target, let maximum,
                  minimum <= target, target <= maximum else { return nil }
            return CountPolicy(
                minimumCount: minimum,
                targetCount: target,
                maximumCount: maximum,
                streakThreshold: .minimum,
                capBehavior: capBehavior == .allowOverTarget ? .blockAtMaximum : capBehavior
            )
        }
    }

    private func positive(_ text: String) -> Int? {
        guard let value = Int(text), value > 0 else { return nil }
        return value
    }
}

struct EditGoalView: View {
    @Environment(AwradStore.self) private var store
    @Environment(AppServices.self) private var services
    @Environment(\.dismiss) private var dismiss

    let goalID: AwradID

    @State private var mode: CountRuleMode = .target
    @State private var slotDrafts: [GoalSlotRuleDraft] = []
    @State private var originalDrafts: [GoalSlotRuleDraft] = []
    @State private var autoCompleteOnTarget = false
    @State private var originalAutoComplete = false
    @State private var didLoad = false
    @State private var saveError: String?
    @State private var isSaving = false
    @State private var showLowerMaximumConfirmation = false

    private var goal: Goal? { store.goal(id: goalID) }
    private var language: AppLanguage { store.preferences.appLanguage }
    private var isDirty: Bool {
        slotDrafts != originalDrafts || autoCompleteOnTarget != originalAutoComplete ||
            mode != goal.map { Self.inferredMode($0) } ?? .target
    }
    private var policies: [AwradID: CountPolicy]? {
        var result: [AwradID: CountPolicy] = [:]
        for draft in slotDrafts {
            guard let policy = draft.policy(for: mode) else { return nil }
            result[draft.id] = policy
        }
        return result
    }

    var body: some View {
        Group {
            if let goal {
                editor(goal)
            } else {
                ContentUnavailableView(
                    "Goal not found",
                    systemImage: "target",
                    description: Text("This goal may have been removed.")
                )
            }
        }
        .background(AwradTheme.background)
        .navigationTitle("Edit count rules")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: attemptSave)
                    .fontWeight(.semibold)
                    .disabled(!isDirty || policies == nil || isSaving)
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
        .confirmationDialog(
            "Maximum is below existing progress",
            isPresented: $showLowerMaximumConfirmation,
            titleVisibility: .visible
        ) {
            Button("Save New Maximum", role: .destructive, action: save)
            Button("Review Changes", role: .cancel) {}
        } message: {
            Text("Existing history will be preserved. The goal may already be beyond the new maximum, so no further counts will be accepted for that session.")
        }
    }

    private func editor(_ goal: Goal) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(store.title(for: goal))
                        .font(AwradTheme.displayFont(26, weight: .bold))
                    Text("Set how progress, milestones, and count limits work.")
                        .font(AwradTheme.bodyFont(.subheadline))
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Count rule")
                        .font(AwradTheme.bodyFont(.headline, weight: .semibold))
                    Picker("Count rule", selection: $mode) {
                        ForEach(CountRuleMode.allCases) { value in
                            Text(value.title).tag(value)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
                    .frame(minHeight: 50)
                    .awradGlassSurface(cornerRadius: 18, tint: AwradTheme.surface.opacity(0.72), interactive: true)
                    Text(mode.detail)
                        .font(AwradTheme.bodyFont(.caption))
                        .foregroundStyle(.secondary)
                }

                if slotDrafts.count == 1, let index = slotDrafts.indices.first {
                    GoalRulePolicyEditor(title: "Progress target", draft: $slotDrafts[index], mode: mode)
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Session targets")
                            .font(AwradTheme.bodyFont(.headline, weight: .semibold))
                        Text("Each session keeps its own target and count history.")
                            .font(AwradTheme.bodyFont(.caption))
                            .foregroundStyle(.secondary)
                        ForEach($slotDrafts) { $draft in
                            GoalRulePolicyEditor(title: draft.title, draft: $draft, mode: mode)
                        }
                    }
                }

                if goal.targetPolicy == .cumulativeTotal && mode != .tracker {
                    Toggle("Complete goal when target is reached", isOn: $autoCompleteOnTarget)
                        .font(AwradTheme.bodyFont(.subheadline, weight: .semibold))
                        .padding(16)
                        .awradGlassSurface(cornerRadius: 20, tint: AwradTheme.surface.opacity(0.72), interactive: true)
                }

                if policies == nil {
                    Label("Enter positive counts in order: minimum ≤ target ≤ maximum.", systemImage: "exclamationmark.triangle.fill")
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
        .onChange(of: mode) { _, newMode in
            for index in slotDrafts.indices {
                slotDrafts[index].applyDefaults(for: newMode)
            }
        }
    }

    private func hydrateIfNeeded() {
        guard !didLoad, let goal else { return }
        mode = Self.inferredMode(goal)
        slotDrafts = goal.activeSlots
            .sorted { $0.sortOrder < $1.sortOrder }
            .map { GoalSlotRuleDraft(slot: $0, language: language) }
        originalDrafts = slotDrafts
        autoCompleteOnTarget = goal.autoCompleteOnTarget
        originalAutoComplete = goal.autoCompleteOnTarget
        didLoad = true
    }

    private func attemptSave() {
        guard let goal, let policies else { return }
        let lowersMaximumBelowProgress = policies.contains { slotID, policy in
            guard let maximum = policy.maximumCount else { return false }
            return store.count(for: goal, slotID: slotID) > Int64(maximum)
        }
        if lowersMaximumBelowProgress {
            showLowerMaximumConfirmation = true
        } else {
            save()
        }
    }

    private func save() {
        guard !isSaving else { return }
        guard let goal, let policies, let first = policies.values.first else { return }
        let previousGoal = goal
        guard let updated = store.updateGoalCountSetup(
            goalID: goal.id,
            ruleMode: mode,
            goalPolicy: first,
            slotPolicies: policies,
            autoCompleteOnTarget: autoCompleteOnTarget
        ) else {
            saveError = "Review the count rule and try again."
            return
        }
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
        await services.refreshNotificationsAfterGoalMutation(goalID: goal.id, store: store)
    }

    static func inferredMode(_ goal: Goal) -> CountRuleMode {
        if goal.targetPolicy == .none { return .tracker }
        let policies = goal.activeSlots.map(\.countPolicy)
        let representative = policies.first ?? goal.countPolicy
        if let target = representative.targetCount,
           representative.maximumCount == target,
           representative.capBehavior == .blockAtMaximum {
            return .exact
        }
        if representative.minimumCount != nil,
           representative.targetCount != nil,
           representative.maximumCount != nil {
            return .bounded
        }
        if let minimum = representative.minimumCount,
           let target = representative.targetCount {
            return minimum == target ? .minimum : .stretch
        }
        if representative.minimumCount != nil { return .minimum }
        return .target
    }
}

private struct GoalRulePolicyEditor: View {
    let title: String
    @Binding var draft: GoalSlotRuleDraft
    let mode: CountRuleMode

    var body: some View {
        AwradCard(padding: 16) {
            VStack(alignment: .leading, spacing: 13) {
                Text(LocalizedStringKey(title))
                    .font(AwradTheme.bodyFont(.headline, weight: .semibold))
                if mode == .minimum || mode == .stretch || mode == .bounded {
                    numberField("Minimum", text: $draft.minimumText)
                }
                if mode == .target || mode == .stretch || mode == .exact || mode == .bounded {
                    numberField(mode == .exact ? "Exact count" : "Target", text: $draft.targetText)
                }
                if mode == .bounded {
                    numberField("Maximum", text: $draft.maximumText)
                }
                if mode == .target || mode == .stretch || mode == .bounded {
                    Picker("At the limit", selection: $draft.capBehavior) {
                        if mode != .bounded {
                            Text("Keep counting").tag(CapBehavior.allowOverTarget)
                            Text("Warn, then continue").tag(CapBehavior.warnOverTarget)
                            Text("Stop at target").tag(CapBehavior.blockAtTarget)
                        }
                        if mode == .bounded {
                            Text("Stop at maximum").tag(CapBehavior.blockAtMaximum)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
        }
    }

    private func numberField(_ title: LocalizedStringKey, text: Binding<String>) -> some View {
        HStack {
            Text(title)
                .font(AwradTheme.bodyFont(.subheadline))
            Spacer()
            TextField("0", text: text)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 100)
                .textFieldStyle(.roundedBorder)
        }
    }
}

private extension String {
    var nonEmpty: String? { isEmpty ? nil : self }
}
