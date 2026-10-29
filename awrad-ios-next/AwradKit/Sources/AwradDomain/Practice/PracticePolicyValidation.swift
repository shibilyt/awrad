import Foundation

// Rule: practice policy validity (contracts/practice-settings/v1/fixtures/practice_policy_validity.json).

/// The rules a `practice_policy` document must follow, on raw JSON, so every error can be named.
public enum PracticePolicyValidation {
    static let members = ["day_reset", "calculation_method", "madhab", "week_start", "hijri_corrections"]

    static let values: [String: Set<String>] = [
        "day_reset": Set(DayReset.allCases.map(\.rawValue)),
        "calculation_method": Set(CalculationMethod.allCases.map(\.rawValue)),
        "madhab": Set(Madhab.allCases.map(\.rawValue)),
        "week_start": Set(WeekStart.allCases.map(\.rawValue)),
    ]

    /// The `{field, code}` errors of a document, sorted by field, then code; empty when it's valid.
    ///
    /// | Problem | Error |
    /// |---|---|
    /// | A member missing | `required` on it |
    /// | An unknown member | `not_allowed` on it |
    /// | A value that isn't one of the member's (`null`, wrong case) | `invalid` on it |
    /// | `hijri_corrections` not a list | `invalid` on `/hijri_corrections` |
    /// | A correction that isn't exactly `{year, month, offset_days}` as integers in range | `invalid` on `/hijri_corrections/N` |
    /// | A month twice (only when every correction is well formed) | `duplicate` on each later one |
    /// | A month of neither 29 nor 30 days (only without duplicates) | `range` on `/hijri_corrections` |
    public static func errors(in json: AwradJSON) -> [SyncFieldError] {
        guard let document = json.objectValue else { return [SyncFieldError(field: "", code: "invalid")] }
        var errors: [SyncFieldError] = []
        for key in document.keys where !members.contains(key) {
            errors.append(SyncFieldError(field: "/\(key)", code: "not_allowed"))
        }
        for key in members {
            guard let value = document[key] else {
                errors.append(SyncFieldError(field: "/\(key)", code: "required"))
                continue
            }
            if let allowed = values[key], !(value.stringValue.map(allowed.contains) ?? false) {
                errors.append(SyncFieldError(field: "/\(key)", code: "invalid"))
            }
        }
        if let corrections = document["hijri_corrections"] {
            errors += correctionErrors(corrections)
        }
        return errors.sorted()
    }

    private static func correctionErrors(_ json: AwradJSON) -> [SyncFieldError] {
        guard let items = json.arrayValue else { return [SyncFieldError(field: "/hijri_corrections", code: "invalid")] }
        let malformed = items.indices.filter { wellFormed(items[$0]) == nil }
        guard malformed.isEmpty else {
            return malformed.map { SyncFieldError(field: "/hijri_corrections/\($0)", code: "invalid") }
        }
        var errors: [SyncFieldError] = []
        var seen: Set<[Int]> = []
        for (index, correction) in corrections(items).enumerated()
        where !seen.insert([correction.year, correction.month]).inserted {
            errors.append(SyncFieldError(field: "/hijri_corrections/\(index)", code: "duplicate"))
        }
        if errors.isEmpty, (try? HijriCorrections(corrections(items))) == nil {
            errors.append(SyncFieldError(field: "/hijri_corrections", code: "range"))
        }
        return errors
    }

    /// The corrections of a list whose items are all well formed (others are skipped).
    static func corrections(_ items: [AwradJSON]) -> [HijriCorrection] {
        items.compactMap(wellFormed)
    }

    /// A correction that is exactly `{year, month, offset_days}` as integers, the month in the table
    /// and the offset at most two days.
    private static func wellFormed(_ json: AwradJSON) -> HijriCorrection? {
        guard let members = json.objectValue, Set(members.keys) == ["year", "month", "offset_days"],
            let year = members["year"]?.intValue, let month = members["month"]?.intValue,
            let offset = members["offset_days"]?.intValue,
            (UmmAlQuraTable.firstYear...UmmAlQuraTable.lastYear).contains(year), (1...12).contains(month),
            abs(offset) <= HijriCorrections.maximumOffset
        else { return nil }
        return HijriCorrection(year: year, month: month, offsetDays: offset)
    }
}
