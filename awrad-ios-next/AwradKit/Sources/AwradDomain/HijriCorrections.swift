import Foundation

// Rule: Hijri corrections validity (contracts/hijri-calendar/v1/fixtures/hijri_corrections_validity.json).

/// A moon-sighting correction: moves the start of Hijri `year`/`month`, and every later month's
/// until the next correction, by `offsetDays` from the table (positive = later).
public struct HijriCorrection: Hashable, Sendable {
    public var year: Int
    public var month: Int
    public var offsetDays: Int

    public init(year: Int, month: Int, offsetDays: Int) {
        self.year = year
        self.month = month
        self.offsetDays = offsetDays
    }
}

/// Why a set of corrections can't be used. `HijriCorrections.init` throws it.
public struct HijriCorrectionsValidationError: Error, Hashable, Sendable {
    /// One reason a set is invalid. The raw value is the contract's error code.
    public enum Code: String, CaseIterable, Hashable, Sendable {
        /// Two corrections for the same month.
        case duplicateMonth = "duplicate_month"
        /// An adjusted month would have fewer than 29 or more than 30 days. Checked only when
        /// every other check passes.
        case monthLengthInvalid = "month_length_invalid"
        /// The month is outside the table (1400–1500 AH) or not 1–12.
        case monthOutOfRange = "month_out_of_range"
        /// More than 2 days from the table.
        case offsetOutOfRange = "offset_out_of_range"
    }

    /// Every reason, without duplicates, sorted alphabetically by code. Never empty.
    public let codes: [Code]

    init(_ codes: Set<Code>) {
        self.codes = codes.sorted { $0.rawValue < $1.rawValue }
    }
}

/// A valid set of month-start corrections: the account's moon-sighting adjustments (root
/// ADR-2026-10-26). Only valid sets exist, so every rule can trust `calendar`. Order doesn't matter.
public struct HijriCorrections: Hashable, Sendable {
    /// No corrections: the table as it is.
    public static let none = HijriCorrections(validated: [:])

    /// The corrections, in calendar order.
    public let all: [HijriCorrection]
    /// The table with these corrections applied.
    public let calendar: HijriCalendar

    /// The furthest a correction may move a month from the table.
    public static let maximumOffset = 2

    /// Builds a set, or throws every reason it's invalid (`HijriCorrectionsValidationError.codes`).
    public init(_ corrections: [HijriCorrection]) throws(HijriCorrectionsValidationError) {
        var codes: Set<HijriCorrectionsValidationError.Code> = []
        var byIndex: [Int: Int] = [:]
        var seen: Set<[Int]> = []
        for correction in corrections {
            if !seen.insert([correction.year, correction.month]).inserted {
                codes.insert(.duplicateMonth)
            }
            if abs(correction.offsetDays) > Self.maximumOffset {
                codes.insert(.offsetOutOfRange)
            }
            if let index = HijriCalendar.index(year: correction.year, month: correction.month) {
                byIndex[index] = correction.offsetDays
            } else {
                codes.insert(.monthOutOfRange)
            }
        }
        guard codes.isEmpty else { throw HijriCorrectionsValidationError(codes) }
        let candidate = Self(validated: byIndex)
        guard candidate.calendar.monthLengths.allSatisfy((29...30).contains) else {
            throw HijriCorrectionsValidationError([.monthLengthInvalid])
        }
        self = candidate
    }

    /// `offsets` (month index → days) already checked, or about to be.
    private init(validated offsets: [Int: Int]) {
        all = offsets.keys.sorted().compactMap { index in
            offsets[index].map {
                HijriCorrection(year: UmmAlQuraTable.firstYear + index / 12, month: index % 12 + 1, offsetDays: $0)
            }
        }
        calendar = HijriCalendar(offsets: offsets)
    }

    public static func == (lhs: HijriCorrections, rhs: HijriCorrections) -> Bool {
        lhs.all == rhs.all
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(all)
    }
}
