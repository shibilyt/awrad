import AwradDomain
import AwradTesting
import Foundation
import Testing

// Every case of contracts/hijri-calendar/v1/fixtures/, run through the real calendar, and the
// compiled-in table checked month by month against the contract's umm-al-qura.json.

@Suite("hijri-calendar v1 fixtures")
struct HijriCalendarFixtureTests {
    @Test(arguments: try HijriCalendarFixtures.hijriDate())
    func hijriDate(_ fixture: FixtureCase<HijriDateGiven, HijriDateExpect>) {
        let given = fixture.given
        let date = given.corrections.calendar.date(of: given.date)
        #expect(HijriDateExpect(date) == fixture.expect, "\(fixture.id): \(fixture.summary)")
    }

    @Test(arguments: try HijriCalendarFixtures.hijriCorrectionsValidity())
    func hijriCorrectionsValidity(_ fixture: FixtureCase<HijriCorrectionsGiven, ValidityExpect>) {
        #expect(ValidityExpect(fixture.given.construction) == fixture.expect, "\(fixture.id): \(fixture.summary)")
    }
}

@Suite("Umm al-Qura table")
struct UmmAlQuraTableTests {
    private struct Table: Decodable {
        let monthStarts: [String: [String]]
        let endExclusive: String
    }

    /// The generated Swift table decodes to exactly the contract's month starts and end. (The
    /// freshness check in scripts/validate compares the source; this checks what it decodes to.)
    @Test func everyMonthStartsWhereTheContractSays() throws {
        let file = try FixtureLoader.contractsDirectory(holding: "hijri-calendar")
            .appending(path: "hijri-calendar/v1/umm-al-qura.json")
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let table = try decoder.decode(Table.self, from: Data(contentsOf: file))
        let calendar = HijriCalendar.ummAlQura
        var checked = 0
        for (year, starts) in table.monthStarts {
            for (offset, start) in starts.enumerated() {
                let day = try #require(CalendarDay(start))
                let date = try #require(calendar.date(of: day), "\(year)/\(offset + 1)")
                #expect([date.year, date.month, date.day] == [Int(year), offset + 1, 1], "\(start)")
                checked += 1
            }
        }
        #expect(checked == 101 * 12)
        let end = try #require(CalendarDay(table.endExclusive))
        #expect(calendar.date(of: end) == nil)
        #expect(calendar.range.upperBound == end.adding(days: -1))
    }
}
