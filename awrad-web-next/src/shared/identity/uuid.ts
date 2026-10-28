/**
 * IDs (root ADR-2026-10-28, contracts/identity/v1/): every ID the app generates is a
 * UUIDv7 (RFC 9562 §5.7). An ID's timestamp is never used to order, expire or authorize
 * anything; it's only there to keep server indexes compact.
 */

/** The largest 48-bit Unix millisecond time a UUIDv7 can hold. */
const MAX_UNIX_MS = 2 ** 48 - 1;
const RANDOM_BYTES = 10;

const ID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;
const NIL_ID = "00000000-0000-0000-0000-000000000000";
const MAX_ID = "ffffffff-ffff-ffff-ffff-ffffffffffff";

/**
 * Lays out a UUIDv7 exactly as `uuid_v7_layout.json` fixes it: bytes 0–5 are `unixMs`
 * big-endian; byte 6 is `0x70 | (r0 & 0x0f)`; byte 7 is r1; byte 8 is `0x80 | (r2 & 0x3f)`;
 * bytes 9–15 are r3..r9. Lowercase, hyphenated 8-4-4-4-12.
 */
export function uuidV7FromParts(unixMs: number, randomBytes: Uint8Array): string {
  if (!Number.isSafeInteger(unixMs) || unixMs < 0 || unixMs > MAX_UNIX_MS) {
    throw new RangeError(`unixMs must be an integer from 0 to ${String(MAX_UNIX_MS)}`);
  }
  if (randomBytes.length !== RANDOM_BYTES) {
    throw new RangeError(`randomBytes must hold ${String(RANDOM_BYTES)} bytes`);
  }
  const random = (index: number): number => randomBytes[index] ?? 0;
  const bytes = new Uint8Array(16);
  // 48 bits fit a double exactly, so the division and remainder are exact.
  let time = unixMs;
  for (let index = 5; index >= 0; index--) {
    bytes[index] = time % 256;
    time = Math.floor(time / 256);
  }
  bytes[6] = 0x70 | (random(0) & 0x0f);
  bytes[7] = random(1);
  bytes[8] = 0x80 | (random(2) & 0x3f);
  for (let index = 3; index < RANDOM_BYTES; index++) bytes[index + 6] = random(index);
  const hex = Array.from(bytes, (byte) => byte.toString(16).padStart(2, "0")).join("");
  return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-${hex.slice(12, 16)}-${hex.slice(16, 20)}-${hex.slice(20)}`;
}

/** Where a new ID's time and random bits come from; tests inject fixed ones. */
export interface UuidV7Sources {
  /** Unix time in milliseconds. */
  now: () => number;
  /** Fills the array with random bytes. */
  fillRandom: (bytes: Uint8Array<ArrayBuffer>) => void;
}

const systemSources: UuidV7Sources = {
  now: () => Date.now(),
  fillRandom: (bytes) => {
    crypto.getRandomValues(bytes);
  },
};

/** A new UUIDv7, by default from the system clock and a cryptographic random source. */
export function newUuidV7(sources: UuidV7Sources = systemSources): string {
  const randomBytes = new Uint8Array(RANDOM_BYTES);
  sources.fillRandom(randomBytes);
  return uuidV7FromParts(sources.now(), randomBytes);
}

/**
 * Whether `text` is an ID (`uuid_format.json`): lowercase, hyphenated 8-4-4-4-12 hex, any
 * version, but not the nil or max UUID. Nothing is trimmed or case-folded.
 */
export function isValidId(text: string): boolean {
  return ID_PATTERN.test(text) && text !== NIL_ID && text !== MAX_ID;
}
