import { compareText, day } from "./days";
import { lastDay } from "./schedule";
import type { Ended, Goal, GoalInput, GoalSettings, GoalTimeline, Schedule, Version, Weekday } from "./types";

/**
 * Dated versions (README "Dated versions", decision 23): editing never rewrites the past. Each
 * day is judged by the version in force that day.
 */

export function isTimeline(input: GoalInput): input is GoalTimeline {
  return "versions" in input;
}

export function endedOf(input: GoalInput): Ended | null {
  return isTimeline(input) ? input.ended : null;
}

export function createdOn(input: GoalInput): string {
  return isTimeline(input) ? input.created_on : input.active_period.start_date;
}

export function settingsOf(version: GoalSettings): GoalSettings {
  const { schedule, active_period, count_policy, sessions, requirement, completion, make_up } = version;
  return { schedule, active_period, count_policy, sessions, requirement, completion, make_up };
}

/** The index of the version in force on a day: the last one from on or before it, or the first. */
export function versionIndex(timeline: GoalTimeline, n: number): number {
  let found = 0;
  timeline.versions.forEach((version, i) => {
    if (day(version.from) <= n) found = i;
  });
  return found;
}

/**
 * The goal a rule evaluates on a day: that day's version with the goal's pauses and excused days.
 * An ended goal's active period ends on `ended.on` when its version ran longer, unless
 * `capEnded` is false (daily pace judges each day by the end its version had then).
 */
export function resolve(input: GoalInput, n: number, { capEnded = true }: { capEnded?: boolean } = {}): Goal {
  if (!isTimeline(input)) return input;
  const version = input.versions[versionIndex(input, n)];
  if (version === undefined) throw new Error("a goal timeline has no versions");
  const goal: Goal = { ...settingsOf(version), paused: input.paused, excused: input.excused };
  const { ended } = input;
  if (capEnded && ended !== null) {
    const last = lastDay(version.active_period);
    if (last === null || last > day(ended.on)) {
      goal.active_period = { ...version.active_period, end_date: ended.on, duration_days: null };
    }
  }
  return goal;
}

/** goal_version_on_day: the version in force on `date` and the goal it resolves into. */
export function versionOnDay(timeline: GoalTimeline, date: string): { version: number; goal: Goal } {
  const n = day(date);
  return { version: versionIndex(timeline, n), goal: resolve(timeline, n) };
}

/** Deep equality of JSON values, whatever the key order. */
export function sameJson(a: unknown, b: unknown): boolean {
  if (a === b) return true;
  if (typeof a !== "object" || typeof b !== "object" || a === null || b === null) return false;
  if (Array.isArray(a) !== Array.isArray(b)) return false;
  const aKeys = Object.keys(a);
  const bKeys = Object.keys(b);
  if (aKeys.length !== bKeys.length) return false;
  const aRecord = a as Record<string, unknown>;
  const bRecord = b as Record<string, unknown>;
  return aKeys.every((key) => key in bRecord && sameJson(aRecord[key], bRecord[key]));
}

const WEEK_ORDER: readonly Weekday[] = ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"];

/** A schedule with its weekdays, month days and dates in one order: they're sets. */
function canonicalSchedule(schedule: Schedule): Schedule {
  switch (schedule.kind) {
    case "weekdays":
      return {
        ...schedule,
        weekdays: [...schedule.weekdays].sort((a, b) => WEEK_ORDER.indexOf(a) - WEEK_ORDER.indexOf(b)),
      };
    case "month_days":
    case "hijri_month_days":
      return { ...schedule, days: [...schedule.days].sort((a, b) => a - b) };
    case "specific_dates":
      return { ...schedule, dates: [...schedule.dates].sort(compareText) };
    case "every_day":
    case "one_time":
    case "every_n_days":
    case "yearly":
      return schedule;
  }
}

/** Equal settings, weekdays, month days and dates compared regardless of order. */
export function sameSettings(a: GoalSettings, b: GoalSettings): boolean {
  return sameJson({ ...a, schedule: canonicalSchedule(a.schedule) }, { ...b, schedule: canonicalSchedule(b.schedule) });
}

/** The most versions a document keeps; the oldest folds into the next. */
export const MAX_VERSIONS = 100;

/**
 * goal_version_add: a detail edit saved as a version from `today`. Unchanged settings add
 * nothing (weekdays, month days and dates compare as sets); a second edit on the same day replaces today's version, and editing back to the
 * previous settings removes it; a 101st version folds the oldest into the next.
 */
export function addVersion(versions: readonly Version[], settings: GoalSettings, today: string): Version[] {
  const next = versions.map((version) => ({ ...version }));
  const last = next.at(-1);
  if (last === undefined) return [{ from: today, ...settings }];
  if (sameSettings(settingsOf(last), settings)) return next;
  if (day(last.from) >= day(today)) {
    next[next.length - 1] = { from: last.from, ...settings };
    const previous = next.at(-2);
    if (previous !== undefined && sameSettings(settingsOf(previous), settings)) next.pop();
  } else {
    next.push({ from: today, ...settings });
  }
  if (next.length > MAX_VERSIONS) {
    const oldest = next.shift();
    const second = next[0];
    if (oldest !== undefined && second !== undefined) next[0] = { ...second, from: oldest.from };
  }
  return next;
}
