import Foundation

/// The active profile's practice policy, as Settings shows it.
public struct PracticeSettingsState: Hashable, Sendable {
    public var policy: PracticePolicy
    /// A merge after editing on two devices dropped this phone's Hijri corrections
    /// (`hijri_corrections_replaced`), until the user dismisses it.
    public var correctionsReplaced: Bool

    public init(policy: PracticePolicy = .default, correctionsReplaced: Bool = false) {
        self.policy = policy
        self.correctionsReplaced = correctionsReplaced
    }
}

/// Why a policy couldn't be saved.
public enum PracticeSettingsError: Error, Hashable, Sendable {
    /// The profile's database couldn't be written.
    case storage
}

/// Port: the active profile's practice policy (each local profile has its own, the anonymous one
/// included). Saving marks it chosen and, for a profile with an account, queues it for the change
/// queue; it works signed out and offline.
public protocol PracticeSettings: Sendable {
    func practiceSettings() async -> PracticeSettingsState
    /// The state now, then after every change (an edit, a sync, a profile switch).
    func practiceSettingsUpdates() -> AsyncStream<PracticeSettingsState>
    func savePolicy(_ policy: PracticePolicy) async throws(PracticeSettingsError)
    func dismissCorrectionsReplaced() async
}

/// The practice day at an instant, as Settings previews it.
public struct PracticeToday: Hashable, Sendable {
    /// The effective practice day (`EffectivePracticeDay`).
    public let day: CalendarDay
    /// Maghrib on the instant's local date; `nil` without a location, or where the sun doesn't set.
    public let maghrib: Date?
    /// The effective day's Hijri date with the policy's corrections; `nil` outside the table.
    public let hijri: HijriDate?

    /// The practice day at `instant` in `timeZone`, with Maghrib from `calculator` at `location`.
    /// The Maghrib reset without a Maghrib falls back to midnight.
    public init(
        at instant: Date, in timeZone: TimeZone, policy: PracticePolicy, location: DeviceLocation?,
        calculator: any MaghribCalculator
    ) {
        let localDay = CalendarDay(instant, in: timeZone)
        maghrib = location.flatMap {
            calculator.maghrib(
                on: localDay, latitude: $0.latitude, longitude: $0.longitude, method: policy.calculationMethod)
        }
        day = EffectivePracticeDay.resolve(at: instant, in: timeZone, dayReset: policy.dayReset, maghrib: maghrib)
        hijri = policy.hijriCorrections.calendar.date(of: day)
    }
}
