import { describe, expect, test } from "vitest";
import { uploadRuleError } from "./rules";

/**
 * Runs contracts/audio/v1/fixtures/ (contracts/FIXTURES.md) against the real rule, naming failures
 * by case id. Every file needs an adapter, so a new rule can't be skipped silently.
 */
interface Fixture {
  format: string;
  rule: string;
  cases: { id: string; given: Record<string, unknown>; expect: unknown }[];
}

const FIXTURES: Record<string, Fixture> = import.meta.glob("../../../../contracts/audio/v1/fixtures/*.json", {
  eager: true,
  import: "default",
});

const ADAPTERS: Record<string, (given: Record<string, unknown>) => unknown> = {
  audio_upload_validity: (given) => {
    const { byte_size: byteSize, content_type: contentType, used_bytes: usedBytes } = given;
    if (typeof byteSize !== "number" || typeof contentType !== "string" || typeof usedBytes !== "number") {
      throw new Error("given isn't {byte_size, content_type, used_bytes}");
    }
    const error = uploadRuleError({ byte_size: byteSize, content_type: contentType, used_bytes: usedBytes });
    return { allowed: error === null, error };
  },
};

const fixtures = Object.values(FIXTURES).sort((a, b) => a.rule.localeCompare(b.rule));

test("every audio fixture file has an adapter, and every adapter a file", () => {
  expect(fixtures.map((fixture) => fixture.rule)).toEqual(Object.keys(ADAPTERS).sort());
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
