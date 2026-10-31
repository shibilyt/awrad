import { hijriMonthOn, type HijriCorrection } from "@/shared/practice";
import { day, daysInMonth, earlier, gregorianParts, iso, weekdayOf, type Span } from "./days";
import type { ActivePeriod, Goal, MonthDay, Schedule, YearlyRange, YearlySchedule } from "./types";

/**
 * Whether a goal is due on a day (goal_is_due.json): on its schedule, inside its active period,
 * and neither paused nor excused. Hijri schedules read the shared Umm al-Qura table with the
 * account's corrections, and are never due outside it.
 */

/** The active period's last day: the earlier of its end date and its number of days; `null` for none. */
export function lastDay(period: ActivePeriod): number | null {
  const end = period.end_date === null ? null : day(period.end_date);
  const byDuration = period.duration_days === null ? null : day(period.start_date) + period.duration_days - 1;
  return earlier(end, byDuration);
}

export function inActive(period: ActivePeriod, n: number): boolean {
  const last = lastDay(period);
  return n >= day(period.start_date) && (last === null || n <= last);
}

/** A span cut to the active period, or `null` when nothing of it is left. */
export function clip(span: Span, period: ActivePeriod): Span | null {
  const first = Math.max(span.first, day(period.start_date));
  const last = earlier(span.last, lastDay(period)) ?? span.last;
  return first > last ? null : { first, last };
}

export function isPaused(goal: Goal, n: number): boolean {
  return goal.paused.some((p) => n >= day(p.from) && (p.to === null || n <= day(p.to)));
}

export function isExcused(goal: Goal, n: number): boolean {
  return goal.excused.includes(iso(n));
}

/** A month day, or the month's last day for days past its end (31 in April, Hijri 30 in a 29-day month). */
function onMonthDay(days: readonly number[], date: number, length: number): boolean {
  return days.includes(date) || (date === length && days.some((d) => d > date));
}

const tuple = (md: MonthDay): number => md.month * 100 + md.day;

/** A range boundary in this month, a day past the month's end falling on its last day. */
function clamp(boundary: MonthDay, md: MonthDay, length: number): number {
  return boundary.month === md.month ? boundary.month * 100 + Math.min(boundary.day, length) : tuple(boundary);
}

function inRange(range: YearlyRange, md: MonthDay, length: number): boolean {
  const afterStart = clamp(range.start, md, length) <= tuple(md);
  const beforeEnd = tuple(md) <= clamp(range.end, md, length);
  return tuple(range.end) < tuple(range.start) ? afterStart || beforeEnd : afterStart && beforeEnd;
}

interface YearlyMatch {
  range: YearlyRange;
  md: MonthDay;
  year: number;
  length: number;
}

/** The range a day falls in, in the schedule's own calendar, with that calendar's date. */
function yearlyMatch(schedule: YearlySchedule, n: number, corrections: readonly HijriCorrection[]): YearlyMatch | null {
  let year: number, md: MonthDay, length: number;
  if (schedule.calendar === "gregorian") {
    const date = gregorianParts(n);
    year = date.year;
    md = { month: date.month, day: date.day };
    length = daysInMonth(date.year, date.month);
  } else {
    const month = hijriMonthOn(n, corrections);
    if (month === null) return null;
    year = month.year;
    md = { month: month.month, day: n - month.start + 1 };
    length = month.length;
  }
  const range = schedule.ranges.find((r) => inRange(r, md, length));
  return range === undefined ? null : { range, md, year, length };
}

/**
 * The occasion a due day of a yearly schedule belongs to: its year in the schedule's calendar,
 * where a range over the year end belongs to the year it starts in.
 */
export function occasionOf(schedule: YearlySchedule, n: number, corrections: readonly HijriCorrection[]): number {
  const match = yearlyMatch(schedule, n, corrections);
  if (match === null) throw new Error(`${iso(n)} isn't on the yearly schedule`);
  const { range, md, year, length } = match;
  const wraps = tuple(range.end) < tuple(range.start);
  return wraps && tuple(md) <= clamp(range.end, md, length) ? year - 1 : year;
}

function scheduled(schedule: Schedule, start: string, n: number, corrections: readonly HijriCorrection[]): boolean {
  switch (schedule.kind) {
    case "every_day":
    case "one_time":
      return true;
    case "weekdays":
      return schedule.weekdays.includes(weekdayOf(n));
    case "every_n_days": {
      const since = n - day(schedule.anchor_date ?? start);
      return since >= 0 && since % schedule.every === 0;
    }
    case "month_days": {
      const date = gregorianParts(n);
      return onMonthDay(schedule.days, date.day, daysInMonth(date.year, date.month));
    }
    case "specific_dates":
      return schedule.dates.includes(iso(n));
    case "hijri_month_days": {
      const month = hijriMonthOn(n, corrections);
      return month !== null && onMonthDay(schedule.days, n - month.start + 1, month.length);
    }
    case "yearly":
      return yearlyMatch(schedule, n, corrections) !== null;
  }
}

/** On the schedule inside the active period, paused or not. */
export function inSchedule(goal: Goal, n: number, corrections: readonly HijriCorrection[]): boolean {
  return inActive(goal.active_period, n) && scheduled(goal.schedule, goal.active_period.start_date, n, corrections);
}

export function isDue(goal: Goal, n: number, corrections: readonly HijriCorrection[]): boolean {
  return inSchedule(goal, n, corrections) && !isPaused(goal, n) && !isExcused(goal, n);
}
