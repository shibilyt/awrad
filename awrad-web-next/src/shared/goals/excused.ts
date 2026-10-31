import { judging } from "./context";
import { countsOn, dayMetTarget } from "./counts";
import { dayStatuses, KEPT } from "./dayStatus";
import { day } from "./days";
import { isDue, lastDay } from "./schedule";
import type { GoalCalendar, GoalOnDay } from "./types";
import { endedOf, resolve } from "./versions";

/**
 * Excused days (excused_days.json, decision 20): whether a day can be excused or un-excused, and
 * why not. The checks run in the README's order; the reason is the first that fails.
 */

export type ExcuseRefusal =
  | "goal_finished"
  | "not_past"
  | "already_excused"
  | "not_available"
  | "not_due"
  | "not_missed"
  | "limit_reached"
  | "not_excused";

export type ExcuseAnswer = { allowed: true; reason: null } | { allowed: false; reason: ExcuseRefusal };

/** At most this many excused days in one Gregorian month. */
export const EXCUSED_PER_MONTH = 2;

const ALLOWED: ExcuseAnswer = { allowed: true, reason: null };
const refused = (reason: ExcuseRefusal): ExcuseAnswer => ({ allowed: false, reason });

/**
 * Whether `excusedDay` can be excused (or, with `unexcuse`, un-excused) on `date`, today. A day
 * can be excused while the goal runs, before today, on a goal judged by day, when it was due
 * and not kept, and while its month has fewer than two.
 */
export function canExcuse(
  goalOnDay: GoalOnDay,
  excusedDay: string,
  action: "excuse" | "unexcuse",
  { hijriCorrections }: Pick<GoalCalendar, "hijriCorrections">,
): ExcuseAnswer {
  const j = judging(goalOnDay, hijriCorrections);
  const goal = resolve(j.input, j.today);
  const last = lastDay(goal.active_period);
  if (endedOf(j.input) !== null || (last !== null && j.today > last)) return refused("goal_finished");
  const { excused } = goal;
  if (action === "unexcuse") return excused.includes(excusedDay) ? ALLOWED : refused("not_excused");
  const x = day(excusedDay);
  if (x >= j.today) return refused("not_past");
  if (excused.includes(excusedDay)) return refused("already_excused");
  if (goal.requirement.type === "period_total") return refused("not_available");
  const then = resolve(j.input, x);
  if (!isDue(then, x, j.corrections)) return refused("not_due");
  const kept =
    then.requirement.type === "days_per_period"
      ? dayMetTarget(then, countsOn(j.counts, x))
      : KEPT.has(dayStatuses(j).get(x)?.status ?? "missed");
  if (kept) return refused("not_missed");
  const month = excusedDay.slice(0, 7);
  if (excused.filter((d) => d.startsWith(month)).length >= EXCUSED_PER_MONTH) return refused("limit_reached");
  return ALLOWED;
}
