import { describe, expect, test } from "vitest";
import { customDhikrProblems } from "./customDhikrValidity";
import { normalizeTagName } from "./tagName";

/**
 * Runs contracts/sync/v1/fixtures/ (contracts/FIXTURES.md) against the real rules, naming failures
 * by case id. The web runs the two rules every platform shares; the others belong to the server
 * or to phones (contracts/sync/v1/README.md "Fixtures"). Every file must be one or the other, so a
 * new rule can't be skipped silently.
 */
interface Fixture {
  format: string;
  rule: string;
  cases: { id: string; given: Record<string, unknown>; expect: unknown }[];
}

const FIXTURES: Record<string, Fixture> = import.meta.glob("../../../../contracts/sync/v1/fixtures/*.json", {
  eager: true,
  import: "default",
});

const ADAPTERS: Record<string, (given: Record<string, unknown>) => unknown> = {
  tag_name_normalization: (given) => {
    if (typeof given["input"] !== "string") throw new Error("given.input isn't a string");
    return normalizeTagName(given["input"]);
  },
  custom_dhikr_validity: (given) => {
    const errors = customDhikrProblems(given["document"]);
    return { valid: errors.length === 0, errors };
  },
};

/** Rules only the server (receipts, the feed) or the phones' queue and profiles run. */
const NOT_ON_THE_WEB = ["sync_receipts", "sync_changes_feed", "outbox_enqueue", "apply_changes", "profile_switch"];

const fixtures = Object.entries(FIXTURES)
  .sort(([a], [b]) => a.localeCompare(b))
  .map(([, fixture]) => fixture);

test("every sync fixture file has an adapter or is another platform's, and every adapter a file", () => {
  expect(fixtures.length).toBeGreaterThan(0);
  expect(fixtures.map((fixture) => fixture.rule).sort()).toEqual([...Object.keys(ADAPTERS), ...NOT_ON_THE_WEB].sort());
  for (const fixture of fixtures) expect(fixture.format).toBe("awrad-fixture/1");
});

for (const fixture of fixtures.filter(({ rule }) => rule in ADAPTERS)) {
  describe(fixture.rule, () => {
    test.each(fixture.cases.map((testCase) => [testCase.id, testCase] as const))("%s", (_id, testCase) => {
      const adapter = ADAPTERS[fixture.rule];
      if (adapter === undefined) throw new Error(`no adapter for ${fixture.rule}`);
      expect(adapter(testCase.given)).toEqual(testCase.expect);
    });
  });
}
