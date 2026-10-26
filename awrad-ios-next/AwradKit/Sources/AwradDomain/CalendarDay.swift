import Foundation

/// A Gregorian calendar day (`YYYY-MM-DD`) with no time or timezone: an effective practice day,
/// a start or end date, a count entry's day.
///
/// All day arithmetic goes through one explicit Gregorian calendar fixed to UTC, never
/// `Calendar.current`: the frozen app broke on devices set to the Islamic or Persian calendar
/// (slice 1, inventory row 3). Strideable, so a `ClosedRange<CalendarDay>` is a window you can walk.
public struct CalendarDay: Hashable, Sendable, Strideable, CustomStringConvertible {
    public let year: Int
    public let month: Int
    public let day: Int

    /// `nil` unless the components name a real Gregorian day (no 30 February).
    public init?(year: Int, month: Int, day: Int) {
        let components = DateComponents(year: year, month: month, day: day)
        guard let date = Gregorian.calendar.date(from: components) else { return nil }
        self.init(utcMidnight: date)
        guard self.year == year, self.month == month, self.day == day else { return nil }
    }

    /// Parses `YYYY-MM-DD`, the wire and fixture format.
    public init?(_ string: String) {
        let parts = string.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3, parts[0].count == 4, parts[1].count == 2, parts[2].count == 2,
            let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2])
        else { return nil }
        self.init(year: year, month: month, day: day)
    }

    /// The local calendar day of `instant` in `timeZone` (still Gregorian, whatever the device uses).
    public init(_ instant: Date, in timeZone: TimeZone) {
        var calendar = Gregorian.calendar
        calendar.timeZone = timeZone
        let parts = calendar.dateComponents([.year, .month, .day], from: instant)
        year = parts.year ?? 0
        month = parts.month ?? 0
        day = parts.day ?? 0
    }

    init(utcMidnight date: Date) {
        self.init(date, in: Gregorian.calendar.timeZone)
    }

    /// `YYYY-MM-DD`.
    public var description: String {
        String(format: "%04d-%02d-%02d", year, month, day)
    }

    public var weekday: Weekday {
        Weekday(gregorianNumber: Gregorian.calendar.component(.weekday, from: utcMidnight))
    }

    public var firstDayOfMonth: CalendarDay {
        adding(days: 1 - day)
    }

    public var lastDayOfMonth: CalendarDay {
        let length = Gregorian.calendar.range(of: .day, in: .month, for: utcMidnight)?.count ?? day
        return adding(days: length - day)
    }

    public func adding(days: Int) -> CalendarDay {
        guard days != 0 else { return self }
        guard let date = Gregorian.calendar.date(byAdding: .day, value: days, to: utcMidnight) else {
            preconditionFailure("Gregorian day arithmetic overflowed: \(self) + \(days)")
        }
        return CalendarDay(utcMidnight: date)
    }

    /// Whole days from `self` to `other` (negative when `other` is earlier).
    public func distance(to other: CalendarDay) -> Int {
        Gregorian.calendar.dateComponents([.day], from: utcMidnight, to: other.utcMidnight).day ?? 0
    }

    public func advanced(by days: Int) -> CalendarDay {
        adding(days: days)
    }

    public static func < (lhs: CalendarDay, rhs: CalendarDay) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }

    var utcMidnight: Date {
        let components = DateComponents(year: year, month: month, day: day)
        guard let date = Gregorian.calendar.date(from: components) else {
            preconditionFailure("CalendarDay holds an invalid day: \(year)-\(month)-\(day)")
        }
        return date
    }
}

/// A day of the week, by name. Fixtures and the API never number weekdays: the frozen apps
/// disagreed on whether 1 is Sunday or Monday.
public enum Weekday: String, CaseIterable, Hashable, Sendable {
    case monday, tuesday, wednesday, thursday, friday, saturday, sunday

    /// From `Calendar.Component.weekday` in the Gregorian calendar, where 1 is Sunday.
    init(gregorianNumber: Int) {
        let order: [Weekday] = [.sunday, .monday, .tuesday, .wednesday, .thursday, .friday, .saturday]
        self = order[((gregorianNumber - 1) % 7 + 7) % 7]
    }

    /// Days from `other` forward to `self` (0...6).
    func daysSince(_ other: Weekday) -> Int {
        let all = Weekday.allCases
        let distance = (all.firstIndex(of: self) ?? 0) - (all.firstIndex(of: other) ?? 0)
        return (distance + 7) % 7
    }
}

/// The first day of a week for week-based windows, from the account practice policy (default Monday).
public enum WeekStart: String, CaseIterable, Hashable, Sendable {
    case saturday, sunday, monday

    public var weekday: Weekday {
        switch self {
        case .saturday: .saturday
        case .sunday: .sunday
        case .monday: .monday
        }
    }
}

/// The one calendar every Gregorian rule uses.
enum Gregorian {
    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        calendar.locale = Locale(identifier: "en_US_POSIX")
        return calendar
    }()
}
