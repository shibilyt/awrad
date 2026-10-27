import { describe, expect, test } from "vitest";
import { isLanguage } from "@/shared/i18n";
import { catalog } from "./catalog.gen";
import { normalizeForSearch, searchDhikrs } from "./search";

/**
 * Runs contracts/dhikr-catalog/v1/fixtures/ (contracts/FIXTURES.md) against the real search,
 * naming failures by case id. Every fixture file there needs an adapter here, so a new shared
 * rule can't be skipped silently. Fixtures are never edited to fit the code.
 */
interface Fixture {
  format: string;
  rule: string;
  cases: { id: string; given: Record<string, unknown>; expect: unknown }[];
}

const FIXTURES: Record<string, Fixture> = import.meta.glob("../../../../contracts/dhikr-catalog/v1/fixtures/*.json", {
  eager: true,
  import: "default",
});

function text(given: Record<string, unknown>, key: string): string {
  const value = given[key];
  if (typeof value !== "string") throw new Error(`given.${key} isn't a string`);
  return value;
}

const ADAPTERS: Record<string, (given: Record<string, unknown>) => unknown> = {
  dhikr_search_normalization: (given) => ({ normalized: normalizeForSearch(text(given, "text")) }),
  dhikr_search: (given) => {
    const language = text(given, "language");
    if (!isLanguage(language)) throw new Error(`unknown language ${language}`);
    return { keys: searchDhikrs(catalog, text(given, "query"), language).map((dhikr) => dhikr.key) };
  },
};

const fixtures = Object.entries(FIXTURES)
  .sort(([a], [b]) => a.localeCompare(b))
  .map(([, fixture]) => fixture);

test("every dhikr-catalog fixture file has an adapter, and every adapter a fixture file", () => {
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
