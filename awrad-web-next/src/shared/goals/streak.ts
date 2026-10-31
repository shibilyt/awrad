import type { WeekStart } from "@/shared/practice";
import { judging, type Judging } from "./context";
import { dayStatuses, KEPT, OPEN, pendingDays, type DayResult } from "./dayStatus";
import { periodsBack } from "./periods";
import { inSchedule, isPaused, lastDay, occasionOf } from "./schedule";
import type { Goal, GoalCalendar, GoalOnDay, Schedule, Weekday, YearlySchedule } from "./types";
import { resolve } from "./versions";

/**
 * Streaks in the goal's rhythm (goal_streak.json, decision 43) and consistency tags
 * (consistency.json, decisions 19, 21 and 32).
 */

export type StreakUnit = "day" | "weekday" | "week" | "month" | "occasion";

/** The unit a goal's streak counts in, from the version in force today. */
export function streakUnit(goal: Goal): { unit: StreakUnit; weekday: Weekday | null } {
  const { requirement, schedule } = goal;
  if (requirement.type === "period_total" || requirement.type === "days_per_period") {
    return { unit: requirement.period === "week" ? "week" : "month", weekday: null };
  }
  if (schedule.kind === "yearly") return { unit: "occasion", weekday: null };
  const [only] = schedule.kind === "weekdays" && schedule.weekdays.length === 1 ? schedule.weekdays : [];
  return only === undefined ? { unit: "day", weekday: null } : { unit: "weekday", weekday: only };
}

/** How far ahead an occasion still in progress is looked for (and placement's horizon). */
export const HORIZON_DAYS = 400;

function yearly(schedule: Schedule): YearlySchedule {
  if (schedule.kind !== "yearly") throw new Error("an occasion goal's schedule is yearly in every version");
  return schedule;
}

interface Occasion {
  days: number[];
  inProgress: boolean;
  kept: boolean;
}

/** Whether the current occasion has a due day still to come. */
function occasionContinues(j: Judging, key: number): boolean {
  for (let n = j.today + 1; n <= j.today + HORIZON_DAYS; n += 1) {
    const goal = resolve(j.input, n);
    const last = lastDay(goal.active_period);
    if (last !== null && n > last) return false;
    if (inSchedule(goal, n, j.corrections) && !isPaused(goal, n)) {
      return occasionOf(yearly(goal.schedule), n, j.corrections) === key;
    }
  }
  return false;
}

/** An occasion goal's occasions, newest first. */
function occasionsBack(j: Judging, statuses: ReadonlyMap<number, DayResult>): Occasion[] {
  const groups: { key: number; days: number[] }[] = [];
  for (const n of [...statuses.keys()].sort((a, b) => b - a)) {
    const key = occasionOf(yearly(resolve(j.input, n).schedule), n, j.corrections);
    const group = groups.at(-1);
    if (group?.key === key) group.days.push(n);
    else groups.push({ key, days: [n] });
  }
  const last = lastDay(resolve(j.input, j.today).active_period);
  const running = last === null || j.today <= last;
  const isKept = (n: number) => KEPT.has(statuses.get(n)?.status ?? "missed");
  const isOpen = (n: number) => OPEN.has(statuses.get(n)?.status ?? "missed");
  return groups.map(({ key, days }, i) => ({
    days,
    inProgress: i === 0 && running && (days.some(isOpen) || occasionContinues(j, key)),
    kept: days.every(isKept),
  }));
}

/** The current streak: kept units back from today; open ones neither break nor add. */
export function currentStreak(j: Judging, weekStart: WeekStart, statuses = dayStatuses(j)): number {
  const { unit } = streakUnit(resolve(j.input, j.today));
  let current = 0;
  if (unit === "week" || unit === "month") {
    for (const period of periodsBack(j, weekStart)) {
      if (period.met) current += 1;
      else if (!period.inProgress) break;
    }
  } else if (unit === "occasion") {
    for (const occasion of occasionsBack(j, statuses)) {
      if (occasion.inProgress) continue;
      if (!occasion.kept) break;
      current += 1;
    }
  } else {
    for (const n of [...statuses.keys()].sort((a, b) => b - a)) {
      const status = statuses.get(n)?.status ?? "missed";
      if (KEPT.has(status)) current += 1;
      else if (!OPEN.has(status)) break;
    }
  }
  return current;
}

export interface GoalStreak {
  current: number;
  unit: StreakUnit;
  /** The weekday, for the `weekday` unit ("🔥 12 Fridays"). */
  weekday: Weekday | null;
  /** Days pending make-up, oldest first ("make up Mon"). */
  pending_make_up: string[];
}

/** goal_streak: the current streak, its unit, and the days pending make-up. */
export function goalStreak(goalOnDay: GoalOnDay, { weekStart, hijriCorrections }: GoalCalendar): GoalStreak {
  const j = judging(goalOnDay, hijriCorrections);
  const statuses = dayStatuses(j);
  return {
    current: currentStreak(j, weekStart, statuses),
    ...streakUnit(resolve(j.input, j.today)),
    pending_make_up: pendingDays(statuses),
  };
}

export type ConsistencyTag = "devoted" | "steady";

export interface Consistency {
  basis: "due_days" | "periods";
  met: number;
  out_of: number;
  tag: ConsistencyTag | null;
  /** What a row shows: 🔥 and the streak, the tag ("Steady · 25/30"), or nothing. */
  show: "streak" | "consistency" | "none";
}

const DUE_DAYS_WINDOW = 30;
const PERIODS_WINDOW = 12;
const DUE_DAYS_FOR_A_TAG = 7;
const PERIODS_FOR_A_TAG = 4;
/** From this streak on, the row shows it rather than the tag. */
const STREAK_SHOWN_FROM = 3;

function tagFor(met: number, outOf: number, enough: boolean): ConsistencyTag | null {
  if (!enough) return null;
  if (met * 10 >= outOf * 9) return "devoted";
  return met * 10 >= outOf * 8 ? "steady" : null;
}

/**
 * consistency: kept due days among the last 30 (periods met among the last 12), the tag, and
 * what the row shows. Today, or the current period, counts only once kept or met, and a day
 * pending make-up only once its window closes.
 */
export function consistency(goalOnDay: GoalOnDay, { weekStart, hijriCorrections }: GoalCalendar): Consistency {
  const j = judging(goalOnDay, hijriCorrections);
  const statuses = dayStatuses(j);
  const { unit } = streakUnit(resolve(j.input, j.today));
  const basis = unit === "week" || unit === "month" ? "periods" : "due_days";
  let met = 0;
  let outOf = 0;
  if (basis === "periods") {
    for (const period of periodsBack(j, weekStart)) {
      if (outOf === PERIODS_WINDOW) break;
      if (period.inProgress && !period.met) continue;
      outOf += 1;
      if (period.met) met += 1;
    }
  } else {
    for (const n of [...statuses.keys()].sort((a, b) => b - a)) {
      if (outOf === DUE_DAYS_WINDOW) break;
      const status = statuses.get(n)?.status ?? "missed";
      if (OPEN.has(status)) continue;
      outOf += 1;
      if (KEPT.has(status)) met += 1;
    }
  }
  const tag = tagFor(met, outOf, outOf >= (basis === "periods" ? PERIODS_FOR_A_TAG : DUE_DAYS_FOR_A_TAG));
  const streak = currentStreak(j, weekStart, statuses);
  let show: Consistency["show"] = "none";
  if (streak >= STREAK_SHOWN_FROM) show = "streak";
  else if (tag !== null) show = "consistency";
  else if (streak >= 1) show = "streak";
  return { basis, met, out_of: outOf, tag, show };
}
