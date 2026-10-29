import Foundation

// The account practice policy (contracts/practice-settings/v1, root ADR-2026-10-29): how a user's
// practice is measured. It syncs as the `practice_policy` entity of the change queue; location
// stays on the device (`DeviceLocation`).

/// Prayer-time calculation method, by the adhan library's names. Only `dubai` and
/// `moonsightingCommittee` move Maghrib (3 minutes after sunset).
public enum CalculationMethod: String, CaseIterable, Hashable, Sendable {
    case karachi
    case northAmerica = "north_america"
    case muslimWorldLeague = "muslim_world_league"
    case egyptian
    case ummAlQura = "umm_al_qura"
    case moonsightingCommittee = "moonsighting_committee"
    case dubai, kuwait, qatar, singapore
}

/// The Asr shadow rule: Shafi'i (also Maliki and Hanbali, shadow length 1) or Hanafi (2). No
/// screen uses Asr before the prayer-times slice.
public enum Madhab: String, CaseIterable, Hashable, Sendable {
    case shafi, hanafi
}

/// One account's practice policy. Only valid policies exist: `hijriCorrections` is a valid set,
/// and decoding goes through `PracticePolicyValidation`.
public struct PracticePolicy: Hashable, Sendable {
    public var dayReset: DayReset
    public var calculationMethod: CalculationMethod
    public var madhab: Madhab
    public var weekStart: WeekStart
    public var hijriCorrections: HijriCorrections

    /// A new profile's policy, and the base a phone merges against when it knows no server copy:
    /// midnight, Karachi, Shafi'i, Monday, no corrections (the frozen defaults).
    public static let `default` = PracticePolicy(
        dayReset: .midnight, calculationMethod: .karachi, madhab: .shafi, weekStart: .monday, hijriCorrections: .none)

    public init(
        dayReset: DayReset, calculationMethod: CalculationMethod, madhab: Madhab, weekStart: WeekStart,
        hijriCorrections: HijriCorrections
    ) {
        self.dayReset = dayReset
        self.calculationMethod = calculationMethod
        self.madhab = madhab
        self.weekStart = weekStart
        self.hijriCorrections = hijriCorrections
    }
}

/// A `practice_policy` document that isn't valid: its `{field, code}` errors, sorted.
public struct PracticePolicyError: Error, Hashable, Sendable {
    public let errors: [SyncFieldError]
}

extension PracticePolicy {
    /// The policy of a wire document, or every reason it's invalid (`practice_policy_validity.json`).
    public init(json: AwradJSON) throws(PracticePolicyError) {
        let errors = PracticePolicyValidation.errors(in: json)
        guard errors.isEmpty, let members = json.objectValue,
            let dayReset = members["day_reset"]?.stringValue.flatMap(DayReset.init(rawValue:)),
            let method = members["calculation_method"]?.stringValue.flatMap(CalculationMethod.init(rawValue:)),
            let madhab = members["madhab"]?.stringValue.flatMap(Madhab.init(rawValue:)),
            let weekStart = members["week_start"]?.stringValue.flatMap(WeekStart.init(rawValue:)),
            let corrections = members["hijri_corrections"]?.arrayValue.map(PracticePolicyValidation.corrections),
            let valid = try? HijriCorrections(corrections)
        else {
            throw PracticePolicyError(errors: errors.isEmpty ? [SyncFieldError(field: "", code: "invalid")] : errors)
        }
        self.init(
            dayReset: dayReset, calculationMethod: method, madhab: madhab, weekStart: weekStart,
            hijriCorrections: valid)
    }

    /// The wire document; corrections sorted by year, then month, as clients write them.
    public var json: AwradJSON {
        .object([
            "day_reset": .string(dayReset.rawValue),
            "calculation_method": .string(calculationMethod.rawValue),
            "madhab": .string(madhab.rawValue),
            "week_start": .string(weekStart.rawValue),
            "hijri_corrections": .array(
                hijriCorrections.all.map { correction in
                    .object([
                        "year": .int(correction.year), "month": .int(correction.month),
                        "offset_days": .int(correction.offsetDays),
                    ])
                }),
        ])
    }
}
