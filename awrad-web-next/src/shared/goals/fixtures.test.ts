import { describe, expect, test } from "vitest";
import { effectivePracticeDay, type DayReset, type HijriCorrection, type WeekStart } from "@/shared/practice";
import {
  addVersion,
  attributeCounts,
  canExcuse,
  consistency,
  dailyPace,
  daysPerPeriod,
  documentErrors,
  goalCompletion,
  goalErrors,
  goalIsDue,
  goalStreak,
  makeUpDays,
  mergeGoalOrder,
  placeGoals,
  requirementStanding,
  todayRing,
  versionOnDay,
  type AttributedGoal,
  type CountEntry,
  type CountLogEntry,
  type Goal,
  type GoalCalendar,
  type GoalInput,
  type GoalOnDay,
  type GoalOrderDocument,
  type GoalSettings,
  type GoalTimeline,
  type PlacedGoal,
  type Version,
} from ".";

/**
 * Runs every file in contracts/goal-model/v1/fixtures/ (contracts/FIXTURES.md) against the
 * goal rules, naming failures by case id. Every file must have a check here, and every check a
 * file, so a new rule can't be skipped.
 */
type Given = Record<string, unknown>;
interface Fixture {
  format: string;
  rule: string;
  cases: { id: string; given: Given; expect: unknown }[];
}

const FILES: Record<string, Fixture> = import.meta.glob("../../../../contracts/goal-model/v1/fixtures/*.json", {
  eager: true,
  import: "default",
});
const fixtures = Object.entries(FILES)
  .sort(([a], [b]) => a.localeCompare(b))
  .map(([, fixture]) => fixture);

/** The day a rule evaluates: `goal`, `counts` and `date` in a case's `given`. */
const onDay = (given: Given): GoalOnDay => ({
  goal: given["goal"] as GoalInput,
  counts: (given["counts"] ?? []) as CountEntry[],
  date: given["date"] as string,
});

const NO_CORRECTIONS: readonly HijriCorrection[] = [];
/** The account's calendar; a case without `week_start` is for a rule that never reads it. */
const calendar = (given: Given): GoalCalendar => ({
  weekStart: (given["week_start"] ?? "monday") as WeekStart,
  hijriCorrections: (given["hijri_corrections"] ?? NO_CORRECTIONS) as HijriCorrection[],
});

const CHECKS: Record<string, (given: Given) => unknown> = {
  effective_practice_day: (given) => ({
    date: effectivePracticeDay({
      instant: new Date(given["instant"] as string),
      timeZone: given["timezone"] as string,
      dayReset: given["day_reset"] as DayReset,
      maghrib: given["maghrib"] === null ? null : new Date(given["maghrib"] as string),
    }),
  }),
  goal_is_due: (given) => ({ due: goalIsDue(given["goal"] as GoalInput, given["date"] as string, calendar(given)) }),
  requirement_standing: (given) => requirementStanding(onDay(given), calendar(given)),
  days_per_period: (given) => daysPerPeriod(onDay(given), calendar(given)),
  goal_completion: (given) => ({ completed: goalCompletion(onDay(given)) }),
  goal_streak: (given) => goalStreak(onDay(given), calendar(given)),
  goal_validity: (given) => {
    const errors =
      "document" in given ? documentErrors(given["document"] as GoalTimeline) : goalErrors(given["goal"] as Goal);
    return { valid: errors.length === 0, errors };
  },
  goal_version_on_day: (given) => versionOnDay(given["document"] as GoalTimeline, given["date"] as string),
  goal_version_add: (given) => ({
    versions: addVersion(given["versions"] as Version[], given["settings"] as GoalSettings, given["today"] as string),
  }),
  count_attribution: (given) => ({
    goals: (given["goals"] as AttributedGoal[]).map((goal) => ({
      id: goal.id,
      counts: attributeCounts(goal, given["log"] as CountLogEntry[]),
    })),
  }),
  make_up: (given) => ({ days: makeUpDays(onDay(given), given["from"] as string, calendar(given)) }),
  excused_days: (given) =>
    canExcuse(onDay(given), given["day"] as string, given["action"] as "excuse" | "unexcuse", calendar(given)),
  consistency: (given) => consistency(onDay(given), calendar(given)),
  daily_pace: (given) => dailyPace(onDay(given), calendar(given)),
  today_ring: (given) => todayRing(onDay(given), calendar(given)),
  goal_list_placement: (given) =>
    placeGoals(given["goals"] as PlacedGoal[], given["order"] as string[], given["date"] as string, calendar(given)),
  goal_order_merge: (given) =>
    mergeGoalOrder(
      given["base"] as GoalOrderDocument,
      given["mine"] as GoalOrderDocument,
      given["theirs"] as GoalOrderDocument,
    ),
};

test("every goal-model fixture file has a check, and every check a file", () => {
  expect(fixtures.map((fixture) => fixture.rule).sort()).toEqual(Object.keys(CHECKS).sort());
  for (const fixture of fixtures) expect(fixture.format).toBe("awrad-fixture/1");
});

for (const fixture of fixtures) {
  describe(fixture.rule, () => {
    test.each(fixture.cases.map((testCase) => [testCase.id, testCase] as const))("%s", (_id, testCase) => {
      const check = CHECKS[fixture.rule];
      if (check === undefined) throw new Error(`no check for ${fixture.rule}`);
      expect(check(testCase.given)).toEqual(testCase.expect);
    });
  });
}
