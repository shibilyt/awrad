# Identity v1

How IDs look and how new ones are made, for every project (ADR-2026-10-28).

- **Format:** every ID is a lowercase, hyphenated UUID. Any version is accepted, but not the nil or max UUID. Nothing is trimmed or case-folded. See [`fixtures/uuid_format.json`](fixtures/uuid_format.json).
- **New IDs are UUIDv7** (RFC 9562 §5.7): a 48-bit Unix millisecond time, then random bits. [`fixtures/uuid_v7_layout.json`](fixtures/uuid_v7_layout.json) fixes the exact layout from a time and 10 random bytes. Each platform's generator takes the clock and the random source as inputs, so the fixture drives it; production uses the system clock and a cryptographic random source.
- **Built-in content keeps its fixed IDs:** the built-in dhikr UUIDv4 constants (`progress-model/v1/builtin-dhikrs.json`) and the deterministic wird IDs. They are content constants and are never regenerated.
- **The timestamp is not a clock.** IDs created on devices carry the device's clock, which can be wrong. Nothing may order, expire or authorize by an ID's timestamp; sync orders by server revisions.
