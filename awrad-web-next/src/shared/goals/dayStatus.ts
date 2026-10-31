import type { HijriCorrection } from "@/shared/practice";
import { judging, type Judging } from "./context";
import { allOf, countsOn, dailyTarget, unitCount, unitsOf, type CountIndex, type DayCounts } from "./counts";
import { day, earlier, iso } from "./days";
import { paceOn } from "./pace";
import { inActive, isDue, isExcused, isPaused, lastDay } from "./schedule";
import type { CountPolicy, GoalCalendar, GoalInput, GoalOnDay, MakeUpWindow } from "./types";
import { resolve } from "./versions";

/**
 * Each due day's status, with make-up (make_up.json, decisions 18, 31, 46 and 48), and the
 * streak amount a day needs (README "Streaks").
 */

export type DayStatus = "met" | "minimum_only" | "made_up" | "pending" | "missed" | "in_progress";

/** Statuses that keep the streak. */
export const KEPT: ReadonlySet<DayStatus> = new Set(["met", "minimum_only", "made_up"]);
/** Not settled yet: today, or a missed day whose make-up window is still open. Neither breaks nor adds. */
export const OPEN: ReadonlySet<DayStatus> = new Set(["in_progress", "pending"]);
/** A day with sessions takes its worst session's status, in this order. */
const WORST_FIRST: readonly DayStatus[] = ["in_progress", "missed", "pending", "made_up", "minimum_only", "met"];
const WINDOW_DAYS: Record<MakeUpWindow, number> = { off: 0, next_day: 1, within_3_days: 3 };

/** The number a day needs for the streak: 1 for any count, a policy value, an amount, or that day's pace. */
export function streakAmount(
  input: GoalInput,
  counts: CountIndex,
  policy: CountPolicy,
  n: number,
  corrections: readonly HijriCorrection[],
): number {
  const threshold = policy.streak_threshold;
  if (typeof threshold === "object") return threshold.amount;
  switch (threshold) {
    case "any_count":
      return 1;
    case "daily_pace":
      return Math.max(1, paceOn(input, counts, n, corrections).pace ?? 1);
    case "minimum":
    case "target":
    case "maximum":
      return policy[threshold] ?? 0;
  }
}

interface UnitDay {
  id: string | null;
  /** The day's own target, if it has one. */
  target: number | null;
  streak: number;
  count: number;
  /** What make-up fills it to. */
  fillTo: number;
  filled: number;
}

interface DueDay {
  n: number;
  window: number;
  units: UnitDay[];
}

export interface DayResult {
  status: DayStatus;
  count: number;
  filled: number;
}

function dueDays(j: Judging, first: number, last: number): DueDay[] {
  const days: DueDay[] = [];
  for (let n = first; n <= last; n += 1) {
    const goal = resolve(j.input, n);
    if (!isDue(goal, n, j.corrections)) continue;
    const counts = countsOn(j.counts, n);
    const units = unitsOf(goal).map(({ id, policy }): UnitDay => {
      const target = dailyTarget(goal, policy);
      const streak = streakAmount(j.input, j.counts, policy, n, j.corrections);
      const fillTo = goal.make_up.fill === "streak" ? streak : Math.max(target ?? 0, streak);
      return { id, target, streak, count: unitCount(goal, counts, id), fillTo, filled: 0 };
    });
    days.push({ n, window: WINDOW_DAYS[goal.make_up.window], units });
  }
  return days;
}

/** What a day gives to make-up: past its own needs when due, all its counts when not. */
function surplusOf(due: DueDay | undefined, counts: DayCounts, id: string | null): number {
  if (due === undefined) return id === null ? allOf(counts) : (counts.get(id) ?? 0);
  const unit = due.units.find((u) => u.id === id);
  return unit === undefined ? 0 : Math.max(0, unit.count - Math.max(unit.target ?? 0, unit.streak));
}

/** Counts past what a later day needs fill missed days in their window, oldest first. */
function fillMissedDays(j: Judging, days: readonly DueDay[], first: number, last: number): void {
  const byDay = new Map(days.map((d) => [d.n, d]));
  for (let e = first; e <= last; e += 1) {
    const goal = resolve(j.input, e);
    if (!inActive(goal.active_period, e) || isPaused(goal, e) || isExcused(goal, e)) continue;
    const counts = countsOn(j.counts, e);
    const due = byDay.get(e);
    const surplus = new Map<string | null, number>();
    for (let m = e - WINDOW_DAYS.within_3_days; m < e; m += 1) {
      const missed = byDay.get(m);
      if (missed === undefined || e - m > missed.window) continue;
      for (const unit of missed.units) {
        const deficit = unit.fillTo - unit.count - unit.filled;
        if (deficit <= 0) continue;
        const left = surplus.get(unit.id) ?? surplusOf(due, counts, unit.id);
        const give = Math.min(deficit, left);
        unit.filled += give;
        surplus.set(unit.id, left - give);
      }
    }
  }
}

function unitStatus(unit: UnitDay, due: DueDay, today: number, running: boolean): DayStatus {
  if (unit.count >= unit.streak && (unit.target === null || unit.count >= unit.target)) return "met";
  if (unit.filled > 0 && unit.count + unit.filled >= unit.fillTo) return "made_up";
  if (unit.count >= unit.streak) return "minimum_only";
  if (due.n === today) return "in_progress";
  return due.window > 0 && today <= due.n + due.window && running ? "pending" : "missed";
}

/** The status of every due day from the start date to the judged day (or the goal's last day). */
export function dayStatuses(j: Judging): Map<number, DayResult> {
  const period = resolve(j.input, j.today).active_period;
  const first = day(period.start_date);
  const end = lastDay(period);
  const last = earlier(j.today, end) ?? j.today;
  const running = end === null || j.today <= end;
  const days = dueDays(j, first, last);
  fillMissedDays(j, days, first, last);
  const result = new Map<number, DayResult>();
  for (const due of days) {
    const statuses = due.units.map((unit) => unitStatus(unit, due, j.today, running));
    const status = WORST_FIRST.find((s) => statuses.includes(s)) ?? "met";
    const count = due.units.reduce((total, u) => total + u.count, 0);
    const filled = due.units.reduce((total, u) => total + u.filled, 0);
    result.set(due.n, { status, count, filled });
  }
  return result;
}

/** The days pending make-up, oldest first. */
export function pendingDays(statuses: ReadonlyMap<number, DayResult>): string[] {
  return [...statuses.entries()].filter(([, s]) => s.status === "pending").map(([n]) => iso(n));
}

export interface MakeUpDay extends DayResult {
  date: string;
}

/** make_up: each due day's status from `from` to `date`. */
export function makeUpDays(
  goalOnDay: GoalOnDay,
  from: string,
  { hijriCorrections }: Pick<GoalCalendar, "hijriCorrections">,
): MakeUpDay[] {
  const start = day(from);
  return [...dayStatuses(judging(goalOnDay, hijriCorrections)).entries()]
    .filter(([n]) => n >= start)
    .map(([n, s]) => ({ date: iso(n), ...s }));
}
