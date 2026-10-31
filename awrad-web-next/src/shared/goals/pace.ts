import type { HijriCorrection } from "@/shared/practice";
import { countsOn, goalTotal, indexCounts, type CountIndex } from "./counts";
import { day } from "./days";
import { inActive, isDue, lastDay } from "./schedule";
import type { GoalCalendar, GoalInput, GoalOnDay } from "./types";
import { resolve } from "./versions";

/**
 * Daily pace (daily_pace.json, decision 28): a total goal with an end, spread over the due days
 * left. What's left before the day, divided by the due days from the day to the last one, rounded
 * up, so the goal finishes on time. It leaves out the day's own counts, so it holds while counting.
 * Each day is judged by the end its version had then, even after the goal ended early.
 */
export interface DailyPace {
  /** `null` without an end, when the day isn't due, or for a goal that isn't a total (or has sessions). */
  pace: number | null;
  remaining: number | null;
  due_days_left: number | null;
}

const NO_PACE: DailyPace = { pace: null, remaining: null, due_days_left: null };

export function paceOn(
  input: GoalInput,
  counts: CountIndex,
  n: number,
  corrections: readonly HijriCorrection[],
): DailyPace {
  const goal = resolve(input, n, { capEnded: false });
  if (goal.requirement.type !== "cumulative_total" || goal.sessions.length > 0) return NO_PACE;
  const start = day(goal.active_period.start_date);
  let before = 0;
  for (let m = start; m < n; m += 1) {
    if (inActive(goal.active_period, m)) before += goalTotal(goal, countsOn(counts, m));
  }
  const remaining = Math.max(0, (goal.count_policy.target ?? 0) - before);
  const last = lastDay(goal.active_period);
  if (last === null) return { pace: null, remaining, due_days_left: null };
  let left = 0;
  for (let m = Math.max(n, start); m <= last; m += 1) {
    if (isDue(resolve(input, m, { capEnded: false }), m, corrections)) left += 1;
  }
  const pace = isDue(goal, n, corrections) && left > 0 ? Math.ceil(remaining / left) : null;
  return { pace, remaining, due_days_left: left };
}

/** daily_pace: the pace on `date`. */
export function dailyPace(
  { goal, counts, date }: GoalOnDay,
  { hijriCorrections }: Pick<GoalCalendar, "hijriCorrections">,
): DailyPace {
  return paceOn(goal, indexCounts(counts), day(date), hijriCorrections);
}
