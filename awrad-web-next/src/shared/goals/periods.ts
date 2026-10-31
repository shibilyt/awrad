import { hijriTableEnd, type WeekStart } from "@/shared/practice";
import { judging, type Judging } from "./context";
import { countsOn, dayMetTarget, goalTotal, meetsTarget, type CountIndex } from "./counts";
import { day, daysOf, earlier, iso, periodOf, type Span } from "./days";
import { clip, inActive, isDue, lastDay } from "./schedule";
import type { Goal, GoalCalendar, GoalOnDay, Period, Requirement } from "./types";
import { resolve } from "./versions";

/**
 * Weeks and months: requirement standing (requirement_standing.json), days per period
 * (days_per_period.json), and walking back over a period goal's weeks or months for its streak.
 */

export interface SessionStanding {
  id: string;
  progress: number;
  target: number | null;
  status: "met" | "not_met";
}

interface Progress {
  progress: number;
  sessions: SessionStanding[];
}

/** Counts over some days: the goal's total, and each session's against its target. */
export function progressOver(goal: Goal, counts: CountIndex, days: readonly number[]): Progress {
  const progress = days.reduce((total, n) => total + goalTotal(goal, countsOn(counts, n)), 0);
  const sessions = goal.sessions.map((session): SessionStanding => {
    const sum = days.reduce((total, n) => total + (countsOn(counts, n).get(session.id) ?? 0), 0);
    return {
      id: session.id,
      progress: sum,
      target: session.target,
      status: meetsTarget(sum, session.target) ? "met" : "not_met",
    };
  });
  return { progress, sessions };
}

/** Met: the total reaches the target (any count for a tracker), or every session met its own. */
export function progressMet(goal: Goal, { progress, sessions }: Progress): boolean {
  if (goal.sessions.length > 0) return sessions.every((s) => s.status === "met");
  return meetsTarget(progress, goal.requirement.type === "tracker" ? null : goal.count_policy.target);
}

function periodOfRequirement(requirement: Requirement): Period | null {
  return requirement.type === "period_total" || requirement.type === "days_per_period" ? requirement.period : null;
}

interface Tally {
  qualifying: number;
  required: number;
}

/**
 * Days per period over a window: qualifying due days up to the judged day, against the required
 * days, which excused days lower and the window's due days cap.
 */
function tally(j: Judging, window: Span): Tally {
  const goal = resolve(j.input, Math.min(window.last, j.today));
  const days = daysOf(window);
  const due = days.filter((n) => isDue(resolve(j.input, n), n, j.corrections));
  const qualifying = due.filter((n) => n <= j.today && dayMetTarget(resolve(j.input, n), countsOn(j.counts, n)));
  const excused = days.filter((n) => goal.excused.includes(iso(n))).length;
  const needed = goal.requirement.type === "days_per_period" ? goal.requirement.days : 0;
  return { qualifying: qualifying.length, required: Math.max(0, Math.min(needed - excused, due.length)) };
}

/** Whether a week or month met the requirement, judged by the version in force on its last day so far. */
function windowMet(j: Judging, window: Span): boolean {
  const goal = resolve(j.input, Math.min(window.last, j.today));
  if (goal.requirement.type === "days_per_period") {
    const { qualifying, required } = tally(j, window);
    return qualifying >= required;
  }
  const days = daysOf(window).filter((n) => n <= j.today && inActive(goal.active_period, n));
  return progressMet(goal, progressOver(goal, j.counts, days));
}

export interface PeriodResult {
  window: Span;
  inProgress: boolean;
  met: boolean;
}

/** A period goal's weeks or months with due days, newest first, up to the judged day. */
export function* periodsBack(j: Judging, weekStart: WeekStart): Generator<PeriodResult> {
  const goal = resolve(j.input, j.today);
  const unit = periodOfRequirement(goal.requirement);
  if (unit === null) return;
  let last = earlier(j.today, lastDay(goal.active_period)) ?? j.today;
  if (last < day(goal.active_period.start_date)) return;
  if (unit === "hijri_month") last = Math.min(last, hijriTableEnd(j.corrections) - 1);
  let period = periodOf(last, unit, weekStart, j.corrections);
  while (period !== null) {
    const window = clip(period, goal.active_period);
    if (window === null) return;
    const hasDue = daysOf(window).some((n) => isDue(resolve(j.input, n), n, j.corrections));
    const required = goal.requirement.type === "days_per_period" && hasDue ? tally(j, window).required : 1;
    if (hasDue && required > 0) yield { window, inProgress: window.last >= j.today, met: windowMet(j, window) };
    period = periodOf(period.first - 1, unit, weekStart, j.corrections);
  }
}

export interface RequirementStanding {
  status: "met" | "not_met" | "not_due";
  window: { from: string; to: string };
  progress: number;
  /** `null` with sessions (each has its own) and for trackers. */
  target: number | null;
  sessions: SessionStanding[];
}

/** The days a requirement is judged over on a day, or `null` outside the active period. */
function standingWindow(j: Judging, goal: Goal, weekStart: WeekStart): Span | null {
  const period = goal.active_period;
  if (!inActive(period, j.today)) return null;
  switch (goal.requirement.type) {
    case "cumulative_total":
      return { first: day(period.start_date), last: j.today };
    case "period_total": {
      const span = periodOf(j.today, goal.requirement.period, weekStart, j.corrections);
      return span === null ? null : clip(span, period);
    }
    case "per_due_date":
    case "tracker":
    case "days_per_period":
      return { first: j.today, last: j.today };
  }
}

/**
 * requirement_standing: the window, progress, target and status on a day. Days per period are
 * judged here by that day against the daily target; `daysPerPeriod` judges the period.
 */
export function requirementStanding(
  goalOnDay: GoalOnDay,
  { weekStart, hijriCorrections }: GoalCalendar,
): RequirementStanding {
  const j = judging(goalOnDay, hijriCorrections);
  const goal = resolve(j.input, j.today);
  let window = standingWindow(j, goal, weekStart);
  let due = window !== null;
  if (window !== null && goal.requirement.type === "period_total") {
    due = daysOf(window).some((n) => isDue(goal, n, j.corrections));
  } else if (window !== null && goal.requirement.type !== "cumulative_total") {
    due = isDue(goal, j.today, j.corrections);
  }
  if (!due || window === null) window = { first: j.today, last: j.today };
  const days = daysOf(window).filter((n) => n <= j.today && inActive(goal.active_period, n));
  const progress = progressOver(goal, j.counts, days);
  return {
    status: due ? (progressMet(goal, progress) ? "met" : "not_met") : "not_due",
    window: { from: iso(window.first), to: iso(window.last) },
    progress: progress.progress,
    target: goal.sessions.length === 0 && goal.requirement.type !== "tracker" ? goal.count_policy.target : null,
    sessions: progress.sessions,
  };
}

export interface DaysPerPeriod {
  status: "met" | "not_met" | "not_due";
  window: { from: string; to: string };
  qualifying_days: number;
  required_days: number;
}

/** days_per_period: qualifying days in the day's week or month against the days it requires. */
export function daysPerPeriod(goalOnDay: GoalOnDay, { weekStart, hijriCorrections }: GoalCalendar): DaysPerPeriod {
  const j = judging(goalOnDay, hijriCorrections);
  const goal = resolve(j.input, j.today);
  const date = iso(j.today);
  const notDue: DaysPerPeriod = {
    status: "not_due",
    window: { from: date, to: date },
    qualifying_days: 0,
    required_days: 0,
  };
  const unit = periodOfRequirement(goal.requirement);
  if (unit === null || !inActive(goal.active_period, j.today)) return notDue;
  const span = periodOf(j.today, unit, weekStart, j.corrections);
  const window = span === null ? null : clip(span, goal.active_period);
  if (window === null) return notDue;
  const { qualifying, required } = tally(j, window);
  if (required <= 0) return notDue;
  return {
    status: qualifying >= required ? "met" : "not_met",
    window: { from: iso(window.first), to: iso(window.last) },
    qualifying_days: qualifying,
    required_days: required,
  };
}
