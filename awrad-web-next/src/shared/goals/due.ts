import { day } from "./days";
import { isDue } from "./schedule";
import type { GoalCalendar, GoalInput } from "./types";
import { resolve } from "./versions";

/**
 * goal_is_due: whether a goal is due on `date`: on its schedule (by the version in force that
 * day), inside its active period, and neither paused nor excused.
 */
export function goalIsDue(
  goal: GoalInput,
  date: string,
  { hijriCorrections }: Pick<GoalCalendar, "hijriCorrections">,
): boolean {
  const n = day(date);
  return isDue(resolve(goal, n), n, hijriCorrections);
}
