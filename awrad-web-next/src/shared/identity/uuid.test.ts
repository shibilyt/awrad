import { describe, expect, test } from "vitest";
import { isValidId, newUuidV7, uuidV7FromParts } from ".";

const V7 = /^[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/;

describe("newUuidV7", () => {
  test("uses the system clock and a cryptographic random source by default", () => {
    const before = Date.now();
    const id = newUuidV7();
    const after = Date.now();
    expect(id).toMatch(V7);
    expect(isValidId(id)).toBe(true);
    const unixMs = Number.parseInt(id.replaceAll("-", "").slice(0, 12), 16);
    expect(unixMs).toBeGreaterThanOrEqual(before);
    expect(unixMs).toBeLessThanOrEqual(after);
  });

  test("two IDs differ", () => {
    expect(newUuidV7()).not.toBe(newUuidV7());
  });
});

describe("uuidV7FromParts", () => {
  test.each([-1, 2 ** 48, 1.5, Number.NaN])("rejects time %s", (unixMs) => {
    expect(() => uuidV7FromParts(unixMs, new Uint8Array(10))).toThrow(RangeError);
  });

  test.each([9, 11])("rejects %i random bytes", (length) => {
    expect(() => uuidV7FromParts(0, new Uint8Array(length))).toThrow(RangeError);
  });
});
