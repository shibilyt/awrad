import AwradDomain
import AwradTesting
import Foundation
import Testing

// Every case of contracts/identity/v1/fixtures/, run through the real `AwradID` and `UUIDv7`. The
// fixtures are the spec: never edit them to match this code.

@Suite("identity v1 fixtures")
struct IdentityFixtureTests {
    @Test(arguments: try IdentityFixtures.uuidFormat())
    func uuidFormat(_ fixture: FixtureCase<UUIDFormatGiven, UUIDFormatExpect>) {
        let id = AwradID(fixture.given.text)
        #expect(UUIDFormatExpect(id) == fixture.expect, "\(fixture.id): \(fixture.summary)")
    }

    @Test(arguments: try IdentityFixtures.uuidV7Layout())
    func uuidV7Layout(_ fixture: FixtureCase<UUIDv7LayoutGiven, UUIDv7LayoutExpect>) throws {
        let random = try #require(fixture.given.randomBytes, "\(fixture.id): random_hex")
        let uuid = UUIDv7.uuid(unixMilliseconds: fixture.given.unixMs, random: random)
        #expect(UUIDv7LayoutExpect(AwradID(uuid)) == fixture.expect, "\(fixture.id): \(fixture.summary)")
    }
}

/// The production generator: what the layout fixture can't pin because it's random or clock-bound.
struct UUIDv7GeneratorTests {
    /// The 48-bit time a UUIDv7 carries.
    private func unixMilliseconds(of id: AwradID) -> UInt64 {
        withUnsafeBytes(of: id.value.uuid) { bytes in
            bytes.prefix(6).reduce(0) { $0 << 8 | UInt64($1) }
        }
    }

    @Test func consecutiveIDsAreValidV7AndSortByTime() throws {
        let ids = (0..<1_000).map { _ in AwradID.random() }
        for id in ids {
            let parsed = try #require(AwradID(id.description), "\(id) isn't a valid ID")
            #expect(parsed == id)
            let bytes = id.value.uuid
            #expect(bytes.6 >> 4 == 0x7, "\(id) isn't version 7")
            #expect(bytes.8 >> 6 == 0b10, "\(id) isn't the RFC 9562 variant")
        }
        let times = ids.map(unixMilliseconds(of:))
        #expect(times == times.sorted())
        #expect(Set(ids).count == ids.count)
    }

    @Test func theTimeIsTheInjectedClocksMilliseconds() {
        let now = Date(timeIntervalSince1970: 1_645_557_742.000_9)
        let id = AwradID(UUIDv7.generate(now: { now }))
        #expect(unixMilliseconds(of: id) == 1_645_557_742_000)
        #expect(id.description.hasPrefix("017f22e2-79b0-7"))
    }

    @Test func randomBitsComeFromTheInjectedGenerator() {
        var zeros = ConstantGenerator(value: 0)
        var ones = ConstantGenerator(value: .max)
        let epoch = Date(timeIntervalSince1970: 0)
        #expect(UUIDv7.generate(now: { epoch }, using: &zeros).uuidString == "00000000-0000-7000-8000-000000000000")
        #expect(UUIDv7.generate(now: { epoch }, using: &ones).uuidString == "00000000-0000-7FFF-BFFF-FFFFFFFFFFFF")
    }

    @Test func aClockBefore1970GivesTimeZero() {
        let id = AwradID(UUIDv7.generate(now: { Date(timeIntervalSince1970: -1) }))
        #expect(unixMilliseconds(of: id) == 0)
    }
}

private struct ConstantGenerator: RandomNumberGenerator {
    let value: UInt64
    mutating func next() -> UInt64 { value }
}
