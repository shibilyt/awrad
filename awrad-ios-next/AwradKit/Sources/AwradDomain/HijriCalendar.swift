import Foundation

// Rule: Hijri date (contracts/hijri-calendar/v1/fixtures/hijri_date.json).

/// A day in the Hijri calendar, with the length of its month (29 or 30).
public struct HijriDate: Hashable, Sendable, CustomStringConvertible {
    public let year: Int
    public let month: Int
    public let day: Int
    public let monthLength: Int

    public init(year: Int, month: Int, day: Int, monthLength: Int) {
        self.year = year
        self.month = month
        self.day = day
        self.monthLength = monthLength
    }

    /// `YYYY-MM-DD AH`.
    public var description: String {
        String(format: "%04d-%02d-%02d AH", year, month, day)
    }
}

/// A Hijri month and the Gregorian days it covers.
public struct HijriMonth: Hashable, Sendable {
    public let year: Int
    public let month: Int
    public let days: ClosedRange<CalendarDay>
}

/// The Umm al-Qura table (`UmmAlQuraTable`, generated from `contracts/hijri-calendar/v1`) with a
/// set of month-start corrections applied. No Hijri library is involved (root ADR-2026-10-26).
///
/// Get one from `HijriCorrections.calendar`, or `ummAlQura` for the table alone. Outside the
/// (adjusted) table there's no Hijri date: every lookup returns `nil`.
public struct HijriCalendar: Hashable, Sendable {
    /// The table without corrections.
    public static let ummAlQura = HijriCorrections.none.calendar

    /// The adjusted start of each month (`CalendarDay.ordinal`), 1 Muharram of the first year first.
    private let starts: [Int]
    /// The adjusted day after the last month: the table's end moves with the last correction.
    private let endExclusive: Int

    /// The table with `offsets` (month index → days) in force. A month without its own offset
    /// keeps the one before it; the end moves with the last month's.
    init(offsets: [Int: Int]) {
        var current = 0
        var starts: [Int] = []
        starts.reserveCapacity(UmmAlQuraTable.monthStarts.count)
        for (index, start) in UmmAlQuraTable.monthStarts.enumerated() {
            current = offsets[index] ?? current
            starts.append(start + current)
        }
        self.starts = starts
        endExclusive = UmmAlQuraTable.endExclusive + current
    }

    /// The days the table covers, after corrections.
    public var range: ClosedRange<CalendarDay> {
        CalendarDay(ordinal: starts[0])...CalendarDay(ordinal: endExclusive - 1)
    }

    /// The Hijri date of `day` (an effective practice day); `nil` outside the table.
    public func date(of day: CalendarDay) -> HijriDate? {
        let ordinal = day.ordinal
        guard let index = monthIndex(containing: ordinal) else { return nil }
        let (year, month) = Self.yearAndMonth(at: index)
        return HijriDate(
            year: year, month: month, day: ordinal - starts[index] + 1, monthLength: monthLength(at: index))
    }

    /// The Hijri month containing `day`; `nil` outside the table.
    public func month(containing day: CalendarDay) -> HijriMonth? {
        guard let index = monthIndex(containing: day.ordinal) else { return nil }
        let (year, month) = Self.yearAndMonth(at: index)
        let first = CalendarDay(ordinal: starts[index])
        return HijriMonth(year: year, month: month, days: first...first.adding(days: monthLength(at: index) - 1))
    }

    /// Every adjusted month's length, in table order. Validation checks they're 29 or 30.
    var monthLengths: [Int] {
        starts.indices.map(monthLength(at:))
    }

    /// The table index of `year`/`month`; `nil` outside the table.
    static func index(year: Int, month: Int) -> Int? {
        let index = (year - UmmAlQuraTable.firstYear) * 12 + month - 1
        let inTable = (UmmAlQuraTable.firstYear...UmmAlQuraTable.lastYear).contains(year) && (1...12).contains(month)
        return inTable ? index : nil
    }

    private static func yearAndMonth(at index: Int) -> (year: Int, month: Int) {
        (UmmAlQuraTable.firstYear + index / 12, index % 12 + 1)
    }

    private func monthLength(at index: Int) -> Int {
        (index + 1 < starts.count ? starts[index + 1] : endExclusive) - starts[index]
    }

    /// Binary search for the last month starting on or before `ordinal`.
    private func monthIndex(containing ordinal: Int) -> Int? {
        guard let first = starts.first, ordinal >= first, ordinal < endExclusive else { return nil }
        var low = 0
        var high = starts.count - 1
        while low < high {
            let middle = (low + high + 1) / 2
            if starts[middle] <= ordinal {
                low = middle
            } else {
                high = middle - 1
            }
        }
        return low
    }
}
