import Foundation
import Testing
@testable import awrad

@MainActor
struct WirdContractV1Tests {
    @Test func bundledDalailMatchesCanonicalIdentityAndContent() throws {
        let wird = try #require(AwradSeedData.defaultWirds().first { $0.slug == "dalail-al-khayrat" })

        #expect(wird.id == UUID(uuidString: "377ac7e5-800e-3074-bb6e-91c3af353de3"))
        #expect(wird.version == 5)
        #expect(wird.estimatedMinutes == 60)
        #expect(wird.parts.count == 8)
        #expect(wird.schedule.partsByWeekday == [
            1: [6],
            2: [7, 0],
            3: [1],
            4: [2],
            5: [3],
            6: [4],
            7: [5],
        ])
        #expect(wird.parts[0].id == UUID(uuidString: "7b7ca701-9d65-3bfc-87b9-722f8b5377d9"))
        #expect(wird.parts[7].id == UUID(uuidString: "843ed09d-2834-3ce2-850f-22192d9c6ef6"))
        #expect(wird.parts[0].segments[0].id == UUID(uuidString: "0b78196b-72af-3483-906e-d8e1c2a204f7"))
        #expect(wird.parts[7].segments[18].id == UUID(uuidString: "bc7b0eb7-fa7e-3de0-8fa7-c2ea0e9f4c25"))
        #expect(wird.parts.reduce(0) { $0 + $1.segments.count } == 452)
        #expect(wird.parts.reduce(0) { $0 + $1.countableSegments.count } == 433)
        #expect(wird.parts.allSatisfy { part in
            part.countableSegments.allSatisfy { !$0.arabic.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        })
    }

    @Test func mondaySelectsLastThenFirstPartLikeAndroid() throws {
        let wird = try #require(AwradSeedData.defaultWirds().first { $0.slug == "dalail-al-khayrat" })
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))
        let monday = try #require(calendar.date(from: DateComponents(year: 2026, month: 7, day: 13)))

        #expect(calendar.component(.weekday, from: monday) == 2)
        #expect(WirdCalculator.activeParts(wird, on: monday, calendar: calendar).map { $0.id.uuidString.lowercased() } == [
            "843ed09d-2834-3ce2-850f-22192d9c6ef6",
            "7b7ca701-9d65-3bfc-87b9-722f8b5377d9",
        ])
    }

    @Test func weekdayMapSurvivesSnapshotRoundTrip() throws {
        let wird = try #require(AwradSeedData.defaultWirds().first { $0.slug == "dalail-al-khayrat" })
        let encoded = try JSONEncoder().encode(wird)
        let decoded = try JSONDecoder().decode(Wird.self, from: encoded)

        #expect(decoded.schedule.partsByWeekday == wird.schedule.partsByWeekday)
        #expect(decoded.parts.map(\.id) == wird.parts.map(\.id))
        #expect(decoded.parts.flatMap(\.segments).map(\.id) == wird.parts.flatMap(\.segments).map(\.id))
    }
}
