import SwiftUI
import UIKit

/// Full Quran reading surface. It is read-only when entered from Library and keeps an optional
/// goal/slot identity when entered from Counting, matching Android's destination contract.
struct QuranDhikrReaderView: View {
    @Environment(AwradStore.self) private var store
    @Environment(AppServices.self) private var services
    let dhikrID: AwradID
    let goalID: AwradID?
    let initialSlotID: AwradID?

    @State private var countAlertMessage: String?
    @State private var pendingCountingConfirmation: CountingAvailabilityConfirmationKey?
    @State private var feedbackTrigger = 0

    init(
        dhikrID: AwradID,
        goalID: AwradID? = nil,
        initialSlotID: AwradID? = nil
    ) {
        self.dhikrID = dhikrID
        self.goalID = goalID
        self.initialSlotID = initialSlotID
    }

    var body: some View {
        Group {
            if let dhikr = store.dhikr(id: dhikrID) {
                reader(for: dhikr)
            } else {
                EmptyStateView(
                    symbol: "exclamationmark.triangle",
                    title: "Not Found",
                    message: "This dhikr is no longer available."
                )
                .padding(20)
            }
        }
        .background(AwradTheme.background)
        .navigationTitle(store.dhikr(id: dhikrID)?.displayTitle(language: store.preferences.appLanguage) ?? "Quran Reader")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if let context = countingContext {
                countingBar(goal: context.goal, slot: context.slot)
            }
        }
        .alert(
            Text(AwradLocalizer.localized(
                pendingCountingConfirmation == nil ? "Counting" : "counting_availability_title",
                language: store.preferences.appLanguage
            )),
            isPresented: countAlertBinding
        ) {
            if pendingCountingConfirmation != nil {
                Button(AwradLocalizer.localized("counting_availability_count_anyway", language: store.preferences.appLanguage)) {
                    confirmPendingCount()
                }
                Button("Cancel", role: .cancel) {
                    clearCountAlert()
                }
            } else {
                Button("OK") { clearCountAlert() }
            }
        } message: {
            Text(countAlertMessage ?? "")
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: feedbackTrigger)
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = store.preferences.keepScreenOn
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }

    private func reader(for dhikr: Dhikr) -> some View {
        let splitText = QuranDhikrReadingPolicy.splitBismillah(dhikr.arabic)
        return ScrollView {
            VStack(spacing: 24) {
                readingControls

                if let bismillah = splitText.bismillah {
                    Text(bismillah)
                        .font(AwradTheme.arabicFont(CGFloat(24 * textScale)))
                        .multilineTextAlignment(.center)
                        .lineSpacing(CGFloat(10 * lineSpacing))
                        .frame(maxWidth: .infinity)
                        .environment(\.layoutDirection, .rightToLeft)
                }

                Text(splitText.body)
                    .font(AwradTheme.arabicFont(CGFloat(29 * textScale)))
                    .multilineTextAlignment(.center)
                    .lineSpacing(CGFloat(15 * lineSpacing))
                    .frame(maxWidth: .infinity)
                    .environment(\.layoutDirection, .rightToLeft)
                    .accessibilityLabel(splitText.body)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            .padding(.bottom, countingContext == nil ? 36 : 12)
        }
    }

    private var readingControls: some View {
        VStack(spacing: 10) {
            stepperRow(
                title: "Text size",
                decreaseLabel: "Decrease text size",
                increaseLabel: "Increase text size",
                onDecrease: {
                    updateTextScale(QuranDhikrReadingPolicy.previousStep(
                        before: textScale,
                        in: QuranDhikrReadingPolicy.textScales
                    ))
                },
                onIncrease: {
                    updateTextScale(QuranDhikrReadingPolicy.nextStep(
                        after: textScale,
                        in: QuranDhikrReadingPolicy.textScales
                    ))
                }
            )
            stepperRow(
                title: "Line spacing",
                decreaseLabel: "Decrease line spacing",
                increaseLabel: "Increase line spacing",
                onDecrease: {
                    updateLineSpacing(QuranDhikrReadingPolicy.previousStep(
                        before: lineSpacing,
                        in: QuranDhikrReadingPolicy.lineSpacings
                    ))
                },
                onIncrease: {
                    updateLineSpacing(QuranDhikrReadingPolicy.nextStep(
                        after: lineSpacing,
                        in: QuranDhikrReadingPolicy.lineSpacings
                    ))
                }
            )
        }
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func stepperRow(
        title: LocalizedStringKey,
        decreaseLabel: LocalizedStringKey,
        increaseLabel: LocalizedStringKey,
        onDecrease: @escaping () -> Void,
        onIncrease: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 12) {
            Button(action: onDecrease) {
                Image(systemName: "minus")
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.bordered)
            .accessibilityLabel(decreaseLabel)

            Text(title)
                .font(AwradTheme.bodyFont(.subheadline, weight: .semibold))
                .frame(maxWidth: .infinity)

            Button(action: onIncrease) {
                Image(systemName: "plus")
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.bordered)
            .accessibilityLabel(increaseLabel)
        }
        .tint(AwradTheme.sage)
    }

    private var countingContext: (goal: Goal, slot: GoalSlot)? {
        guard let goalID,
              let goal = store.goal(id: goalID),
              goal.dhikrID == dhikrID else {
            return nil
        }
        let slots = goal.activeSlots.sorted { $0.sortOrder < $1.sortOrder }
        let slot = initialSlotID.flatMap { requestedID in
            slots.first { $0.id == requestedID }
        } ?? slots.first
        guard let slot else { return nil }
        return (goal, slot)
    }

    private var textScale: Double {
        store.preferences.countingDhikrTextScale
    }

    private var lineSpacing: Double {
        store.preferences.countingDhikrLineSpacing
    }

    private func updateTextScale(_ value: Double) {
        store.updatePreferences { $0.countingDhikrTextScale = value }
    }

    private func updateLineSpacing(_ value: Double) {
        store.updatePreferences { $0.countingDhikrLineSpacing = value }
    }

    private func countingBar(goal: Goal, slot: GoalSlot) -> some View {
        let count = store.count(for: goal, slotID: slot.id)
        let target = slot.targetCount
        return VStack(spacing: 8) {
            Text(target.map { "\(count) / \($0)" } ?? "\(count)")
                .font(AwradTheme.bodyFont(.subheadline, weight: .semibold).monospacedDigit())
                .foregroundStyle(.secondary)
            Button {
                countOnce(goalID: goal.id, slotID: slot.id)
            } label: {
                Text("COUNT")
                    .font(AwradTheme.bodyFont(.headline, weight: .bold))
                    .tracking(1.5)
                    .frame(maxWidth: .infinity, minHeight: 50)
            }
            .buttonStyle(.borderedProminent)
            .tint(AwradTheme.sage)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.regularMaterial)
    }

    private func countOnce(goalID: AwradID, slotID: AwradID) {
        guard let goal = store.goal(id: goalID),
              let slot = goal.activeSlots.first(where: { $0.id == slotID }) else {
            return
        }
        switch CountingAvailabilityCalculator.decision(
            for: goal,
            slot: slot,
            effectiveDateKey: store.todayKey,
            preferences: store.preferences,
            prayerTimeService: services.prayerTimes
        ) {
        case .allow:
            applyCount(goalID: goalID, slotID: slotID)
        case let .hardBlock(reason):
            countAlertMessage = AwradLocalizer.localized(
                hardBlockMessageKey(for: reason),
                language: store.preferences.appLanguage
            )
        case let .requiresConfirmation(reasons, key):
            if CountingAvailabilityConfirmationStore.isConfirmed(key) {
                applyCount(goalID: goalID, slotID: slotID)
            } else {
                pendingCountingConfirmation = key
                countAlertMessage = reasons
                    .sorted { $0.rawValue < $1.rawValue }
                    .map { "• \(availabilityMessage(for: $0, goal: goal, slot: slot))" }
                    .joined(separator: "\n")
            }
        }
    }

    private func confirmPendingCount() {
        guard let pending = pendingCountingConfirmation else { return }
        clearCountAlert()
        CountingAvailabilityConfirmationStore.confirm(pending)
        guard store.todayKey == pending.effectiveDateKey,
              let slotID = pending.slotID else { return }
        applyCount(goalID: pending.goalID, slotID: slotID)
    }

    private func applyCount(goalID: AwradID, slotID: AwradID) {
        let result = store.applyCount(goalID: goalID, slotID: slotID)
        if result.appliedDelta > 0, store.preferences.vibrateOnCount {
            feedbackTrigger &+= 1
        }
        switch result.capEvent {
        case .none:
            break
        case .warnedOverTarget:
            countAlertMessage = String(localized: "You reached the target. Counting can continue for this slot.")
        case .blocked:
            countAlertMessage = String(localized: "This slot has reached its maximum count.")
        }
    }

    private func clearCountAlert() {
        countAlertMessage = nil
        pendingCountingConfirmation = nil
    }

    private func hardBlockMessageKey(for reason: CountingHardBlockReason) -> String {
        switch reason {
        case .paused: "counting_hard_block_paused"
        case .completed: "counting_hard_block_completed"
        case .expired: "counting_hard_block_expired"
        case .durationEnded: "counting_hard_block_duration_ended"
        }
    }

    private func availabilityMessage(
        for reason: CountingAvailabilityReason,
        goal: Goal,
        slot: GoalSlot
    ) -> String {
        let language = store.preferences.appLanguage
        switch reason {
        case .futureStart:
            return AwradLocalizer.format(
                "counting_availability_future_start",
                language: language,
                goal.startDate
            )
        case .offRecurrence:
            return AwradLocalizer.localized("counting_availability_off_recurrence", language: language)
        case .slotUpcoming, .slotEnded:
            let timing = SlotStatusCalculator.timing(
                for: slot,
                occurrenceDateKey: store.todayKey,
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

    private var countAlertBinding: Binding<Bool> {
        Binding(
            get: { countAlertMessage != nil },
            set: { if !$0 { clearCountAlert() } }
        )
    }
}
