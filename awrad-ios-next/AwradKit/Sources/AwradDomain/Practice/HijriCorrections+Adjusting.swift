import Foundation

// "Adjust this month" (slice 3d brief, Hijri corrections UI): a month can be moved only to the
// offsets that keep every month 29 or 30 days, so usually one day from the month before, in one
// direction.

extension HijriCorrections {
    /// The offset in force for `year`/`month`: its own correction, else the last earlier one, else 0.
    public func offset(year: Int, month: Int) -> Int {
        all.last { ($0.year, $0.month) <= (year, month) }?.offsetDays ?? 0
    }

    /// This month's own correction, if it has one.
    public func correction(year: Int, month: Int) -> HijriCorrection? {
        all.first { $0.year == year && $0.month == month }
    }

    /// The offsets (−2…2, ascending) `year`/`month` can be moved to with the set staying valid.
    public func allowedOffsets(year: Int, month: Int) -> [Int] {
        (-Self.maximumOffset...Self.maximumOffset).filter { setting($0, year: year, month: month) != nil }
    }

    /// The set with `year`/`month` moved to `offset` from the table, or `nil` when that's invalid.
    /// When the month would inherit `offset` anyway, its own correction is dropped instead.
    public func setting(_ offset: Int, year: Int, month: Int) -> HijriCorrections? {
        var others = all.filter { $0.year != year || $0.month != month }
        let inherited = others.last { ($0.year, $0.month) < (year, month) }?.offsetDays ?? 0
        if offset != inherited { others.append(HijriCorrection(year: year, month: month, offsetDays: offset)) }
        return try? HijriCorrections(others)
    }

    /// The set without `year`/`month`'s own correction, or `nil` when that leaves a month of the
    /// wrong length (a later correction depends on it).
    public func removing(year: Int, month: Int) -> HijriCorrections? {
        try? HijriCorrections(all.filter { $0.year != year || $0.month != month })
    }
}

extension HijriDate {
    /// The month after this date's, as (year, month).
    public var nextMonth: (year: Int, month: Int) {
        month == 12 ? (year + 1, 1) : (year, month + 1)
    }
}
