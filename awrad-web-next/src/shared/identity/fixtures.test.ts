import { describe, expect, test } from "vitest";
import { isValidId, newUuidV7, uuidV7FromParts } from ".";

/**
 * Runs contracts/identity/v1/fixtures/ (contracts/FIXTURES.md) against the real
 * generator and validator, naming failures by case id. Every fixture file there needs an
 * adapter here, so a new shared rule can't be skipped silently.
 */
interface Fixture {
  format: string;
  rule: string;
  cases: { id: string; given: Record<string, unknown>; expect: unknown }[];
}

const FIXTURES: Record<string, Fixture> = import.meta.glob("../../../../contracts/identity/v1/fixtures/*.json", {
  eager: true,
  import: "default",
});

function text(given: Record<string, unknown>, key: string): string {
  const value = given[key];
  if (typeof value !== "string") throw new Error(`given.${key} isn't a string`);
  return value;
}

function integer(given: Record<string, unknown>, key: string): number {
  const value = given[key];
  if (typeof value !== "number" || !Number.isSafeInteger(value)) throw new Error(`given.${key} isn't an integer`);
  return value;
}

function bytesOf(hex: string): Uint8Array {
  return Uint8Array.from(hex.match(/../g) ?? [], (pair) => Number.parseInt(pair, 16));
}

const ADAPTERS: Record<string, (given: Record<string, unknown>) => unknown> = {
  uuid_format: (given) => ({ valid: isValidId(text(given, "text")) }),
  // Drives newUuidV7 through its injected clock and random source too, so the production path is tested.
  uuid_v7_layout: (given) => {
    const unixMs = integer(given, "unix_ms");
    const random = bytesOf(text(given, "random_hex"));
    const generated = newUuidV7({
      now: () => unixMs,
      fillRandom: (bytes) => {
        bytes.set(random);
      },
    });
    expect(generated).toBe(uuidV7FromParts(unixMs, random));
    return { uuid: generated };
  },
};

const fixtures = Object.entries(FIXTURES)
  .sort(([a], [b]) => a.localeCompare(b))
  .map(([, fixture]) => fixture);

test("every identity fixture file has an adapter, and every adapter a fixture file", () => {
  expect(fixtures.map((fixture) => fixture.rule).sort()).toEqual(Object.keys(ADAPTERS).sort());
  for (const fixture of fixtures) expect(fixture.format).toBe("awrad-fixture/1");
});

for (const fixture of fixtures) {
  describe(fixture.rule, () => {
    test.each(fixture.cases.map((testCase) => [testCase.id, testCase] as const))("%s", (_id, testCase) => {
      const adapter = ADAPTERS[fixture.rule];
      if (adapter === undefined) throw new Error(`no adapter for ${fixture.rule}`);
      expect(adapter(testCase.given)).toEqual(testCase.expect);
    });
  });
}
