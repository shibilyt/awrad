import { describe, expect, test } from "vitest";
import effectivePracticeDayFixture from "../../../../contracts/goal-model/v1/fixtures/effective_practice_day.json";
import { loadCities, searchCities } from "./cities";
import { hijriCorrectionErrors, hijriDate, type HijriCorrection } from "./hijri";
import { maghribOn } from "./maghrib";
import { mergePolicy } from "./merge";
import { policyProblems, type CalculationMethod, type DayReset, type PracticePolicy } from "./policy";
import { effectivePracticeDay } from "./practiceDay";

/**
 * Runs the slice 3d fixtures (contracts/FIXTURES.md) against the real rules, naming failures by
 * case id: practice-settings/v1, places/v1 and hijri-calendar/v1 in full, and goal-model's
 * effective_practice_day (the rest of goal-model is slice 4's). Every file in those three
 * directories must have an adapter here or be another platform's, so a new rule can't be skipped.
 */
interface Case {
  id: string;
  given: Record<string, unknown>;
  expect: Record<string, unknown>;
}
interface Fixture {
  format: string;
  rule: string;
  cases: Case[];
}

const FILES: Record<string, Fixture> = {
  ...import.meta.glob("../../../../contracts/practice-settings/v1/fixtures/*.json", { eager: true, import: "default" }),
  ...import.meta.glob("../../../../contracts/places/v1/fixtures/*.json", { eager: true, import: "default" }),
  ...import.meta.glob("../../../../contracts/hijri-calendar/v1/fixtures/*.json", { eager: true, import: "default" }),
};
const fixtures = [...Object.values(FILES), effectivePracticeDayFixture as Fixture];

/** Within the 60 seconds maghrib_time allows; `null` only where the fixture says so. */
function expectSameMinute(actual: Date | null, expected: unknown): void {
  if (expected === null) {
    expect(actual).toBeNull();
    return;
  }
  if (typeof expected !== "string" || actual === null) {
    throw new Error(`expected ${JSON.stringify(expected)}, got ${String(actual)}`);
  }
  expect(Math.abs(actual.getTime() - Date.parse(expected))).toBeLessThanOrEqual(60_000);
}

type Check = (given: Record<string, unknown>, expected: Record<string, unknown>) => void | Promise<void>;
const policy = (value: unknown) => value as PracticePolicy;

const CHECKS: Record<string, Check> = {
  practice_policy_validity: (given, expected) => {
    const errors = policyProblems(given["document"]);
    expect({ valid: errors.length === 0, errors }).toEqual(expected);
  },
  practice_policy_merge: (given, expected) => {
    expect(mergePolicy(policy(given["base"]), policy(given["mine"]), policy(given["theirs"]))).toEqual(expected);
  },
  maghrib_time: (given, expected) => {
    const place = { latitude: given["latitude"] as number, longitude: given["longitude"] as number };
    expectSameMinute(
      maghribOn(given["date"] as string, place, given["calculation_method"] as CalculationMethod),
      expected["maghrib"],
    );
  },
  city_search: async (given, expected) => {
    const { cities } = await loadCities();
    const found = searchCities(cities, given["query"] as string, given["limit"] as number);
    expect(found.map((city) => city.id)).toEqual(expected["city_ids"]);
  },
  hijri_date: (given, expected) => {
    const { hijri, monthLength } = hijriDate(given["date"] as string, given["corrections"] as HijriCorrection[]);
    expect({ hijri, month_length: monthLength }).toEqual(expected);
  },
  hijri_corrections_validity: (given, expected) => {
    const errors = hijriCorrectionErrors(given["corrections"] as HijriCorrection[]);
    expect({ valid: errors.length === 0, errors }).toEqual(expected);
  },
  effective_practice_day: (given, expected) => {
    const maghrib = given["maghrib"] === null ? null : new Date(given["maghrib"] as string);
    const date = effectivePracticeDay({
      instant: new Date(given["instant"] as string),
      timeZone: given["timezone"] as string,
      dayReset: given["day_reset"] as DayReset,
      maghrib,
    });
    expect({ date }).toEqual(expected);
  },
};

/** Phones only: whose policy a phone ends up with at its first sign-in (the web has no local profile). */
const NOT_ON_THE_WEB = ["practice_policy_first_sign_in"];

test("every fixture file has a check or is another platform's, and every check a file", () => {
  expect(fixtures.map((fixture) => fixture.rule).sort()).toEqual([...Object.keys(CHECKS), ...NOT_ON_THE_WEB].sort());
  for (const fixture of fixtures) expect(fixture.format).toBe("awrad-fixture/1");
});

for (const fixture of fixtures.filter(({ rule }) => rule in CHECKS)) {
  describe(fixture.rule, () => {
    test.each(fixture.cases.map((testCase) => [testCase.id, testCase] as const))("%s", async (_id, testCase) => {
      const check = CHECKS[fixture.rule];
      if (check === undefined) throw new Error(`no check for ${fixture.rule}`);
      await check(testCase.given, testCase.expect);
    });
  });
}
