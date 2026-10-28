import Foundation

/// Every ID the app generates (root ADR-2026-10-28, `contracts/identity/v1`): a UUIDv7 (RFC 9562
/// §5.7), a 48-bit Unix millisecond time followed by random bits.
///
/// Foundation's `UUID()` only makes v4, so it's never called outside tests
/// (`scripts/check-uuid-generation.py`). The timestamp is the device's clock, which can be wrong:
/// nothing may order, expire or authorize by it.
public enum UUIDv7 {
    /// How many random bytes one ID takes.
    public static let randomByteCount = 10
    /// The largest time the 48-bit field holds.
    public static let maxUnixMilliseconds: UInt64 = (1 << 48) - 1

    /// Lays out a UUIDv7 exactly as `uuid_v7_layout.json` fixes it: bytes 0–5 are the time,
    /// big-endian; byte 6 is `0x70 | (r0 & 0x0f)`; byte 7 is r1; byte 8 is `0x80 | (r2 & 0x3f)`;
    /// bytes 9–15 are r3…r9. Pure, so the fixture drives it.
    public static func uuid(unixMilliseconds: UInt64, random: [UInt8]) -> UUID {
        precondition(unixMilliseconds <= maxUnixMilliseconds, "A UUIDv7 time has 48 bits")
        precondition(random.count == randomByteCount, "A UUIDv7 takes \(randomByteCount) random bytes")
        let time = (0..<6).map { UInt8(truncatingIfNeeded: unixMilliseconds >> (8 * (5 - $0))) }
        return UUID(
            uuid: (
                time[0], time[1], time[2], time[3], time[4], time[5],
                0x70 | (random[0] & 0x0f), random[1],
                0x80 | (random[2] & 0x3f), random[3], random[4], random[5], random[6], random[7], random[8],
                random[9]
            ))
    }

    /// A new UUIDv7 at `now()`, with random bits from `generator`.
    public static func generate<Generator: RandomNumberGenerator>(
        now: () -> Date = Date.init,
        using generator: inout Generator
    ) -> UUID {
        let random = (0..<randomByteCount).map { _ in UInt8.random(in: .min ... .max, using: &generator) }
        return uuid(unixMilliseconds: unixMilliseconds(of: now()), random: random)
    }

    /// A new UUIDv7 at `now()`, with random bits from `SystemRandomNumberGenerator`, which is
    /// cryptographically secure on Apple platforms.
    public static func generate(now: () -> Date = Date.init) -> UUID {
        var generator = SystemRandomNumberGenerator()
        return generate(now: now, using: &generator)
    }

    /// `date` in whole Unix milliseconds, clamped to what the 48-bit field holds.
    static func unixMilliseconds(of date: Date) -> UInt64 {
        let milliseconds = (date.timeIntervalSince1970 * 1000).rounded(.down)
        guard milliseconds > 0 else { return 0 }
        return milliseconds >= Double(maxUnixMilliseconds) ? maxUnixMilliseconds : UInt64(milliseconds)
    }
}
