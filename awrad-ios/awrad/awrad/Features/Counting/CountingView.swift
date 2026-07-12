import SwiftUI
import Combine

#if os(iOS)
import AudioToolbox
import UIKit
#endif

private enum CounterSheet: String, Identifiable {
    case sessionTarget
    case adjustCount
    case history
    case fullDhikr

    var id: String { rawValue }
}

private enum CountAdjustmentMode: String, CaseIterable, Identifiable {
    case add
    case subtract

    var id: String { rawValue }

    var titleKey: LocalizedStringKey {
        switch self {
        case .add:
            return "Add"
        case .subtract:
            return "Subtract"
        }
    }
}

struct CountingView: View {
    @Environment(AwradStore.self) private var store
    @Environment(AppServices.self) private var services
    @Environment(\.dismiss) private var dismiss
    let goalID: AwradID
    @State private var selectedSlotID: AwradID?
    @State private var showAudioError = false
    @State private var showAudioExitConfirmation = false
    @State private var activeSheet: CounterSheet?
    @State private var sessionTarget: Int?
    @State private var sessionStartCount = 0
    @State private var sessionDraftTarget = 33
    @State private var sessionType: SessionTargetType = .count
    @State private var sessionDraftType: SessionTargetType = .count
    @State private var sessionTimerEnd: Date?
    @State private var adjustmentAmount = 1
    @State private var adjustmentMode = CountAdjustmentMode.add
    // Phase 3: cap warnings, slot timing guard, completion, ticker
    @State private var capMessage: LocalizedStringKey?
    @State private var showCapMessage = false
    @State private var didShowCompletion = false
    @State private var showCompletionDialog = false
    @State private var pendingOutOfWindowCount = false
    @State private var confirmedOutOfWindowSlots: Set<AwradID> = []
    @State private var nowMinuteOfDay = SlotStatusCalculator.minuteOfDay(from: Date())
    // Phase 4: first-run coach marks
    @State private var showCoachMarks = false
    @State private var coachTapProgress = 0
    @State private var coachAudioProgress = 0
    @State private var liveActivity = CountingLiveActivityController()

    private let minuteTicker = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    private var goal: Goal? { store.goal(id: goalID) }
    private var language: AppLanguage { store.preferences.appLanguage }

    var body: some View {
        ZStack {
            AwradTheme.background
                .ignoresSafeArea()

            if let goal, let dhikr = store.dhikr(id: goal.dhikrID) {
                VStack(spacing: 0) {
                    CountingTopChrome(
                        title: counterTitle(for: dhikr),
                        onBack: handleBack,
                        onHistory: { activeSheet = .history },
                        onAdjust: openAdjustmentSheet
                    )

                    VStack(spacing: 10) {
                        CountingTargetReadout(
                            currentText: formattedNumber(heroCurrentCount(for: goal)),
                            denominatorText: heroDenominatorText(for: goal),
                            todayChipText: heroTodayChipText(for: goal),
                            progress: heroProgress(for: goal)
                        )
                        .coachAnchor("progress")

                        if sessionTarget == nil, let minimum = goal.minimumForStreak {
                            MinimumStreakChip(
                                text: AwradLocalizer.format("counting_min_for_streak", language: language, minimum)
                            )
                        }

                        if let endDate = sessionTimerEnd, sessionTarget != nil, sessionType == .timer {
                            SessionTimerChip(endDate: endDate)
                        }

                        DhikrPreviewCard(arabic: dhikr.arabic) {
                            activeSheet = .fullDhikr
                        }

                        if goal.slots.count > 1 {
                            slotCards(for: goal)
                        }

                        if showsSlotCompleteBanner(for: goal) {
                            SlotCompleteBanner(language: language) {
                                selectNextIncompleteSlot(for: goal)
                            }
                        }

                        countingActionRow(goal: goal, dhikr: dhikr)

                        if services.audio.isCounting(goalID: goal.id) {
                            CompactAudioStatus(
                                progress: services.audio.progress,
                                elapsedText: services.audio.elapsedText,
                                durationText: services.audio.durationText,
                                playbackRate: services.audio.playbackRate,
                                onStop: { services.audio.stop() }
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                    if !services.audio.isCounting(goalID: goal.id) {
                        CountCircleButton(
                            isEnabled: countButtonEnabled(for: goal),
                            onCount: { add(1) }
                        )
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                    } else {
                        Spacer(minLength: 24)
                    }
                }
            } else {
                EmptyStateView(symbol: "target", title: "Goal Missing", message: "This goal is no longer available.")
                    .padding(20)
            }

        }
        .overlayPreferenceValue(CoachAnchorKey.self) { anchors in
            if showCoachMarks, goal != nil {
                GeometryReader { proxy in
                    CountingCoachOverlay(
                        steps: coachSteps,
                        language: language,
                        tapProgress: coachTapProgress,
                        audioProgress: coachAudioProgress,
                        targets: anchors.mapValues { proxy[$0] },
                        onFinish: finishCoachMarks
                    )
                }
                .ignoresSafeArea()
            }
        }
        .background(AwradTheme.background)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            selectedSlotID = selectedSlotID ?? goal?.slots.first?.id
            updateIdleTimer(enabled: store.preferences.keepScreenOn)
            if !store.preferences.hasSeenCountingGuide {
                showCoachMarks = true
            }
            startLiveActivity()
        }
        .onChange(of: selectedSlotID) { oldValue, _ in
            if oldValue != nil, services.audio.isCounting(goalID: goalID) {
                services.audio.stop()
            }
            guard let goal, sessionTarget != nil else { return }
            sessionStartCount = displayedCount(for: goal)
        }
        .onChange(of: services.audio.errorMessage) { _, newValue in
            showAudioError = newValue != nil
        }
        .onChange(of: services.audio.countingPlayTick) { _, _ in
            if showCoachMarks { coachAudioProgress += 1 }
        }
        .sheet(item: $activeSheet) { sheet in
            if let goal {
                switch sheet {
                case .sessionTarget:
                    SessionTargetSheet(
                        target: $sessionDraftTarget,
                        type: $sessionDraftType,
                        canClear: sessionTarget != nil,
                        language: language,
                        onSave: {
                            applySessionTarget(for: goal)
                        },
                        onClear: {
                            clearSessionTarget(for: goal)
                        }
                    )
                case .adjustCount:
                    CountAdjustmentSheet(
                        amount: $adjustmentAmount,
                        mode: $adjustmentMode,
                        currentCount: displayedCount(for: goal),
                        targetCount: adjustmentTarget(for: goal),
                        language: language,
                        onApply: {
                            applyAdjustment(for: goal)
                        }
                    )
                case .history:
                    CountHistorySheet(
                        goal: goal,
                        entries: store.countHistory(for: goal),
                        language: language
                    )
                case .fullDhikr:
                    if let dhikr = store.dhikr(id: goal.dhikrID) {
                        FullDhikrSheet(arabic: dhikr.arabic) {
                            add(1)
                        }
                        .presentationDetents([.large])
                        .presentationDragIndicator(.visible)
                    } else {
                        EmptyStateView(symbol: "text.book.closed", title: "Dhikr Missing", message: "This dhikr is no longer available.")
                    }
                }
            } else {
                EmptyStateView(symbol: "target", title: "Goal Missing", message: "This goal is no longer available.")
            }
        }
        .alert("Audio Error", isPresented: $showAudioError) {
            Button("OK") {
                services.audio.stop()
            }
        } message: {
            Text(services.audio.errorMessage ?? "Audio playback failed.")
        }
        .confirmationDialog("Audio is playing", isPresented: $showAudioExitConfirmation, titleVisibility: .visible) {
            Button("Stop and Exit", role: .destructive) {
                services.audio.stop()
                dismiss()
            }
            Button("Continue Counting", role: .cancel) {}
        } message: {
            Text("Stop audio counting before leaving this counter?")
        }
        .alert(Text("Counting"), isPresented: $showCapMessage) {
            Button("OK", role: .cancel) {}
        } message: {
            if let capMessage {
                Text(capMessage)
            }
        }
        .confirmationDialog(
            Text(AwradLocalizer.localized("slot_ended_title", language: language)),
            isPresented: $pendingOutOfWindowCount,
            titleVisibility: .visible
        ) {
            Button(AwradLocalizer.localized("Count anyway", language: language)) {
                if let goal, let slotID = activeCountSlotID(for: goal) {
                    confirmedOutOfWindowSlots.insert(slotID)
                }
                performCount(1)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(AwradLocalizer.localized("slot_ended_body", language: language))
        }
        .alert(
            Text(AwradLocalizer.localized("goal_reached_title", language: language)),
            isPresented: $showCompletionDialog
        ) {
            Button("Done") { dismiss() }
        } message: {
            if let goal {
                Text(AwradLocalizer.format("goal_reached_body", language: language, goal.totalTarget))
            }
        }
        .onReceive(minuteTicker) { _ in
            nowMinuteOfDay = SlotStatusCalculator.minuteOfDay(from: Date())
            evaluateTimerSession()
        }
        .onDisappear {
            updateIdleTimer(enabled: false)
            liveActivity.end()
        }
    }

    private func startLiveActivity() {
        guard let goal, let dhikr = store.dhikr(id: goal.dhikrID) else { return }
        liveActivity.start(
            dhikrTitle: counterTitle(for: dhikr),
            goalID: goal.id.uuidString,
            currentCount: displayedCount(for: goal),
            targetCount: goal.targetPolicy == .none ? 0 : selectedSlotTarget(for: goal),
            isPlaying: services.audio.isCounting(goalID: goal.id)
        )
    }

    private func refreshLiveActivity() {
        guard let goal else { return }
        liveActivity.update(
            currentCount: displayedCount(for: goal),
            targetCount: goal.targetPolicy == .none ? 0 : selectedSlotTarget(for: goal),
            isPlaying: services.audio.isCounting(goalID: goal.id),
            audioPositionText: services.audio.isCounting(goalID: goal.id) ? services.audio.elapsedText : ""
        )
    }

    /// Fires the session-complete dialog when a TIMER session elapses.
    private func evaluateTimerSession() {
        guard sessionType == .timer, let end = sessionTimerEnd, sessionTarget != nil,
              Date() >= end, let goal else { return }
        sessionTimerEnd = nil
        clearSessionTarget(for: goal)
        capMessage = "counting_session_complete_body_timer"
        showCapMessage = true
    }

    private var shouldConfirmAudioExit: Bool {
        services.audio.isCounting(goalID: goalID)
    }

    private func handleBack() {
        if shouldConfirmAudioExit {
            showAudioExitConfirmation = true
        } else {
            dismiss()
        }
    }

    private func counterTitle(for dhikr: Dhikr) -> String {
        let transliteration = dhikr.transliteration.trimmingCharacters(in: .whitespacesAndNewlines)
        return transliteration.isEmpty ? dhikr.title : transliteration
    }

    private func formattedNumber(_ value: Int) -> String {
        value.formatted(.number)
    }

    private func heroCurrentCount(for goal: Goal) -> Int {
        if sessionTarget != nil {
            return sessionProgress(for: goal)
        }
        return displayedCount(for: goal)
    }

    private func heroTarget(for goal: Goal) -> Int? {
        if let sessionTarget {
            return sessionTarget
        }
        guard goal.targetPolicy != .none else { return nil }
        return goal.slots.count > 1 ? selectedSlotTarget(for: goal) : goal.totalTarget
    }

    private func heroProgress(for goal: Goal) -> Double {
        if sessionTarget != nil {
            return sessionProgressValue(for: goal)
        }
        return displayedProgress(for: goal)
    }

    private func heroGoalLabel(for goal: Goal) -> String {
        if sessionTarget != nil {
            return "Session active"
        }
        guard let target = heroTarget(for: goal) else {
            return "Open count"
        }
        return "\(target) total"
    }

    private func heroRemainingLabel(for goal: Goal) -> String? {
        if let sessionTarget {
            return "\(max(sessionTarget - sessionProgress(for: goal), 0)) remaining"
        }
        guard goal.targetPolicy != .none else { return nil }
        return "\(store.remaining(for: goal, slotID: activeCountSlotID(for: goal))) remaining"
    }

    private func heroDenominatorText(for goal: Goal) -> String? {
        heroTarget(for: goal).map(formattedNumber)
    }

    private func heroTodayChipText(for goal: Goal) -> String? {
        guard sessionTarget == nil else { return nil }
        let count = displayedCount(for: goal)
        guard count > 0 else { return nil }
        return "\(formattedNumber(count)) today"
    }

    private func countButtonEnabled(for goal: Goal) -> Bool {
        goal.targetPolicy == .none || store.remaining(for: goal, slotID: activeCountSlotID(for: goal)) > 0
    }

    private func countingActionRow(goal: Goal, dhikr: Dhikr) -> some View {
        HStack(spacing: 14) {
            if services.audio.sourceURL(for: dhikr) != nil {
                Button {
                    toggleAudioCounting(goal: goal, dhikr: dhikr)
                } label: {
                    Text(LocalizedStringKey(services.audio.isCounting(goalID: goal.id) ? "Stop Audio Count" : "Start Audio Count"))
                        .font(AwradTheme.bodyFont(.headline, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
                .modifier(GlassControlModifier(
                    cornerRadius: 18,
                    tint: services.audio.isCounting(goalID: goal.id) ? Color.red.opacity(0.82) : AwradTheme.sage
                ))
                .disabled(audioStartDisabled(for: goal))
                .coachAnchor("audio")
            }

            CounterIconButton(symbol: "scope") {
                openSessionTarget(for: goal)
            }
            .accessibilityLabel(Text("Set session target"))
            .coachAnchor("session")

            CounterIconButton(symbol: "chart.bar.fill") {
                activeSheet = .history
            }
            .accessibilityLabel(Text("View history"))
            .coachAnchor("history")
        }
    }

    private func sessionTargetCard(for goal: Goal) -> some View {
        AwradCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 12) {
                    Label("Session Target", systemImage: "scope")
                        .font(AwradTheme.bodyFont(.headline, weight: .semibold))
                    Spacer()
                    Button {
                        openSessionTarget(for: goal)
                    } label: {
                        Text(LocalizedStringKey(sessionTarget == nil ? "Set Target" : "Change Target"))
                    }
                    .buttonStyle(.bordered)
                    .tint(AwradTheme.sage)
                }

                if let sessionTarget {
                    let completed = min(sessionProgress(for: goal), sessionTarget)
                    AwradProgressBar(value: sessionProgressValue(for: goal), height: 9)
                    HStack {
                        Text(AwradLocalizer.format("%d of %d this session", language: language, completed, sessionTarget))
                            .font(AwradTheme.bodyFont(.subheadline, weight: .semibold))
                            .foregroundStyle(AwradTheme.ink)
                        Spacer()
                        if sessionProgress(for: goal) >= sessionTarget {
                            Label("Session Complete", systemImage: "checkmark.circle.fill")
                                .font(AwradTheme.bodyFont(.caption, weight: .semibold))
                                .foregroundStyle(AwradTheme.sage)
                        }
                    }
                    Button(role: .destructive) {
                        clearSessionTarget(for: goal)
                    } label: {
                        Label("Reset Session", systemImage: "arrow.counterclockwise")
                    }
                    .buttonStyle(.bordered)
                } else {
                    Text("Set a short target for this sitting.")
                        .font(AwradTheme.bodyFont(.subheadline))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func add(_ amount: Int) {
        // Slot timing guard applies only to positive manual counts on slot goals.
        if amount > 0, let goal, let slotID = activeCountSlotID(for: goal),
           let slot = goal.slots.first(where: { $0.id == slotID }) {
            let status = SlotStatusCalculator.status(for: slot, nowMinuteOfDay: nowMinuteOfDay)
            let decision = SlotStatusCalculator.countability(status: status, policy: goal.slotCountingPolicy)
            if !decision.allowed {
                presentCap("slot_count_blocked_outside_active")
                return
            }
            if decision.warns, !confirmedOutOfWindowSlots.contains(slotID) {
                pendingOutOfWindowCount = true
                return
            }
        }
        performCount(amount)
    }

    private func performCount(_ amount: Int) {
        let result = store.applyCount(goalID: goalID, slotID: activeCountSlotID(for: goal), amount: amount)
        #if os(iOS)
        if store.preferences.vibrateOnCount, result.appliedDelta > 0 {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
        if store.preferences.soundOnCount, result.appliedDelta > 0 {
            AudioServicesPlaySystemSound(1104)
        }
        #endif
        switch result.capEvent {
        case .warnedOverTarget:
            presentCap("count_over_target_warning")
        case .blocked:
            presentCap("count_hard_cap_reached")
        case .none:
            break
        }
        if showCoachMarks, result.appliedDelta > 0 {
            coachTapProgress += 1
        }
        refreshLiveActivity()
        stopAudioIfTargetReached()
        evaluateCompletion()
    }

    private var coachSteps: [CountingCoachStep] {
        guard let goal else { return [] }
        var steps: [CountingCoachStep] = [
            CountingCoachStep(
                id: "tap",
                titleKey: "coach_tap_title",
                bodyKey: "coach_tap_body",
                symbol: "hand.tap.fill",
                targetID: "tap",
                circle: true,
                gate: .taps(required: 3)
            ),
            CountingCoachStep(
                id: "progress",
                titleKey: "coach_progress_title",
                bodyKey: "coach_progress_body",
                symbol: "chart.bar.fill",
                targetID: "progress"
            ),
            CountingCoachStep(
                id: "session",
                titleKey: "coach_session_title",
                bodyKey: "coach_session_body",
                symbol: "scope",
                targetID: "session"
            ),
            CountingCoachStep(
                id: "history",
                titleKey: "coach_history_title",
                bodyKey: "coach_history_body",
                symbol: "clock.arrow.circlepath",
                targetID: "history"
            )
        ]
        if let dhikr = store.dhikr(id: goal.dhikrID), services.audio.sourceURL(for: dhikr) != nil {
            steps.append(
                CountingCoachStep(
                    id: "audio",
                    titleKey: "coach_audio_title",
                    bodyKey: "coach_audio_body",
                    symbol: "waveform",
                    targetID: "audio",
                    gate: .audioPlays(required: 3)
                )
            )
        }
        return steps
    }

    private func finishCoachMarks() {
        showCoachMarks = false
        store.updatePreferences { $0.hasSeenCountingGuide = true }
    }

    private func presentCap(_ message: LocalizedStringKey) {
        capMessage = message
        showCapMessage = true
    }

    /// Shows the goal-completion dialog once the goal is fully complete.
    private func evaluateCompletion() {
        guard let goal = store.goal(id: goalID) else { return }
        if goal.isCompleted, !didShowCompletion {
            didShowCompletion = true
            showCompletionDialog = true
            liveActivity.end()
        }
    }

    /// The active slot is complete but the goal still has incomplete slots.
    private func showsSlotCompleteBanner(for goal: Goal) -> Bool {
        guard goal.slots.count > 1, !goal.isCompleted else { return false }
        let slotComplete = store.remaining(for: goal, slotID: activeCountSlotID(for: goal)) == 0
            && goal.targetPolicy != .none
        guard slotComplete else { return false }
        return goal.slots.contains { slot in
            store.remaining(for: goal, slotID: slot.id) > 0
        }
    }

    private func selectNextIncompleteSlot(for goal: Goal) {
        let next = goal.slots
            .sorted { $0.sortOrder < $1.sortOrder }
            .first { store.remaining(for: goal, slotID: $0.id) > 0 }
        if let next {
            selectedSlotID = next.id
        }
    }

    private func updateIdleTimer(enabled: Bool) {
        #if os(iOS)
        UIApplication.shared.isIdleTimerDisabled = enabled
        #endif
    }

    private func displayedCount(for goal: Goal) -> Int {
        guard goal.slots.count > 1 else { return store.count(for: goal) }
        return store.count(for: goal, slotID: selectedSlotID)
    }

    private func displayedProgress(for goal: Goal) -> Double {
        guard goal.slots.count > 1 else { return store.progress(for: goal) }
        let target = selectedSlotTarget(for: goal)
        guard target > 0 else { return 0 }
        return min(Double(displayedCount(for: goal)) / Double(target), 1)
    }

    private func counterSubtitle(for goal: Goal) -> String {
        guard goal.targetPolicy != .none else {
            return AwradLocalizer.localized("Open-ended count", language: language)
        }

        let remaining = store.remaining(for: goal, slotID: goal.slots.count > 1 ? selectedSlotID : nil)
        if goal.slots.count > 1,
           let slot = goal.slots.first(where: { $0.id == selectedSlotID }) {
            return AwradLocalizer.format(
                "%d remaining in %@",
                language: language,
                remaining,
                slot.displayLabel(language: language)
            )
        }
        return AwradLocalizer.format("%d remaining of %d", language: language, remaining, goal.totalTarget)
    }

    private func selectedSlotTarget(for goal: Goal) -> Int {
        selectedSlotID
            .flatMap { id in goal.slots.first { $0.id == id }?.targetCount }
            ?? goal.totalTarget
    }

    private func adjustmentTarget(for goal: Goal) -> Int? {
        goal.targetPolicy == .none ? nil : selectedSlotTarget(for: goal)
    }

    private func slotCards(for goal: Goal) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 146), spacing: 12)], spacing: 12) {
            ForEach(goal.slots) { slot in
                let count = store.count(for: goal, slotID: slot.id)
                let target = max(slot.targetCount ?? goal.totalTarget, 1)
                let isSelected = selectedSlotID == slot.id
                Button {
                    selectedSlotID = slot.id
                } label: {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(slot.displayLabel(language: language))
                                .font(AwradTheme.bodyFont(.caption, weight: .semibold))
                                .lineLimit(1)
                            Spacer()
                            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(isSelected ? AwradTheme.sage : .secondary)
                        }
                        Text("\(count) / \(target)")
                            .font(AwradTheme.bodyFont(.headline, weight: .semibold).monospacedDigit())
                            .foregroundStyle(AwradTheme.ink)
                        AwradProgressBar(value: min(Double(count) / Double(target), 1), height: 8)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, minHeight: 106, alignment: .topLeading)
                    .background(isSelected ? AwradTheme.sage.opacity(0.14) : AwradTheme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(isSelected ? AwradTheme.sage.opacity(0.45) : AwradTheme.sage.opacity(0.12), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func audioCountingControls(goal: Goal, dhikr: Dhikr) -> some View {
        Group {
            if services.audio.sourceURL(for: dhikr) != nil {
                AwradCard {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "waveform.circle.fill")
                                .font(AwradTheme.bodyFont(26))
                                .foregroundStyle(AwradTheme.gold)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Audio Counting")
                                    .font(AwradTheme.bodyFont(.headline, weight: .semibold))
                                Text(AwradLocalizer.format("%d count per completed play", language: language, dhikr.audioCountPerPlay))
                                    .font(AwradTheme.bodyFont(.caption))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if dhikr.isDownloaded {
                                Label("Offline", systemImage: "checkmark.circle.fill")
                                    .font(AwradTheme.bodyFont(.caption, weight: .semibold))
                                    .foregroundStyle(AwradTheme.sage)
                            }
                        }

                        if services.audio.isCounting(goalID: goal.id) {
                            ProgressView(value: services.audio.progress)
                                .tint(AwradTheme.sage)
                            HStack {
                                Text(services.audio.elapsedText)
                                Spacer()
                                Text(services.audio.durationText)
                            }
                            .font(AwradTheme.bodyFont(.caption).monospacedDigit())
                            .foregroundStyle(.secondary)
                        }

                        HStack(spacing: 12) {
                            Button {
                                toggleAudioCounting(goal: goal, dhikr: dhikr)
                            } label: {
                                Label {
                                    Text(LocalizedStringKey(audioButtonTitle(for: goal)))
                                } icon: {
                                    Image(systemName: audioButtonSymbol(for: goal))
                                }
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                            .tint(AwradTheme.sage)
                            .disabled(audioStartDisabled(for: goal))

                            if services.audio.isCounting(goalID: goal.id) {
                                Button {
                                    services.audio.stop()
                                } label: {
                                    Image(systemName: "stop.fill")
                                        .frame(width: 46, height: 46)
                                }
                                .buttonStyle(.bordered)
                                .tint(AwradTheme.sage)
                                .accessibilityLabel(Text("Stop audio counting"))
                            }
                        }

                        if services.audio.isCounting(goalID: goal.id) {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Label("Speed", systemImage: "speedometer")
                                    Spacer()
                                    Text("\(services.audio.playbackRate, specifier: "%.2g")x")
                                        .monospacedDigit()
                                }
                                .font(AwradTheme.bodyFont(.caption, weight: .semibold))
                                .foregroundStyle(.secondary)
                                Slider(
                                    value: Binding(
                                        get: { services.audio.playbackRate },
                                        set: { services.audio.playbackRate = $0 }
                                    ),
                                    in: 0.75...3,
                                    step: 0.25
                                )
                                .tint(AwradTheme.sage)
                            }
                        }
                    }
                }
            }
        }
    }

    private func audioButtonTitle(for goal: Goal) -> String {
        guard services.audio.isCounting(goalID: goal.id) else { return "Play Loop" }
        return services.audio.isPlaying ? "Pause" : "Resume"
    }

    private func audioButtonSymbol(for goal: Goal) -> String {
        guard services.audio.isCounting(goalID: goal.id) else { return "play.fill" }
        return services.audio.isPlaying ? "pause.fill" : "play.fill"
    }

    private func audioStartDisabled(for goal: Goal) -> Bool {
        guard !services.audio.isCounting(goalID: goal.id), goal.targetPolicy != .none else { return false }
        return store.remaining(for: goal, slotID: activeCountSlotID(for: goal)) == 0
    }

    private func toggleAudioCounting(goal: Goal, dhikr: Dhikr) {
        if services.audio.isCounting(goalID: goal.id) {
            services.audio.isPlaying ? services.audio.pause() : services.audio.play()
            return
        }

        let goalID = goal.id
        let slotID = activeCountSlotID(for: goal)
        services.audio.startCounting(for: dhikr, goalID: goalID, title: dhikr.displayTitle(language: language)) { [store] in
            guard let currentGoal = store.goal(id: goalID) else { return false }
            let actualDelta = store.addCount(goalID: goalID, slotID: slotID, amount: dhikr.audioCountPerPlay)
            if currentGoal.targetPolicy == .none {
                return true
            }
            guard actualDelta > 0, let updatedGoal = store.goal(id: goalID) else {
                return false
            }
            return store.remaining(for: updatedGoal, slotID: slotID) > 0
        }
    }

    private func stopAudioIfTargetReached() {
        guard let goal = store.goal(id: goalID),
              services.audio.isCounting(goalID: goalID),
              goal.targetPolicy != .none,
              store.remaining(for: goal, slotID: activeCountSlotID(for: goal)) == 0 else {
            return
        }
        services.audio.stop()
    }

    private func activeCountSlotID(for goal: Goal?) -> AwradID? {
        guard let goal, goal.slots.count > 1 else { return nil }
        return selectedSlotID ?? goal.slots.sorted { $0.sortOrder < $1.sortOrder }.first?.id
    }

    private func sessionProgress(for goal: Goal) -> Int {
        max(displayedCount(for: goal) - sessionStartCount, 0)
    }

    private func sessionProgressValue(for goal: Goal) -> Double {
        guard let sessionTarget, sessionTarget > 0 else { return 0 }
        return min(Double(sessionProgress(for: goal)) / Double(sessionTarget), 1)
    }

    private func openSessionTarget(for goal: Goal) {
        sessionDraftType = sessionType
        sessionDraftTarget = sessionTarget ?? (sessionDraftType == .timer ? 10 : suggestedSessionTarget(for: goal))
        activeSheet = .sessionTarget
    }

    private func openAdjustmentSheet() {
        adjustmentAmount = 1
        adjustmentMode = .add
        activeSheet = .adjustCount
    }

    private func suggestedSessionTarget(for goal: Goal) -> Int {
        let remaining = store.remaining(for: goal, slotID: goal.slots.count > 1 ? selectedSlotID : nil)
        if goal.targetPolicy != .none, remaining > 0 {
            return min(max(remaining, 1), 100)
        }
        return 33
    }

    private func applySessionTarget(for goal: Goal) {
        sessionType = sessionDraftType
        sessionTarget = max(sessionDraftTarget, 1)
        sessionStartCount = displayedCount(for: goal)
        if sessionType == .timer {
            sessionTimerEnd = Date().addingTimeInterval(TimeInterval(max(sessionDraftTarget, 1) * 60))
        } else {
            sessionTimerEnd = nil
        }
    }

    private func clearSessionTarget(for goal: Goal) {
        sessionTarget = nil
        sessionTimerEnd = nil
        sessionType = .count
        sessionStartCount = displayedCount(for: goal)
    }

    private func applyAdjustment(for goal: Goal) {
        let amount = max(adjustmentAmount, 1)
        add(adjustmentMode == .add ? amount : -amount)
        if sessionTarget != nil {
            sessionStartCount = min(sessionStartCount, displayedCount(for: goal))
        }
    }
}

private struct CountingTopChrome: View {
    let title: String
    let onBack: () -> Void
    let onHistory: () -> Void
    let onAdjust: () -> Void

    var body: some View {
        Group {
            if #available(iOS 26.0, *) {
                GlassEffectContainer(spacing: 10) {
                    chromeContent
                }
            } else {
                chromeContent
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 56)
        .background(.thinMaterial)
    }

    private var chromeContent: some View {
        HStack(spacing: 8) {
            chromeIconButton(symbol: "chevron.left", action: onBack, accessibilityLabel: "Back")

            Text(title)
                .font(AwradTheme.displayFont(20, weight: .semibold))
                .foregroundStyle(AwradTheme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .frame(maxWidth: .infinity, alignment: .leading)

            Menu {
                Button {
                    onHistory()
                } label: {
                    Label("History", systemImage: "chart.bar.fill")
                }
                Button {
                    onAdjust()
                } label: {
                    Label("Adjust Count", systemImage: "plus")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(AwradTheme.bodyFont(20, weight: .bold))
                    .rotationEffect(.degrees(90))
                    .frame(width: 38, height: 38)
            }
            .buttonStyle(.plain)
            .foregroundStyle(AwradTheme.ink)
            .modifier(GlassControlModifier(cornerRadius: 19))
            .accessibilityLabel(Text("More options"))
        }
    }

    private func chromeIconButton(symbol: String, action: @escaping () -> Void, accessibilityLabel: String) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(AwradTheme.bodyFont(20, weight: .semibold))
                .frame(width: 38, height: 38)
        }
        .buttonStyle(.plain)
        .foregroundStyle(AwradTheme.ink)
        .modifier(GlassControlModifier(cornerRadius: 19))
        .accessibilityLabel(Text(accessibilityLabel))
    }
}

private struct CountingTargetReadout: View {
    let currentText: String
    let denominatorText: String?
    let todayChipText: String?
    let progress: Double

    var body: some View {
        VStack(alignment: .center, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .lastTextBaseline, spacing: 0) {
                        Text(currentText)
                            .font(AwradTheme.bodyFont(34, weight: .bold))
                            .foregroundStyle(AwradTheme.ink)
                            .monospacedDigit()
                            .contentTransition(.numericText())
                        if let denominatorText {
                            Text("/\(denominatorText)")
                                .font(AwradTheme.bodyFont(28, weight: .semibold))
                                .foregroundStyle(AwradTheme.subdued)
                                .monospacedDigit()
                        }
                    }

                    HStack(alignment: .lastTextBaseline, spacing: 0) {
                        Text(currentText)
                            .font(AwradTheme.bodyFont(29, weight: .bold))
                            .foregroundStyle(AwradTheme.ink)
                            .monospacedDigit()
                        if let denominatorText {
                            Text("/\(denominatorText)")
                                .font(AwradTheme.bodyFont(23, weight: .semibold))
                                .foregroundStyle(AwradTheme.subdued)
                                .monospacedDigit()
                        }
                    }
                }

                if let todayChipText {
                    Text("(\(todayChipText))")
                        .font(AwradTheme.bodyFont(.callout, weight: .semibold))
                        .foregroundStyle(AwradTheme.sage)
                        .lineLimit(1)
                }

            }
            .frame(maxWidth: .infinity, alignment: .center)

            CountingProgressTrack(value: progress)
        }
        .padding(.horizontal, 4)
        .padding(.top, 14)
        .padding(.bottom, 2)
        .frame(maxWidth: .infinity, alignment: .center)
    }
}

private struct CountingProgressTrack: View {
    let value: Double

    var body: some View {
        GeometryReader { proxy in
            let clampedValue = min(max(value, 0), 1)
            let width = proxy.size.width
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(AwradTheme.mint.opacity(0.40))
                Capsule()
                    .fill(AwradTheme.sage)
                    .frame(width: max(6, width * clampedValue))
                Capsule()
                    .fill(AwradTheme.sage)
                    .frame(width: 9, height: 9)
                    .offset(x: min(max(0, width * clampedValue - 4.5), max(0, width - 9)))
            }
        }
        .frame(height: 9)
    }
}

private struct DhikrPreviewCard: View {
    let arabic: String
    let onShowFull: () -> Void

    private var shouldShowFullButton: Bool {
        arabic.count > 78 || arabic.contains("\n")
    }

    var body: some View {
        VStack(spacing: 4) {
            Text(arabic)
                .font(AwradTheme.arabicFont(25, weight: .semibold))
                .foregroundStyle(AwradTheme.ink)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.72)
                .lineSpacing(0)
                .frame(maxWidth: .infinity, minHeight: shouldShowFullButton ? 74 : 70)
                .padding(.horizontal, 16)
                .environment(\.layoutDirection, .rightToLeft)

            if shouldShowFullButton {
                Button(action: onShowFull) {
                    Text("see full")
                        .font(AwradTheme.bodyFont(.footnote, weight: .semibold))
                        .foregroundStyle(AwradTheme.sage)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, shouldShowFullButton ? 8 : 7)
        .modifier(GlassSurfaceModifier(cornerRadius: 22, tint: AwradTheme.mint.opacity(0.10)))
    }
}

private struct CounterIconButton: View {
    let symbol: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(AwradTheme.bodyFont(21, weight: .bold))
                .foregroundStyle(AwradTheme.sageDark)
                .frame(width: 48, height: 48)
        }
        .buttonStyle(.plain)
        .modifier(GlassControlModifier(cornerRadius: 16, tint: AwradTheme.mint.opacity(0.45)))
    }
}

private struct CompactAudioStatus: View {
    let progress: Double
    let elapsedText: String
    let durationText: String
    let playbackRate: Double
    let onStop: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            ProgressView(value: progress)
                .tint(AwradTheme.sage)

            HStack {
                Text(elapsedText)
                Spacer()
                Text("\(playbackRate, specifier: "%.2g")x")
                Spacer()
                Text(durationText)
                Button(action: onStop) {
                    Image(systemName: "stop.fill")
                        .font(AwradTheme.bodyFont(.caption, weight: .bold))
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .foregroundStyle(AwradTheme.sageDark)
                .background(AwradTheme.mint, in: Circle())
            }
            .font(AwradTheme.bodyFont(.caption).monospacedDigit())
            .foregroundStyle(AwradTheme.subdued)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(AwradTheme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct FullDhikrSheet: View {
    let arabic: String
    let onCount: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                Text(arabic)
                    .font(AwradTheme.arabicFont(32, weight: .semibold))
                    .foregroundStyle(AwradTheme.ink)
                    .multilineTextAlignment(.center)
                    .lineSpacing(12)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 24)
                    .padding(.top, 56)
                    .padding(.bottom, 28)
                    .environment(\.layoutDirection, .rightToLeft)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            VStack(spacing: 10) {
                Button {
                    onCount()
                } label: {
                    Text("COUNT")
                        .font(AwradTheme.bodyFont(.headline, weight: .bold))
                        .tracking(2)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 64)
                }
                .buttonStyle(.plain)
                .modifier(GlassControlModifier(cornerRadius: 16, tint: AwradTheme.sage))

                Text("Tap to increment")
                    .font(AwradTheme.bodyFont(.subheadline))
                    .foregroundStyle(AwradTheme.subdued)
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 16)
            .background(AwradTheme.background)
        }
        .background(AwradTheme.surface)
    }
}

private struct CountCircleButton: View {
    let isEnabled: Bool
    let onCount: () -> Void

    var body: some View {
        GeometryReader { proxy in
            let buttonSize = max(0, min(proxy.size.width, proxy.size.height))
            Button(action: onCount) {
                Text("COUNT")
                    .font(AwradTheme.bodyFont(.headline, weight: .bold))
                    .tracking(2)
                    .foregroundStyle(.white)
                    .frame(width: buttonSize, height: buttonSize)
                    .modifier(GlassCircleControlModifier(tint: AwradTheme.sage))
                    .opacity(isEnabled ? 1 : 0.45)
                    .coachAnchor("tap")
            }
            .buttonStyle(.plain)
            .disabled(!isEnabled)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .accessibilityLabel(Text("Count"))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.bottom, 24)
    }
}

private struct GlassSurfaceModifier: ViewModifier {
    let cornerRadius: CGFloat
    let tint: Color

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        if #available(iOS 26.0, *) {
            content
                .background(tint.opacity(0.18), in: shape)
                .glassEffect(.regular.tint(tint), in: shape)
        } else {
            content
                .background(.ultraThinMaterial, in: shape)
                .overlay(shape.stroke(AwradTheme.sage.opacity(0.18), lineWidth: 1))
        }
    }
}

private struct GlassControlModifier: ViewModifier {
    let cornerRadius: CGFloat
    var tint: Color = AwradTheme.mint.opacity(0.50)

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        if #available(iOS 26.0, *) {
            content
                .background(tint.opacity(0.76), in: shape)
                .glassEffect(.regular.tint(tint).interactive(true), in: shape)
        } else {
            content
                .background(tint, in: shape)
                .overlay(shape.stroke(.white.opacity(0.22), lineWidth: 1))
        }
    }
}

private struct GlassCircleControlModifier: ViewModifier {
    let tint: Color

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .background(tint.opacity(0.84), in: Circle())
                .glassEffect(.regular.tint(tint).interactive(true), in: Circle())
        } else {
            content
                .background(tint, in: Circle())
        }
    }
}

private struct MinimumStreakChip: View {
    let text: String

    var body: some View {
        Label(text, systemImage: "flame.fill")
            .font(AwradTheme.bodyFont(.caption, weight: .semibold))
            .foregroundStyle(AwradTheme.gold)
            .padding(.horizontal, 12)
            .frame(minHeight: 32)
            .background(AwradTheme.gold.opacity(0.14), in: Capsule())
    }
}

private struct SessionTimerChip: View {
    let endDate: Date

    var body: some View {
        Label {
            Text(timerInterval: Date()...max(endDate, Date().addingTimeInterval(1)), countsDown: true)
                .monospacedDigit()
        } icon: {
            Image(systemName: "timer")
        }
        .font(AwradTheme.bodyFont(.caption, weight: .semibold))
        .foregroundStyle(AwradTheme.sage)
        .padding(.horizontal, 12)
        .frame(minHeight: 32)
        .background(AwradTheme.sage.opacity(0.14), in: Capsule())
    }
}

private struct SlotCompleteBanner: View {
    let language: AppLanguage
    let onSelectNext: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.seal.fill")
                .foregroundStyle(AwradTheme.sage)
            VStack(alignment: .leading, spacing: 2) {
                Text(LocalizedStringKey("counting_slot_complete"))
                    .font(AwradTheme.bodyFont(.subheadline, weight: .semibold))
                    .foregroundStyle(AwradTheme.ink)
            }
            Spacer(minLength: 0)
            Button(action: onSelectNext) {
                Text(LocalizedStringKey("counting_select_next_slot"))
                    .font(AwradTheme.bodyFont(.caption, weight: .semibold))
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .tint(AwradTheme.sage)
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(AwradTheme.sage.opacity(0.1), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct SessionTargetSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var target: Int
    @Binding var type: SessionTargetType

    let canClear: Bool
    let language: AppLanguage
    let onSave: () -> Void
    let onClear: () -> Void

    private let countPresets = [33, 100, 500, 1_000]
    private let timerPresets = [5, 10, 15, 30]

    private var presets: [Int] { type == .timer ? timerPresets : countPresets }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Mode", selection: $type) {
                        Text(LocalizedStringKey("counting_session_count_tab")).tag(SessionTargetType.count)
                        Text(LocalizedStringKey("counting_session_timer_tab")).tag(SessionTargetType.timer)
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: type) { _, newValue in
                        target = newValue == .timer ? 10 : 33
                    }
                }

                Section("This Session") {
                    if type == .timer {
                        Stepper(value: $target, in: 1...600, step: 1) {
                            Text(AwradLocalizer.format("%d minutes", language: language, target))
                        }
                    } else {
                        Stepper(value: $target, in: 1...100_000, step: 1) {
                            Text(AwradLocalizer.format("Target %d", language: language, target))
                        }
                    }

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 88), spacing: 10)], spacing: 10) {
                        ForEach(presets, id: \.self) { preset in
                            Button {
                                target = preset
                            } label: {
                                Text("\(preset)")
                                    .font(AwradTheme.bodyFont(.headline, weight: .semibold).monospacedDigit())
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .tint(target == preset ? AwradTheme.sage : .secondary)
                        }
                    }
                }

                if canClear {
                    Section {
                        Button(role: .destructive) {
                            onClear()
                            dismiss()
                        } label: {
                            Label("Reset Session", systemImage: "arrow.counterclockwise")
                        }
                    }
                }
            }
            .navigationTitle("Session Target")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        onSave()
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct CountAdjustmentSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var amount: Int
    @Binding var mode: CountAdjustmentMode

    let currentCount: Int
    let targetCount: Int?
    let language: AppLanguage
    let onApply: () -> Void

    @State private var showSubtractWarning = false

    private var effectiveAmount: Int {
        max(amount, 1)
    }

    private var afterAdjustment: Int {
        switch mode {
        case .add:
            guard let targetCount else {
                return currentCount + effectiveAmount
            }
            return min(currentCount + effectiveAmount, targetCount)
        case .subtract:
            return max(currentCount - effectiveAmount, 0)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Adjustment") {
                    Picker("Mode", selection: $mode) {
                        ForEach(CountAdjustmentMode.allCases) { mode in
                            Text(mode.titleKey).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    TextField("Count Amount", value: $amount, format: .number)
                        #if os(iOS)
                        .keyboardType(.numberPad)
                        #endif
                        .onChange(of: amount) { _, newValue in
                            if newValue < 1 {
                                amount = 1
                            }
                        }

                    Stepper(value: $amount, in: 1...100_000, step: 1) {
                        Text(AwradLocalizer.format("Amount %d", language: language, effectiveAmount))
                    }

                    if mode == .add, targetCount != nil {
                        Text("Additions are capped at the target.")
                            .font(AwradTheme.bodyFont(.caption))
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Preview") {
                    LabeledContent("Current Count", value: "\(currentCount)")
                    LabeledContent("After Adjustment", value: "\(afterAdjustment)")
                }
            }
            .navigationTitle("Adjust Count")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        submit()
                    }
                }
            }
            .confirmationDialog("Confirm Subtraction", isPresented: $showSubtractWarning, titleVisibility: .visible) {
                Button("Subtract Count", role: .destructive) {
                    applyAndDismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Subtracting reduces today's saved count. This cannot be undone automatically.")
            }
        }
    }

    private func submit() {
        amount = effectiveAmount
        if mode == .subtract {
            showSubtractWarning = true
            return
        }
        applyAndDismiss()
    }

    private func applyAndDismiss() {
        amount = effectiveAmount
        onApply()
        dismiss()
    }
}

private struct CountHistorySheet: View {
    @Environment(\.dismiss) private var dismiss

    let goal: Goal
    let entries: [CountEntry]
    let language: AppLanguage

    var body: some View {
        NavigationStack {
            List {
                if entries.isEmpty {
                    EmptyStateView(
                        symbol: "clock.arrow.circlepath",
                        title: "No count history yet",
                        message: "Counts appear here after you begin."
                    )
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(entries) { entry in
                        CountHistoryRow(
                            entry: entry,
                            slotTitle: slotTitle(for: entry),
                            language: language
                        )
                    }
                }
            }
            .navigationTitle("Count History")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func slotTitle(for entry: CountEntry) -> String {
        entry.slotID
            .flatMap { id in goal.slots.first { $0.id == id }?.displayLabel(language: language) }
            ?? AwradLocalizer.localized("Anytime", language: language)
    }
}

private struct CountHistoryRow: View {
    let entry: CountEntry
    let slotTitle: String
    let language: AppLanguage

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "number.circle.fill")
                .foregroundStyle(AwradTheme.sage)
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(dateTitle)
                    .font(AwradTheme.bodyFont(.subheadline, weight: .semibold))
                Text(slotTitle)
                    .font(AwradTheme.bodyFont(.caption))
                    .foregroundStyle(.secondary)
                Text(AwradLocalizer.format(
                    "Updated %@",
                    language: language,
                    AwradLocalizer.formattedTime(entry.lastUpdated, language: language)
                ))
                .font(AwradTheme.bodyFont(.caption2))
                .foregroundStyle(.secondary)
            }

            Spacer()

            Text("+\(entry.count)")
                .font(AwradTheme.bodyFont(.headline, weight: .semibold).monospacedDigit())
                .foregroundStyle(AwradTheme.sageDark)
        }
        .padding(.vertical, 4)
    }

    private var dateTitle: String {
        if entry.dateKey == "all-time" {
            return AwradLocalizer.localized("All time", language: language)
        }
        guard let date = Self.dateKeyFormatter.date(from: entry.dateKey) else {
            return entry.dateKey
        }
        return AwradLocalizer.gregorianDate(date, language: language)
    }

    private static let dateKeyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}
