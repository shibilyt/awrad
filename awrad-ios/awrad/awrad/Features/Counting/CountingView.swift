import SwiftUI
import Combine

#if os(iOS)
import AudioToolbox
import CoreHaptics
import UIKit
#endif

#if os(iOS)
private final class TargetReachedHapticController {
    private let targetReachedVibrationDuration = 1.0
    private var engine: CHHapticEngine?
    private var player: CHHapticPatternPlayer?

    func play() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }

        do {
            let engine = try CHHapticEngine()
            let event = CHHapticEvent(eventType: .hapticContinuous, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
            ], relativeTime: 0, duration: targetReachedVibrationDuration)
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let player = try engine.makePlayer(with: pattern)

            self.engine = engine
            self.player = player
            try engine.start()
            try player.start(atTime: 0)
        } catch {
            player = nil
            engine = nil
        }
    }
}
#endif

private enum CounterSheet: String, Identifiable {
    case sessionTarget
    case adjustCount
    case history
    case fullDhikr
    case textDisplay
    case playbackSpeed

    var id: String { rawValue }
}

struct CountingRingProgress: Equatable {
    let progress: Double
    let minimumSegmentProgress: Double?
    let remainingSegmentProgress: Double?
    let minimumCheckpoint: Double?
    let activeTarget: Int64
}

func countingRingProgress(
    currentCount: Int64,
    minimumCount: Int,
    maximumCount: Int
) -> CountingRingProgress {
    precondition(minimumCount > 0, "minimumCount must be positive")
    precondition(maximumCount >= minimumCount, "maximumCount must be at least minimumCount")

    let activeTarget = currentCount < Int64(minimumCount) ? minimumCount : maximumCount
    let progress = min(max(Double(currentCount) / Double(activeTarget), 0), 1)
    let minimumCheckpoint = min(max(Double(minimumCount) / Double(maximumCount), 0), 1)
    let hasReachedMinimum = currentCount >= Int64(minimumCount)

    return CountingRingProgress(
        progress: progress,
        minimumSegmentProgress: hasReachedMinimum ? minimumCheckpoint : progress,
        remainingSegmentProgress: hasReachedMinimum
            ? min(max(progress - minimumCheckpoint, 0), 1)
            : 0,
        minimumCheckpoint: minimumCheckpoint,
        activeTarget: Int64(activeTarget)
    )
}

enum AudioCountingLoopPolicy {
    @MainActor
    static func shouldContinue(
        appliedDelta: Int64,
        goal: Goal,
        slotID: AwradID,
        store: AwradStore
    ) -> Bool {
        guard appliedDelta > 0 else { return false }
        return store.canIncrement(goal, slotID: slotID)
    }
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

private enum PendingCountingAvailabilityAction {
    case count(Int)
    case startAudio
    case resumeAudio
}

private struct PendingCountingAvailabilityConfirmation {
    var reasons: Set<CountingAvailabilityReason>
    var key: CountingAvailabilityConfirmationKey
    var action: PendingCountingAvailabilityAction
}

struct CountingView: View {
    @Environment(AwradStore.self) private var store
    @Environment(AppRouter.self) private var router
    @Environment(AppServices.self) private var services
    @Environment(\.dismiss) private var dismiss
    let goalID: AwradID
    @State private var selectedSlotID: AwradID?
    @State private var showAudioError = false
    @State private var showAudioExitConfirmation = false
    @State private var activeSheet: CounterSheet?
    @State private var sessionTarget: Int?
    @State private var sessionStartCount: Int64 = 0
    @State private var sessionDraftTarget = 33
    @State private var sessionType: SessionTargetType = .count
    @State private var sessionDraftType: SessionTargetType = .count
    @State private var sessionTimerEnd: Date?
    @State private var showSessionCompletionDialog = false
    @State private var completedSessionType: SessionTargetType = .count
    @State private var completedSessionTarget = 0
    @State private var adjustmentAmount = 1
    @State private var adjustmentMode = CountAdjustmentMode.add
    // Phase 3: cap warnings, slot timing guard, completion, ticker
    @State private var capMessage: LocalizedStringKey?
    @State private var showCapMessage = false
    @State private var didShowCompletion = false
    @State private var showCompletionDialog = false
    @State private var showAllowPastTargetConfirmation = false
    @State private var pendingCountingAvailability: PendingCountingAvailabilityConfirmation?
    // Phase 4: first-run coach marks
    @State private var showCoachMarks = false
    @State private var coachTapProgress = 0
    @State private var coachAudioProgress = 0
    @State private var liveActivity = CountingLiveActivityController()
    @State private var syncFeedback: CountingSyncFeedbackState?
    @State private var lastHandledRemoteCountEventID: UUID?
#if os(iOS)
    @State private var targetReachedHapticController = TargetReachedHapticController()
#endif

    private let minuteTicker = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    init(goalID: AwradID, initialSlotID: AwradID? = nil) {
        self.goalID = goalID
        _selectedSlotID = State(initialValue: initialSlotID)
    }

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
                        goalTag: GoalCardPresentation.targetTag(
                            goal: goal,
                            target: max(goal.totalTarget, goal.targetPolicy == .none ? 0 : 1),
                            language: language
                        ),
                        onBack: handleBack,
                        onHistory: { activeSheet = .history },
                        onAdjust: openAdjustmentSheet
                    )

                    VStack(spacing: 10) {
                        if sessionTarget == nil, let minimum = goal.minimumForStreak {
                            MinimumStreakChip(
                                text: AwradLocalizer.format("counting_min_for_streak", language: language, minimum)
                            )
                        }

                        if let endDate = sessionTimerEnd, sessionTarget != nil, sessionType == .timer {
                            SessionTimerChip(endDate: endDate)
                        }

                        DhikrPreviewCard(
                            arabic: dhikr.arabic,
                            textScale: store.preferences.countingDhikrTextScale,
                            onShowFull: {
                                if dhikr.quranRef != nil {
                                    router.navigate(
                                        .quranDhikrReader(
                                            dhikrID: dhikr.id,
                                            goalID: goal.id,
                                            slotID: selectedSlotID
                                        ),
                                        in: store.selectedTab
                                    )
                                } else {
                                    activeSheet = .fullDhikr
                                }
                            },
                            onAdjustText: { activeSheet = .textDisplay }
                        )

                        if goal.activeSlots.count > 1 {
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
                                isPlaying: services.audio.isPlaying,
                                progress: services.audio.progress,
                                elapsedText: services.audio.elapsedText,
                                durationText: services.audio.durationText,
                                playbackRate: services.audio.playbackRate,
                                onTogglePlayback: {
                                    if services.audio.isPlaying {
                                        services.audio.pause()
                                    } else if let slotID = activeCountSlotID(for: goal),
                                              authorizeCountingAvailability(.resumeAudio, goal: goal, slotID: slotID) {
                                        services.audio.play()
                                    }
                                },
                                onShowPlaybackSpeed: { activeSheet = .playbackSpeed }
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                    let ringProgress = countingRingPresentation(for: goal)
                    CountCircleButton(
                        isEnabled: !services.audio.isCounting(goalID: goal.id) && countButtonEnabled(for: goal),
                        primaryProgress: sessionTarget != nil ? heroProgress(for: goal) : ringProgress?.progress,
                        minimumSegmentProgress: ringProgress?.minimumSegmentProgress,
                        remainingSegmentProgress: ringProgress?.remainingSegmentProgress,
                        minimumCheckpoint: ringProgress?.minimumCheckpoint,
                        showsTargetReachedAlert: isPausedAtTarget(goal),
                        countText: formattedNumber(heroCurrentCount(for: goal)),
                        targetText: heroDenominatorText(for: goal).map { "of \($0)" },
                        onCount: { add(1) },
                        onKeepCounting: { showAllowPastTargetConfirmation = true }
                    )
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                    CountingHintOrSyncAlert(
                        feedback: syncFeedback,
                        language: language
                    )
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)
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
            }
        }
        .background(AwradTheme.background)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            services.setProgressSyncCountingActive(true)
            selectedSlotID = selectedSlotID ?? goal?.activeSlots.sorted { $0.sortOrder < $1.sortOrder }.first?.id
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
        .onChange(of: services.progressSync.remoteCountEvents) { _, events in
            guard let event = events.last(where: {
                $0.goalID == goalID.uuidString.lowercased()
            }), event.id != lastHandledRemoteCountEventID else { return }
            lastHandledRemoteCountEventID = event.id
            presentSyncFeedback(event)
        }
        .sheet(item: $activeSheet) { sheet in
            Group {
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
                        FullDhikrSheet(
                            arabic: dhikr.arabic,
                            textScale: store.preferences.countingDhikrTextScale,
                            lineSpacing: store.preferences.countingDhikrLineSpacing,
                            canCount: !services.audio.isCounting(goalID: goal.id) && countButtonEnabled(for: goal),
                            currentCount: displayedCount(for: goal),
                            targetCount: adjustmentTarget(for: goal),
                            onDecreaseTextSize: { adjustTextScale(increasing: false) },
                            onIncreaseTextSize: { adjustTextScale(increasing: true) },
                            onDecreaseLineSpacing: { adjustLineSpacing(increasing: false) },
                            onIncreaseLineSpacing: { adjustLineSpacing(increasing: true) },
                            onCount: { add(1) }
                        )
                        .presentationDetents([.large])
                        .presentationDragIndicator(.visible)
                    } else {
                        EmptyStateView(symbol: "text.book.closed", title: "Dhikr Missing", message: "This dhikr is no longer available.")
                    }
                case .textDisplay:
                    if let dhikr = store.dhikr(id: goal.dhikrID) {
                        DhikrDisplaySettingsSheet(
                            arabic: dhikr.arabic,
                            textScale: store.preferences.countingDhikrTextScale,
                            lineSpacing: store.preferences.countingDhikrLineSpacing,
                            onDecreaseTextSize: { adjustTextScale(increasing: false) },
                            onIncreaseTextSize: { adjustTextScale(increasing: true) },
                            onDecreaseLineSpacing: { adjustLineSpacing(increasing: false) },
                            onIncreaseLineSpacing: { adjustLineSpacing(increasing: true) }
                        )
                        .presentationDetents([.medium, .large])
                        .presentationDragIndicator(.visible)
                    }
                case .playbackSpeed:
                    PlaybackSpeedSheet(
                        playbackRate: Binding(
                            get: { services.audio.playbackRate },
                            set: { services.audio.playbackRate = $0 }
                        )
                    )
                    .presentationDetents([.height(316)])
                    .presentationDragIndicator(.visible)
                    }
                } else {
                    EmptyStateView(symbol: "target", title: "Goal Missing", message: "This goal is no longer available.")
                }
            }
            .awradSheetStyle()
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
            Text(countingAvailabilityConfirmationTitle),
            isPresented: pendingCountingAvailabilityBinding,
            titleVisibility: .visible
        ) {
            Button(countingAvailabilityConfirmationActionTitle) {
                confirmPendingCountingAvailability()
            }
            Button("Cancel", role: .cancel) {
                pendingCountingAvailability = nil
            }
        } message: {
            Text(countingAvailabilityConfirmationMessage)
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
        .confirmationDialog(
            "Allow counting past target?",
            isPresented: $showAllowPastTargetConfirmation,
            titleVisibility: .visible
        ) {
            Button("Allow") { allowCountingPastTarget() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently changes this slot’s cap to allow counts above the target. The goal will remain completed.")
        }
        .confirmationDialog(
            Text(completedSessionType == .timer ? "Timer session complete" : "Count session complete"),
            isPresented: $showSessionCompletionDialog,
            titleVisibility: .visible
        ) {
            Button("Start Another Session") {
                sessionDraftType = completedSessionType
                sessionDraftTarget = max(completedSessionTarget, 1)
                activeSheet = .sessionTarget
            }
            Button("Done") { dismiss() }
        } message: {
            Text(completedSessionType == .timer
                 ? "Your timed recitation session has ended."
                 : "You reached this sitting’s count target.")
        }
        .task(id: sessionTimerEnd) {
            guard let end = sessionTimerEnd else { return }
            let nanoseconds = UInt64(max(end.timeIntervalSinceNow, 0) * 1_000_000_000)
            try? await Task<Never, Never>.sleep(nanoseconds: nanoseconds)
            guard !Task<Never, Never>.isCancelled else { return }
            evaluateTimerSession()
        }
        .task(id: syncFeedback?.eventID) {
            guard syncFeedback != nil else { return }
            do {
                try await Task<Never, Never>.sleep(nanoseconds: 4_000_000_000)
            } catch {
                return
            }
            guard !Task<Never, Never>.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.2)) {
                syncFeedback = nil
            }
        }
        .onReceive(minuteTicker) { now in
            evaluateTimerSession()
            enforceAudioTiming(at: now)
        }
        .onDisappear {
            services.setProgressSyncCountingActive(false)
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
            targetCount: goal.targetPolicy == .none ? 0 : Int64(selectedSlotTarget(for: goal)),
            isPlaying: services.audio.isCounting(goalID: goal.id)
        )
    }

    private func presentSyncFeedback(_ event: RemoteCountSyncEvent) {
        let currentDelta = syncFeedback?.delta ?? 0
        let (combined, overflow) = currentDelta.addingReportingOverflow(event.delta)
        let delta = overflow ? event.delta : combined
        withAnimation(.easeInOut(duration: 0.2)) {
            syncFeedback = delta == 0
                ? nil
                : CountingSyncFeedbackState(eventID: event.id, delta: delta)
        }
    }

    private func refreshLiveActivity() {
        guard let goal else { return }
        liveActivity.update(
            currentCount: displayedCount(for: goal),
            targetCount: goal.targetPolicy == .none ? 0 : Int64(selectedSlotTarget(for: goal)),
            isPlaying: services.audio.isCounting(goalID: goal.id),
            audioPositionText: services.audio.isCounting(goalID: goal.id) ? services.audio.elapsedText : ""
        )
    }

    /// Fires the session-complete dialog when a TIMER session elapses.
    private func evaluateTimerSession() {
        guard sessionType == .timer, let end = sessionTimerEnd, let target = sessionTarget,
              Date() >= end, let goal else { return }
        completeSession(type: .timer, target: target, goal: goal)
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

    private func formattedNumber(_ value: Int64) -> String {
        value.formatted(.number)
    }

    private func heroCurrentCount(for goal: Goal) -> Int64 {
        if sessionTarget != nil, sessionType == .count {
            return sessionProgress(for: goal)
        }
        return displayedCount(for: goal)
    }

    private func heroTarget(for goal: Goal) -> Int64? {
        if let sessionTarget, sessionType == .count {
            return Int64(sessionTarget)
        }
        guard goal.targetPolicy != .none else { return nil }
        return Int64(goal.activeSlots.count > 1 ? selectedSlotTarget(for: goal) : goal.totalTarget)
    }

    private func heroProgress(for goal: Goal) -> Double {
        if sessionTarget != nil, sessionType == .count {
            return sessionProgressValue(for: goal)
        }
        return displayedProgress(for: goal)
    }

    private func heroGoalLabel(for goal: Goal) -> String {
        if sessionTarget != nil, sessionType == .count {
            return "Session active"
        }
        if sessionTarget != nil, sessionType == .timer { return "Timed session" }
        guard let target = heroTarget(for: goal) else {
            return "Open count"
        }
        return "\(target) total"
    }

    private func heroRemainingLabel(for goal: Goal) -> String? {
        if let sessionTarget, sessionType == .count {
            return "\(max(Int64(sessionTarget) - sessionProgress(for: goal), 0)) remaining"
        }
        guard goal.targetPolicy != .none else { return nil }
        return "\(store.remaining(for: goal, slotID: activeCountSlotID(for: goal))) remaining"
    }

    private func heroDenominatorText(for goal: Goal) -> String? {
        guard heroMilestoneText(for: goal) == nil else { return nil }
        if let ringProgress = countingRingPresentation(for: goal) {
            return formattedNumber(ringProgress.activeTarget)
        }
        return heroTarget(for: goal).map(formattedNumber)
    }

    private func heroMilestoneText(for goal: Goal) -> String? {
        guard sessionTarget == nil,
              goal.targetPolicy != .none,
              !usesRangeProgress(goal),
              let target = heroTarget(for: goal), target > 0 else { return nil }
        let current = heroCurrentCount(for: goal)
        guard current >= target else { return nil }
        let additional = current - target
        if additional == 0 {
            return AwradLocalizer.localized("Target reached", language: language)
        }
        return AwradLocalizer.format(
            "Target %@ reached · +%@ additional",
            language: language,
            formattedNumber(target),
            formattedNumber(additional)
        )
    }

    private func heroTodayChipText(for goal: Goal) -> String? {
        guard sessionTarget == nil else { return nil }
        let count = displayedCount(for: goal)
        guard count > 0 else { return nil }
        return "\(formattedNumber(count)) today"
    }

    private func countButtonEnabled(for goal: Goal) -> Bool {
        guard goal.targetPolicy != .none else { return true }
        let policy = activeCountPolicy(for: goal)
        let current = displayedCount(for: goal)
        switch policy.capBehavior {
        case .allowOverTarget, .warnOverTarget:
            return true
        case .blockAtTarget:
            return policy.targetCount.map { current < Int64($0) } ?? true
        case .blockAtMaximum:
            let limit = policy.maximumCount ?? policy.targetCount
            return limit.map { current < Int64($0) } ?? true
        }
    }

    private func activeCountPolicy(for goal: Goal) -> CountPolicy {
        if let slotID = activeCountSlotID(for: goal),
           let slot = goal.activeSlots.first(where: { $0.id == slotID }) {
            return slot.countPolicy
        }
        return goal.countPolicy
    }

    private func usesRangeProgress(_ goal: Goal) -> Bool {
        let policy = activeCountPolicy(for: goal)
        guard sessionTarget == nil,
              let minimum = policy.minimumCount, minimum > 1,
              let upper = policy.maximumCount ?? policy.targetCount else { return false }
        return upper >= minimum
    }

    private func countingRingPresentation(for goal: Goal) -> CountingRingProgress? {
        guard sessionTarget == nil else { return nil }
        let policy = activeCountPolicy(for: goal)
        guard let upper = policy.maximumCount ?? policy.targetCount, upper > 0 else { return nil }

        if let minimum = policy.minimumCount,
           minimum > 1,
           upper >= minimum {
            return countingRingProgress(
                currentCount: displayedCount(for: goal),
                minimumCount: minimum,
                maximumCount: upper
            )
        }

        return CountingRingProgress(
            progress: min(max(Double(displayedCount(for: goal)) / Double(upper), 0), 1),
            minimumSegmentProgress: nil,
            remainingSegmentProgress: nil,
            minimumCheckpoint: nil,
            activeTarget: Int64(upper)
        )
    }

    private func isPausedAtTarget(_ goal: Goal) -> Bool {
        guard !countButtonEnabled(for: goal) else { return false }
        let policy = activeCountPolicy(for: goal)
        return policy.capBehavior == .blockAtTarget
    }

    private func allowCountingPastTarget() {
        guard let goal,
              store.allowCountingPastTarget(
                goalID: goal.id,
                slotID: activeCountSlotID(for: goal)
              ) != nil else {
            presentCap("Could not change the counting cap. Try again.")
            return
        }
        presentCap("You can now continue counting past the target.")
    }

    private func countingActionRow(goal: Goal, dhikr: Dhikr) -> some View {
        HStack(spacing: 14) {
            if services.audio.sourceURL(for: dhikr) != nil {
                Button {
                    if services.audio.isCounting(goalID: goal.id) {
                        services.audio.stop()
                    } else {
                        startAudioCountingIfAllowed(goal: goal, dhikr: dhikr)
                    }
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
                    let completed = min(sessionProgress(for: goal), Int64(sessionTarget))
                    AwradProgressBar(value: sessionProgressValue(for: goal), height: 9)
                    HStack {
                        Text(AwradLocalizer.format("%d of %d this session", language: language, completed, sessionTarget))
                            .font(AwradTheme.bodyFont(.subheadline, weight: .semibold))
                            .foregroundStyle(AwradTheme.ink)
                        Spacer()
                        if sessionProgress(for: goal) >= Int64(sessionTarget) {
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
        guard amount > 0, let goal else {
            performCount(amount)
            return
        }
        let slotID = activeCountSlotID(for: goal)
        guard authorizeCountingAvailability(.count(amount), goal: goal, slotID: slotID) else {
            return
        }
        performCount(amount, slotID: slotID)
    }

    private func performCount(_ amount: Int, slotID: AwradID? = nil) {
        let resolvedSlotID = slotID ?? activeCountSlotID(for: goal)
        let result = store.applyCount(goalID: goalID, slotID: resolvedSlotID, amount: Int64(amount))
        #if os(iOS)
        if store.preferences.vibrateOnCount, result.appliedDelta > 0 {
            if result.targetReachedNow {
                targetReachedHapticController.play()
            } else {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
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
        evaluateCountSession()
        evaluateCompletion()
    }

    private func authorizeCountingAvailability(
        _ action: PendingCountingAvailabilityAction,
        goal: Goal,
        slotID: AwradID?,
        now: Date = Date()
    ) -> Bool {
        let slot: GoalSlot?
        if let slotID {
            guard let selectedSlot = goal.activeSlots.first(where: { $0.id == slotID }) else {
                return false
            }
            slot = selectedSlot
        } else {
            slot = nil
        }
        switch CountingAvailabilityCalculator.decision(
            for: goal,
            slot: slot,
            effectiveDateKey: store.todayKey,
            preferences: store.preferences,
            now: now,
            prayerTimeService: services.prayerTimes
        ) {
        case .allow:
            return true
        case let .hardBlock(reason):
            presentCap(hardBlockMessageKey(for: reason))
            return false
        case let .requiresConfirmation(reasons, key):
            guard !CountingAvailabilityConfirmationStore.isConfirmed(key) else { return true }
            pendingCountingAvailability = PendingCountingAvailabilityConfirmation(
                reasons: reasons,
                key: key,
                action: action
            )
            return false
        }
    }

    private var pendingCountingAvailabilityBinding: Binding<Bool> {
        Binding(
            get: { pendingCountingAvailability != nil },
            set: { if !$0 { pendingCountingAvailability = nil } }
        )
    }

    private var countingAvailabilityConfirmationTitle: String {
        AwradLocalizer.localized("counting_availability_title", language: language)
    }

    private var countingAvailabilityConfirmationActionTitle: String {
        let key = switch pendingCountingAvailability?.action {
        case .startAudio: "counting_availability_start_anyway"
        case .resumeAudio: "counting_availability_resume_anyway"
        case .count, .none: "counting_availability_count_anyway"
        }
        return AwradLocalizer.localized(key, language: language)
    }

    private var countingAvailabilityConfirmationMessage: String {
        guard let pending = pendingCountingAvailability else { return "" }
        let messages = pending.reasons.sorted { $0.rawValue < $1.rawValue }.map {
            countingAvailabilityMessage(for: $0, key: pending.key)
        }
        return messages.map { "• \($0)" }.joined(separator: "\n")
    }

    private func confirmPendingCountingAvailability() {
        guard let pending = pendingCountingAvailability else { return }
        pendingCountingAvailability = nil
        CountingAvailabilityConfirmationStore.confirm(pending.key)
        guard store.todayKey == pending.key.effectiveDateKey else { return }

        switch pending.action {
        case let .count(amount):
            performCount(amount, slotID: pending.key.slotID)
        case .startAudio:
            guard let goal = store.goal(id: goalID),
                  let dhikr = store.dhikr(id: goal.dhikrID),
                  let slotID = pending.key.slotID,
                  activeCountSlotID(for: goal) == slotID else {
                return
            }
            startAudioCounting(goal: goal, dhikr: dhikr, slotID: slotID)
        case .resumeAudio:
            guard let goal = store.goal(id: goalID),
                  let slotID = pending.key.slotID,
                  activeCountSlotID(for: goal) == slotID,
                  services.audio.isCounting(goalID: goal.id) else {
                return
            }
            services.audio.play()
        }
    }

    private func hardBlockMessageKey(for reason: CountingHardBlockReason) -> LocalizedStringKey {
        switch reason {
        case .paused: "counting_hard_block_paused"
        case .completed: "counting_hard_block_completed"
        case .expired: "counting_hard_block_expired"
        case .durationEnded: "counting_hard_block_duration_ended"
        }
    }

    private func countingAvailabilityMessage(
        for reason: CountingAvailabilityReason,
        key: CountingAvailabilityConfirmationKey
    ) -> String {
        switch reason {
        case .futureStart:
            return AwradLocalizer.format(
                "counting_availability_future_start",
                language: language,
                goal?.startDate ?? ""
            )
        case .offRecurrence:
            return AwradLocalizer.localized("counting_availability_off_recurrence", language: language)
        case .slotUpcoming, .slotEnded:
            guard let goal,
                  let slotID = key.slotID,
                  let slot = goal.activeSlots.first(where: { $0.id == slotID }) else {
                return AwradLocalizer.localized(
                    reason == .slotUpcoming
                        ? "counting_availability_slot_upcoming_unknown"
                        : "counting_availability_slot_ended_unknown",
                    language: language
                )
            }
            let timing = SlotStatusCalculator.timing(
                for: slot,
                occurrenceDateKey: key.effectiveDateKey,
                preferences: store.preferences,
                prayerTimeService: services.prayerTimes
            )
            let date = reason == .slotUpcoming ? timing.startsAt : timing.endsAt
            guard let date else {
                return AwradLocalizer.localized(
                    reason == .slotUpcoming
                        ? "counting_availability_slot_upcoming_unknown"
                        : "counting_availability_slot_ended_unknown",
                    language: language
                )
            }
            return AwradLocalizer.format(
                reason == .slotUpcoming
                    ? "counting_availability_slot_upcoming"
                    : "counting_availability_slot_ended",
                language: language,
                AwradLocalizer.formattedTime(date, language: language)
            )
        case .slotTimingUnavailable:
            return AwradLocalizer.localized("counting_availability_slot_unknown", language: language)
        }
    }

    private var coachSteps: [CountingCoachStep] {
        guard goal != nil else { return [] }
        return [
            CountingCoachStep(
                id: "tap",
                titleKey: "coach_tap_title",
                bodyKey: "coach_tap_body",
                symbol: "hand.tap.fill",
                targetID: "tap",
                circle: true,
                gate: .taps(required: 3)
            )
        ]
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
        guard goal.activeSlots.count > 1, !goal.isCompleted else { return false }
        let slotComplete = store.remaining(for: goal, slotID: activeCountSlotID(for: goal)) == 0
            && goal.targetPolicy != .none
        guard slotComplete else { return false }
        return goal.activeSlots.contains { slot in
            store.remaining(for: goal, slotID: slot.id) > 0
        }
    }

    private func selectNextIncompleteSlot(for goal: Goal) {
        let next = goal.activeSlots
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

    private func displayedCount(for goal: Goal) -> Int64 {
        guard goal.activeSlots.count > 1 else { return store.count(for: goal) }
        return store.count(for: goal, slotID: selectedSlotID)
    }

    private func displayedProgress(for goal: Goal) -> Double {
        guard goal.activeSlots.count > 1 else { return store.progress(for: goal) }
        let target = selectedSlotTarget(for: goal)
        guard target > 0 else { return 0 }
        return min(Double(displayedCount(for: goal)) / Double(target), 1)
    }

    private func counterSubtitle(for goal: Goal) -> String {
        guard goal.targetPolicy != .none else {
            return AwradLocalizer.localized("Open-ended count", language: language)
        }

        let remaining = store.remaining(for: goal, slotID: goal.activeSlots.count > 1 ? selectedSlotID : nil)
        if goal.activeSlots.count > 1,
           let slot = goal.activeSlots.first(where: { $0.id == selectedSlotID }) {
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

    private func adjustmentTarget(for goal: Goal) -> Int64? {
        goal.targetPolicy == .none ? nil : Int64(selectedSlotTarget(for: goal))
    }

    private func slotCards(for goal: Goal) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 146), spacing: 12)], spacing: 12) {
            ForEach(goal.activeSlots) { slot in
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
                            Button {
                                activeSheet = .playbackSpeed
                            } label: {
                                HStack {
                                    Label("Speed", systemImage: "speedometer")
                                    Spacer()
                                    Text(formatPlaybackSpeed(services.audio.playbackRate))
                                        .monospacedDigit()
                                    Image(systemName: "chevron.up")
                                        .font(AwradTheme.bodyFont(.caption2, weight: .bold))
                                }
                                .font(AwradTheme.bodyFont(.caption, weight: .semibold))
                                .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(Text("Playback Speed"))
                            .accessibilityValue(Text(formatPlaybackSpeed(services.audio.playbackRate)))
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
        guard !services.audio.isCounting(goalID: goal.id) else { return false }
        return !countButtonEnabled(for: goal)
    }

    private func toggleAudioCounting(goal: Goal, dhikr: Dhikr) {
        if services.audio.isCounting(goalID: goal.id) {
            if services.audio.isPlaying {
                services.audio.pause()
            } else if let slotID = activeCountSlotID(for: goal),
                      authorizeCountingAvailability(.resumeAudio, goal: goal, slotID: slotID) {
                services.audio.play()
            }
            return
        }
        startAudioCountingIfAllowed(goal: goal, dhikr: dhikr)
    }

    private func startAudioCountingIfAllowed(goal: Goal, dhikr: Dhikr) {
        guard let slotID = activeCountSlotID(for: goal),
              authorizeCountingAvailability(.startAudio, goal: goal, slotID: slotID) else {
            return
        }
        startAudioCounting(goal: goal, dhikr: dhikr, slotID: slotID)
    }

    private func startAudioCounting(goal: Goal, dhikr: Dhikr, slotID: AwradID) {
        let goalID = goal.id
        services.audio.startCounting(for: dhikr, goalID: goalID, title: dhikr.displayTitle(language: language)) { [store] in
            guard let currentGoal = store.goal(id: goalID),
                  authorizeCountingAvailability(.startAudio, goal: currentGoal, slotID: slotID) else {
                return false
            }
            let actualDelta = store.addCount(goalID: goalID, slotID: slotID, amount: Int64(dhikr.audioCountPerPlay))
            guard let updatedGoal = store.goal(id: goalID) else {
                return false
            }
            return AudioCountingLoopPolicy.shouldContinue(
                appliedDelta: actualDelta,
                goal: updatedGoal,
                slotID: slotID,
                store: store
            )
        }
    }

    private func enforceAudioTiming(at now: Date) {
        guard services.audio.isCounting(goalID: goalID),
              services.audio.isPlaying,
              let goal = store.goal(id: goalID),
              let slotID = activeCountSlotID(for: goal),
              !authorizeCountingAvailability(.resumeAudio, goal: goal, slotID: slotID, now: now) else {
            return
        }
        services.audio.pause()
    }

    private func stopAudioIfTargetReached() {
        guard let goal = store.goal(id: goalID),
              services.audio.isCounting(goalID: goalID),
              !countButtonEnabled(for: goal) else {
            return
        }
        services.audio.stop()
    }

    private func activeCountSlotID(for goal: Goal?) -> AwradID? {
        guard let goal else { return nil }
        return selectedSlotID ?? goal.activeSlots.sorted { $0.sortOrder < $1.sortOrder }.first?.id
    }

    private func sessionProgress(for goal: Goal) -> Int64 {
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
        let remaining = store.remaining(for: goal, slotID: goal.activeSlots.count > 1 ? selectedSlotID : nil)
        if goal.targetPolicy != .none, remaining > 0 {
            return Int(min(max(remaining, 1), 100))
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

    private func evaluateCountSession() {
        guard sessionType == .count,
              let target = sessionTarget,
              let goal,
              sessionProgress(for: goal) >= Int64(target) else { return }
        completeSession(type: .count, target: target, goal: goal)
    }

    private func completeSession(type: SessionTargetType, target: Int, goal: Goal) {
        completedSessionType = type
        completedSessionTarget = max(target, 1)
        sessionTarget = nil
        sessionTimerEnd = nil
        sessionType = .count
        sessionStartCount = displayedCount(for: goal)
        services.audio.stop()
        showSessionCompletionDialog = true
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

    private func adjustTextScale(increasing: Bool) {
        store.updatePreferences { preferences in
            preferences.countingDhikrTextScale = steppedDisplayValue(
                preferences.countingDhikrTextScale,
                values: countingDhikrTextScales,
                increasing: increasing
            )
        }
    }

    private func adjustLineSpacing(increasing: Bool) {
        store.updatePreferences { preferences in
            preferences.countingDhikrLineSpacing = steppedDisplayValue(
                preferences.countingDhikrLineSpacing,
                values: countingDhikrLineSpacings,
                increasing: increasing
            )
        }
    }
}

private struct CountingTopChrome: View {
    let title: String
    let goalTag: String
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
        .frame(height: 64)
        .background(.thinMaterial)
    }

    private var chromeContent: some View {
        HStack(spacing: 8) {
            chromeIconButton(symbol: "chevron.left", action: onBack, accessibilityLabel: "Back")

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(AwradTheme.displayFont(17, weight: .semibold))
                    .foregroundStyle(AwradTheme.ink)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Text(goalTag)
                    .font(AwradTheme.bodyFont(.caption2, weight: .medium))
                    .foregroundStyle(AwradTheme.sage)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(AwradTheme.mint.opacity(0.42), in: Capsule())
            }
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
    let milestoneText: String?
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

            if let milestoneText {
                Text(milestoneText)
                    .font(AwradTheme.bodyFont(.subheadline, weight: .semibold))
                    .foregroundStyle(AwradTheme.sageDark)
                    .multilineTextAlignment(.center)
            }

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
    let textScale: Double
    let onShowFull: () -> Void
    let onAdjustText: () -> Void

    private var shouldShowFullButton: Bool {
        arabic.count > 78 || arabic.contains("\n")
    }

    var body: some View {
        VStack(spacing: 4) {
            Text(arabic)
                .font(AwradTheme.arabicFont(25 * CGFloat(textScale), weight: .semibold))
                .foregroundStyle(AwradTheme.ink)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.72)
                .lineSpacing(0)
                .frame(maxWidth: .infinity, minHeight: shouldShowFullButton ? 74 : 70)
                .padding(.horizontal, 16)
                .environment(\.layoutDirection, .rightToLeft)

            HStack(spacing: 4) {
                if shouldShowFullButton {
                    Button(action: onShowFull) {
                        Text("See full")
                            .font(AwradTheme.bodyFont(.footnote, weight: .semibold))
                            .foregroundStyle(AwradTheme.sage)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                }

                Button(action: onAdjustText) {
                    Text("Aa")
                        .font(AwradTheme.bodyFont(.footnote, weight: .bold))
                        .foregroundStyle(AwradTheme.sageDark)
                        .frame(width: 32, height: 32)
                        .background(AwradTheme.mint.opacity(0.55), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Adjust text size"))
            }
        }
        .padding(.vertical, shouldShowFullButton ? 8 : 7)
        .background(AwradTheme.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
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
    let isPlaying: Bool
    let progress: Double
    let elapsedText: String
    let durationText: String
    let playbackRate: Double
    let onTogglePlayback: () -> Void
    let onShowPlaybackSpeed: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onTogglePlayback) {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(AwradTheme.bodyFont(.headline, weight: .bold))
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .background(AwradTheme.sage, in: Circle())
            .accessibilityLabel(Text(isPlaying ? "Pause audio counting" : "Resume audio counting"))

            VStack(spacing: 5) {
                ProgressView(value: progress)
                    .tint(AwradTheme.sage)

                HStack {
                    Text(elapsedText)
                    Spacer()
                    Text(durationText)
                }
                .font(AwradTheme.bodyFont(.caption2).monospacedDigit())
                .foregroundStyle(AwradTheme.subdued)
            }
            .frame(maxWidth: .infinity)

            Button(action: onShowPlaybackSpeed) {
                Text(formatPlaybackSpeed(playbackRate))
                    .font(AwradTheme.bodyFont(.subheadline, weight: .semibold).monospacedDigit())
                    .foregroundStyle(AwradTheme.sageDark)
                    .frame(minWidth: 44, minHeight: 44)
                    .background(AwradTheme.mint.opacity(0.52), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Playback Speed"))
            .accessibilityValue(Text(formatPlaybackSpeed(playbackRate)))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(AwradTheme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct PlaybackSpeedSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var playbackRate: Double

    private let minimumRate = 0.75
    private let maximumRate = 3.0
    private let rateStep = 0.05
    private let presets = [0.75, 1.0, 1.25, 1.5, 1.75, 2.0]

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Text("Playback Speed")
                    .font(AwradTheme.bodyFont(.headline, weight: .semibold))
                Spacer()
                Button("Done") { dismiss() }
                    .font(AwradTheme.bodyFont(.body, weight: .semibold))
                    .foregroundStyle(AwradTheme.sageDark)
            }
            .padding(.horizontal, 20)

            Text(formatPlaybackSpeed(playbackRate))
                .font(AwradTheme.bodyFont(38, weight: .bold).monospacedDigit())
                .foregroundStyle(AwradTheme.sageDark)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(presets, id: \.self) { preset in
                        let isSelected = speedsMatch(playbackRate, preset)
                        Button {
                            playbackRate = preset
                        } label: {
                            Text(formatPlaybackSpeed(preset))
                                .font(AwradTheme.bodyFont(.subheadline, weight: .semibold).monospacedDigit())
                                .foregroundStyle(isSelected ? .white : AwradTheme.sageDark)
                                .padding(.horizontal, 14)
                                .frame(minHeight: 40)
                                .background(
                                    isSelected ? AwradTheme.sage : AwradTheme.mint.opacity(0.52),
                                    in: Capsule()
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(isSelected ? .isSelected : [])
                    }
                }
                .padding(.horizontal, 20)
            }

            HStack(spacing: 12) {
                speedAdjustmentButton(
                    symbol: "minus",
                    accessibilityLabel: "Decrease playback speed",
                    adjustment: -rateStep,
                    disabled: playbackRate <= minimumRate
                )

                Slider(
                    value: $playbackRate,
                    in: minimumRate...maximumRate,
                    step: rateStep
                )
                .tint(AwradTheme.sage)
                .accessibilityLabel(Text("Playback Speed"))
                .accessibilityValue(Text(formatPlaybackSpeed(playbackRate)))

                speedAdjustmentButton(
                    symbol: "plus",
                    accessibilityLabel: "Increase playback speed",
                    adjustment: rateStep,
                    disabled: playbackRate >= maximumRate
                )
            }
            .padding(.horizontal, 20)

            HStack {
                Text(formatPlaybackSpeed(minimumRate))
                Spacer()
                Text(formatPlaybackSpeed(maximumRate))
            }
            .font(AwradTheme.bodyFont(.caption).monospacedDigit())
            .foregroundStyle(AwradTheme.subdued)
            .padding(.horizontal, 68)
        }
        .padding(.top, 28)
        .padding(.bottom, 20)
    }

    private func speedAdjustmentButton(
        symbol: String,
        accessibilityLabel: LocalizedStringKey,
        adjustment: Double,
        disabled: Bool
    ) -> some View {
        Button {
            playbackRate = steppedRate(playbackRate + adjustment)
        } label: {
            Image(systemName: symbol)
                .font(AwradTheme.bodyFont(.headline, weight: .bold))
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.circle)
        .tint(AwradTheme.sage)
        .disabled(disabled)
        .accessibilityLabel(Text(accessibilityLabel))
    }

    private func steppedRate(_ value: Double) -> Double {
        let clamped = min(max(value, minimumRate), maximumRate)
        return (clamped / rateStep).rounded() * rateStep
    }

    private func speedsMatch(_ lhs: Double, _ rhs: Double) -> Bool {
        abs(lhs - rhs) < 0.001
    }
}

private func formatPlaybackSpeed(_ speed: Double) -> String {
    let hundredths = Int((speed * 100).rounded())
    switch hundredths {
    case let value where value.isMultiple(of: 100):
        return "\(value / 100)×"
    case let value where value.isMultiple(of: 10):
        return String(format: "%.1f×", speed)
    default:
        return String(format: "%.2f×", speed)
    }
}

private struct FullDhikrSheet: View {
    let arabic: String
    let textScale: Double
    let lineSpacing: Double
    let canCount: Bool
    let currentCount: Int64
    let targetCount: Int64?
    let onDecreaseTextSize: () -> Void
    let onIncreaseTextSize: () -> Void
    let onDecreaseLineSpacing: () -> Void
    let onIncreaseLineSpacing: () -> Void
    let onCount: () -> Void
    @State private var showsDisplayControls = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button {
                    withAnimation(.snappy) { showsDisplayControls.toggle() }
                } label: {
                    Text("Aa")
                        .font(AwradTheme.bodyFont(.subheadline, weight: .bold))
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.roundedRectangle(radius: 14))
                .tint(AwradTheme.sage)
                .accessibilityLabel(Text("Adjust text size"))
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)

            if showsDisplayControls {
                DhikrDisplayControls(
                    textScale: textScale,
                    lineSpacing: lineSpacing,
                    onDecreaseTextSize: onDecreaseTextSize,
                    onIncreaseTextSize: onIncreaseTextSize,
                    onDecreaseLineSpacing: onDecreaseLineSpacing,
                    onIncreaseLineSpacing: onIncreaseLineSpacing
                )
                .padding(.horizontal, 18)
                .padding(.bottom, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            ScrollView {
                Text(arabic)
                    .font(AwradTheme.arabicFont(32 * CGFloat(textScale), weight: .semibold))
                    .foregroundStyle(AwradTheme.ink)
                    .multilineTextAlignment(.center)
                    .lineSpacing(12 * CGFloat(lineSpacing))
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
                    Text(countButtonText)
                        .font(AwradTheme.bodyFont(.headline, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 64)
                }
                .buttonStyle(.plain)
                .modifier(GlassControlModifier(cornerRadius: 16, tint: AwradTheme.sage))
                .disabled(!canCount)
                .opacity(canCount ? 1 : 0.48)

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

    private var countButtonText: String {
        guard let targetCount else { return currentCount.formatted() }
        return "\(currentCount.formatted()) / \(targetCount.formatted())"
    }
}

private struct DhikrDisplaySettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    let arabic: String
    let textScale: Double
    let lineSpacing: Double
    let onDecreaseTextSize: () -> Void
    let onIncreaseTextSize: () -> Void
    let onDecreaseLineSpacing: () -> Void
    let onIncreaseLineSpacing: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Adjust the Dhikr text size and line spacing. Your choice is saved for every counter.")
                    .font(AwradTheme.bodyFont(.subheadline))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                ScrollView {
                    Text(arabic)
                        .font(AwradTheme.arabicFont(28 * CGFloat(textScale), weight: .semibold))
                        .multilineTextAlignment(.center)
                        .lineSpacing(10 * CGFloat(lineSpacing))
                        .frame(maxWidth: .infinity)
                        .padding(20)
                        .environment(\.layoutDirection, .rightToLeft)
                }
                .frame(maxHeight: 180)
                .background(AwradTheme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))

                DhikrDisplayControls(
                    textScale: textScale,
                    lineSpacing: lineSpacing,
                    onDecreaseTextSize: onDecreaseTextSize,
                    onIncreaseTextSize: onIncreaseTextSize,
                    onDecreaseLineSpacing: onDecreaseLineSpacing,
                    onIncreaseLineSpacing: onIncreaseLineSpacing
                )

                Spacer(minLength: 0)
            }
            .padding(20)
            .background(AwradTheme.background)
            .navigationTitle("Text display")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

private struct DhikrDisplayControls: View {
    let textScale: Double
    let lineSpacing: Double
    let onDecreaseTextSize: () -> Void
    let onIncreaseTextSize: () -> Void
    let onDecreaseLineSpacing: () -> Void
    let onIncreaseLineSpacing: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            controlRow(
                title: "Text size",
                value: textScale,
                lowerBound: countingDhikrTextScales.first ?? 0.85,
                upperBound: countingDhikrTextScales.last ?? 1.3,
                decreaseLabel: "Decrease text size",
                increaseLabel: "Increase text size",
                onDecrease: onDecreaseTextSize,
                onIncrease: onIncreaseTextSize
            )
            Divider()
            controlRow(
                title: "Line spacing",
                value: lineSpacing,
                lowerBound: countingDhikrLineSpacings.first ?? 0.9,
                upperBound: countingDhikrLineSpacings.last ?? 1.3,
                decreaseLabel: "Decrease line spacing",
                increaseLabel: "Increase line spacing",
                onDecrease: onDecreaseLineSpacing,
                onIncrease: onIncreaseLineSpacing
            )
        }
        .padding(.horizontal, 14)
        .background(AwradTheme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(AwradTheme.sage.opacity(0.16), lineWidth: 1)
        )
    }

    private func controlRow(
        title: LocalizedStringKey,
        value: Double,
        lowerBound: Double,
        upperBound: Double,
        decreaseLabel: LocalizedStringKey,
        increaseLabel: LocalizedStringKey,
        onDecrease: @escaping () -> Void,
        onIncrease: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AwradTheme.bodyFont(.subheadline, weight: .semibold))
                Text("\(Int((value * 100).rounded()))%")
                    .font(AwradTheme.bodyFont(.caption).monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(action: onDecrease) {
                Image(systemName: "minus")
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.circle)
            .disabled(value <= lowerBound + 0.01)
            .accessibilityLabel(Text(decreaseLabel))

            Button(action: onIncrease) {
                Image(systemName: "plus")
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.circle)
            .disabled(value >= upperBound - 0.01)
            .accessibilityLabel(Text(increaseLabel))
        }
        .frame(minHeight: 62)
        .tint(AwradTheme.sage)
    }
}

private let countingDhikrTextScales: [Double] = [0.85, 1, 1.15, 1.3]
private let countingDhikrLineSpacings: [Double] = [0.9, 1, 1.15, 1.3]

private func steppedDisplayValue(_ current: Double, values: [Double], increasing: Bool) -> Double {
    if increasing {
        return values.first(where: { $0 > current + 0.01 }) ?? values.last ?? current
    }
    return values.last(where: { $0 < current - 0.01 }) ?? values.first ?? current
}

private struct CountingSyncFeedbackState: Equatable {
    let eventID: UUID
    let delta: Int64
}

private struct CountingHintOrSyncAlert: View {
    let feedback: CountingSyncFeedbackState?
    let language: AppLanguage

    private var message: String? {
        guard let feedback else { return nil }
        let amount = abs(feedback.delta).formatted(
            .number.locale(Locale(identifier: language.localeIdentifier))
        )
        return AwradLocalizer.format(
            feedback.delta > 0 ? "counting_sync_added" : "counting_sync_adjusted",
            language: language,
            amount
        )
    }

    var body: some View {
        ZStack {
            if let message {
                Label {
                    Text(message)
                        .lineLimit(2)
                } icon: {
                    Image(systemName: "icloud.and.arrow.down.fill")
                }
                .font(AwradTheme.bodyFont(.caption, weight: .semibold))
                .foregroundStyle(AwradTheme.ink)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    AwradTheme.gold.opacity(0.12),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(AwradTheme.gold.opacity(0.48), lineWidth: 1)
                }
                .transition(.opacity.combined(with: .scale(scale: 0.97)))
                .accessibilityLabel(Text(message))
            } else {
                Text(AwradLocalizer.localized("counting_tap_circle_to_count", language: language))
                    .font(AwradTheme.bodyFont(.subheadline))
                    .foregroundStyle(.secondary)
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 40)
        .animation(.easeInOut(duration: 0.2), value: feedback)
    }
}

private struct CountCircleButton: View {
    let isEnabled: Bool
    let primaryProgress: Double?
    let minimumSegmentProgress: Double?
    let remainingSegmentProgress: Double?
    let minimumCheckpoint: Double?
    let showsTargetReachedAlert: Bool
    let countText: String
    let targetText: String?
    let onCount: () -> Void
    let onKeepCounting: () -> Void

    var body: some View {
        GeometryReader { proxy in
            let buttonSize = max(0, min(proxy.size.width, proxy.size.height))
            ZStack {
                if let primaryProgress {
                    Circle()
                        .stroke(AwradTheme.mint.opacity(0.42), lineWidth: 9)

                    if let minimumSegmentProgress,
                       let remainingSegmentProgress,
                       let minimumCheckpoint {
                        Circle()
                            .trim(from: 0, to: min(max(minimumSegmentProgress, 0), 1))
                            .stroke(AwradTheme.gold, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .animation(.easeOut(duration: 0.24), value: minimumSegmentProgress)

                        let remainingStart = min(max(minimumCheckpoint, 0), 1)
                        let remainingEnd = min(
                            max(minimumCheckpoint + remainingSegmentProgress, remainingStart),
                            1
                        )
                        if remainingEnd > remainingStart {
                            Circle()
                                .trim(from: remainingStart, to: remainingEnd)
                                .stroke(AwradTheme.sage, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                                .rotationEffect(.degrees(-90))
                                .animation(.easeOut(duration: 0.24), value: remainingSegmentProgress)
                        }
                    } else {
                        Circle()
                            .trim(from: 0, to: min(max(primaryProgress, 0), 1))
                            .stroke(AwradTheme.gold, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .animation(.easeOut(duration: 0.24), value: primaryProgress)
                    }
                }

                if showsTargetReachedAlert {
                    TargetReachedCircleMessage(onKeepCounting: onKeepCounting)
                        .frame(width: max(buttonSize - 44, 0))
                } else {
                    Button(action: onCount) {
                        VStack(spacing: 2) {
                            Text(countText)
                                .font(AwradTheme.bodyFont(64, weight: .bold))
                                .monospacedDigit()
                            if let targetText {
                                Text(targetText)
                                    .font(AwradTheme.bodyFont(28, weight: .semibold))
                                    .monospacedDigit()
                            }
                        }
                        .foregroundStyle(AwradTheme.ink)
                        .frame(
                            width: max(buttonSize - 26, 0),
                            height: max(buttonSize - 26, 0)
                        )
                        .modifier(GlassCircleControlModifier(tint: AwradTheme.mint.opacity(0.72)))
                        .opacity(isEnabled ? 1 : 0.45)
                        .coachAnchor("tap")
                    }
                    .buttonStyle(.plain)
                    .disabled(!isEnabled)
                    .accessibilityLabel(Text("Count"))
                    .accessibilityValue(Text(targetText.map { "\(countText) \($0)" } ?? countText))
                }
            }
            .frame(width: buttonSize, height: buttonSize)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.bottom, 8)
    }
}

private struct TargetReachedCircleMessage: View {
    let onKeepCounting: () -> Void

    var body: some View {
        VStack(spacing: 4) {
            Text("Target reached")
                .font(AwradTheme.bodyFont(.headline, weight: .semibold))
                .multilineTextAlignment(.center)
            Text("Counting is paused because this goal stops at its target.")
                .font(AwradTheme.bodyFont(.caption))
                .foregroundStyle(AwradTheme.ink.opacity(0.78))
                .multilineTextAlignment(.center)
                .lineLimit(3)
            Button("Keep counting", action: onKeepCounting)
                .font(AwradTheme.bodyFont(.subheadline, weight: .semibold))
                .buttonStyle(.plain)
                .foregroundStyle(AwradTheme.sage)
                .padding(.vertical, 4)
        }
    }
}

private struct GlassSurfaceModifier: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    let cornerRadius: CGFloat
    let tint: Color

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        content
            .background(reduceTransparency ? AnyShapeStyle(AwradTheme.surface) : AnyShapeStyle(.ultraThinMaterial), in: shape)
            .overlay(shape.stroke(AwradTheme.sage.opacity(0.18), lineWidth: 1))
    }
}

private struct GlassControlModifier: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    let cornerRadius: CGFloat
    var tint: Color = AwradTheme.mint.opacity(0.50)

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        if #available(iOS 26.0, *), !reduceTransparency {
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
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    let tint: Color

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *), !reduceTransparency {
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
                    AwradSegmentedControl(
                        selection: $type,
                        options: [SessionTargetType.count, .timer]
                    ) { option in
                        Text(LocalizedStringKey(
                            option == .count ? "counting_session_count_tab" : "counting_session_timer_tab"
                        ))
                    }
                    .onChange(of: type) { _, newValue in
                        target = newValue == .timer ? 10 : 33
                    }
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

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

    let currentCount: Int64
    let targetCount: Int64?
    let language: AppLanguage
    let onApply: () -> Void

    @State private var showSubtractWarning = false

    private var effectiveAmount: Int {
        max(amount, 1)
    }

    private var afterAdjustment: Int64 {
        switch mode {
        case .add:
            guard let targetCount else {
                return currentCount + Int64(effectiveAmount)
            }
            return min(currentCount + Int64(effectiveAmount), targetCount)
        case .subtract:
            return max(currentCount - Int64(effectiveAmount), 0)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Adjustment") {
                    AwradSegmentedControl(
                        selection: $mode,
                        options: CountAdjustmentMode.allCases
                    ) { option in
                        Text(option.titleKey)
                    }

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
        goal.slots.first { $0.id == entry.slotID }?.displayLabel(language: language)
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
