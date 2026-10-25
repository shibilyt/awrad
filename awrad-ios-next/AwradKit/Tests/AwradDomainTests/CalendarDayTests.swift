import AwradDomain
import Foundation
import Testing

struct CalendarDayTests {
    @Test func parsesAndPrintsTheWireFormat() throws {
        let day = try #require(CalendarDay("2028-02-29"))
        #expect(day.year == 2028 && day.month == 2 && day.day == 29)
        #expect(day.description == "2028-02-29")
    }

    @Test(arguments: ["2027-02-29", "2026-13-01", "2026-1-01", "20261001", "", "2026-10-01T00:00"])
    func rejectsInvalidDays(_ string: String) {
        #expect(CalendarDay(string) == nil)
    }

    @Test func arithmeticCrossesMonthAndYearEnds() throws {
        let day = try #require(CalendarDay("2026-12-31"))
        #expect(day.adding(days: 1).description == "2027-01-01")
        #expect(day.adding(days: -365).description == "2025-12-31")
        #expect(try #require(CalendarDay("2026-10-01")).distance(to: day) == 91)
        #expect(try #require(CalendarDay("2027-02-10")).lastDayOfMonth.description == "2027-02-28")
    }

    @Test func windowsAreWalkableRanges() throws {
        let from = try #require(CalendarDay("2026-10-30"))
        let window = from...from.adding(days: 3)
        #expect(window.map(\.description) == ["2026-10-30", "2026-10-31", "2026-11-01", "2026-11-02"])
    }

    @Test func weekdaysAreGregorianWhateverTheDeviceCalendar() throws {
        // 14 October 2026 is a Wednesday; the device calendar must not matter (inventory row 3).
        #expect(try #require(CalendarDay("2026-10-14")).weekday == .wednesday)
        var islamic = Calendar(identifier: .islamicUmmAlQura)
        islamic.timeZone = try #require(TimeZone(identifier: "Asia/Riyadh"))
        let instant = try #require(islamic.date(from: DateComponents(year: 1448, month: 4, day: 3, hour: 12)))
        let day = CalendarDay(instant, in: islamic.timeZone)
        #expect(day.year == 2026 && day.weekday == CalendarDay(instant, in: .gmt).weekday)
    }

    @Test func weeksStartOnTheAccountsWeekStart() throws {
        let wednesday = try #require(CalendarDay("2026-10-14"))
        #expect(Period.week.window(containing: wednesday, weekStart: .monday).lowerBound.description == "2026-10-12")
        #expect(Period.week.window(containing: wednesday, weekStart: .sunday).lowerBound.description == "2026-10-11")
        #expect(Period.week.window(containing: wednesday, weekStart: .saturday).upperBound.description == "2026-10-16")
    }

    @Test func idsPrintLowercaseLikeTheWireFormat() throws {
        let id = try #require(AwradID("3285E014-551B-46A4-AEDC-8B6664B59BC7"))
        #expect(id.description == "3285e014-551b-46a4-aedc-8b6664b59bc7")
    }
}
