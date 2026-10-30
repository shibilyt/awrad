import AwradDomain
import Foundation

/// A Hijri month the user can move: the offsets the rules allow, and the one in force.
public struct MonthAdjustment: Equatable, Sendable {
    public let year: Int
    public let month: Int
    /// −2…2, ascending: only those that keep every month 29 or 30 days.
    public let offsets: [Int]
    public let selected: Int
}

/// A correction listed under "Earlier corrections".
public struct ListedCorrection: Equatable, Sendable, Identifiable {
    public let correction: HijriCorrection
    /// Removing it keeps the set valid (no later correction depends on it).
    public let canRemove: Bool

    public var id: String { "\(correction.year)/\(correction.month)" }
}

/// Why the Maghrib reset falls back to midnight now, if it does.
public enum MaghribFallback: Equatable, Sendable {
    case noLocation
    /// The sun doesn't set (or rise) here today.
    case noSunset
}

extension PracticeSettingsModel.State {
    /// The day of a Hijri month from which next month can be adjusted too: sightings are announced
    /// on the 29th (slice 3d UI rule, 2026-10-29).
    static let nextMonthFromDay = 29

    /// The current Hijri month (the effective practice day's, with corrections).
    public var thisMonth: MonthAdjustment? {
        today?.hijri.map { adjustment(year: $0.year, month: $0.month) }
    }

    /// Next month, offered from the 29th of this one.
    public var nextMonth: MonthAdjustment? {
        guard let date = today?.hijri, date.day >= Self.nextMonthFromDay else { return nil }
        let next = date.nextMonth
        let adjustment = adjustment(year: next.year, month: next.month)
        // Past the table's last month nothing can be set.
        return adjustment.offsets.isEmpty ? nil : adjustment
    }

    /// Every correction except this month's and next month's, which their own sections show.
    public var earlierCorrections: [ListedCorrection] {
        let shown = [thisMonth, nextMonth].compactMap { $0.map { [$0.year, $0.month] } }
        let corrections = policy.hijriCorrections
        return corrections.all.filter { !shown.contains([$0.year, $0.month]) }.map {
            ListedCorrection(correction: $0, canRemove: corrections.removing(year: $0.year, month: $0.month) != nil)
        }
    }

    public var maghribFallback: MaghribFallback? {
        guard policy.dayReset == .maghrib else { return nil }
        if location == nil { return .noLocation }
        return today?.maghrib == nil ? .noSunset : nil
    }

    private func adjustment(year: Int, month: Int) -> MonthAdjustment {
        let corrections = policy.hijriCorrections
        return MonthAdjustment(
            year: year, month: month, offsets: corrections.allowedOffsets(year: year, month: month),
            selected: corrections.offset(year: year, month: month))
    }
}
