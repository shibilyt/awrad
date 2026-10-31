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
        // 1970-01-01 was a Thursday (Gregorian weekday 5, where 1 is Sunday).
        Weekday(gregorianNumber: ((ordinal + 4) % 7 + 7) % 7 + 1)
    }

    public var firstDayOfMonth: CalendarDay {
        adding(days: 1 - day)
    }

    public var lastDayOfMonth: CalendarDay {
        adding(days: Self.daysInMonth(year: year, month: month) - day)
    }

    /// Plain ordinal arithmetic: the goal rules walk many days, and Foundation's calendar is slow.
    public func adding(days: Int) -> CalendarDay {
        guard days != 0 else { return self }
        return CalendarDay(ordinal: ordinal + days)
    }

    /// Whole days from `self` to `other` (negative when `other` is earlier).
    public func distance(to other: CalendarDay) -> Int {
        other.ordinal - ordinal
    }

    /// The number of days in a Gregorian month.
    static func daysInMonth(year: Int, month: Int) -> Int {
        switch month {
        case 2:
            let isLeap = year % 4 == 0 && (year % 100 != 0 || year % 400 == 0)
            return isLeap ? 29 : 28
        case 4, 6, 9, 11:
            return 30
        default:
            return 31
        }
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

extension CalendarDay {
    /// Days since 1970-01-01 in the proleptic Gregorian calendar: the Hijri table's encoding.
    /// Plain arithmetic (H. Hinnant's `days_from_civil`), so table lookups stay cheap.
    var ordinal: Int {
        let shiftedYear = month <= 2 ? year - 1 : year
        let era = (shiftedYear >= 0 ? shiftedYear : shiftedYear - 399) / 400
        let yearOfEra = shiftedYear - era * 400
        let dayOfYear = (153 * ((month + 9) % 12) + 2) / 5 + day - 1
        let dayOfEra = yearOfEra * 365 + yearOfEra / 4 - yearOfEra / 100 + dayOfYear
        return era * 146_097 + dayOfEra - 719_468
    }

    /// The day `ordinal` days after 1970-01-01 (H. Hinnant's `civil_from_days`).
    init(ordinal: Int) {
        let shifted = ordinal + 719_468
        let era = (shifted >= 0 ? shifted : shifted - 146_096) / 146_097
        let dayOfEra = shifted - era * 146_097
        let yearOfEra = (dayOfEra - dayOfEra / 1460 + dayOfEra / 36_524 - dayOfEra / 146_096) / 365
        let dayOfYear = dayOfEra - (365 * yearOfEra + yearOfEra / 4 - yearOfEra / 100)
        let shiftedMonth = (5 * dayOfYear + 2) / 153
        let month = shiftedMonth < 10 ? shiftedMonth + 3 : shiftedMonth - 9
        self.year = yearOfEra + era * 400 + (month <= 2 ? 1 : 0)
        self.month = month
        self.day = dayOfYear - (153 * shiftedMonth + 2) / 5 + 1
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
