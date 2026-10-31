import type { WeekStart } from "@/shared/practice";
import { judging, type Judging } from "./context";
import { countsOn, goalTotal, indexCounts, type CountIndex } from "./counts";
import { streakAmount } from "./dayStatus";
import { day, daysOf, periodOf } from "./days";
import { paceOn } from "./pace";
import { progressMet, progressOver } from "./periods";
import { clip, inActive, isDue, lastDay } from "./schedule";
import type { Goal, GoalCalendar, GoalOnDay, Session } from "./types";
import { resolve } from "./versions";

/** Today's ring (today_ring.json, decision 33) and derived completion (goal_completion.json). */

export interface TodayRing {
  /** What the ring fills toward; `none` draws no ring. */
  ring: "target" | "period_target" | "pace" | "streak_amount" | "none";
  progress: number;
  goal: number | null;
}

/** Sessions' targets combined, each session counting up to its own. */
function sessionsRing(
  sessions: readonly Session[],
  progressOf: (s: Session) => number,
): { progress: number; goal: number } {
  return {
    progress: sessions.reduce((total, s) => total + Math.min(progressOf(s), s.target ?? 0), 0),
    goal: sessions.reduce((total, s) => total + (s.target ?? 0), 0),
  };
}

/** A period total's ring: the week or month so far. `null` when the period has no due day. */
function periodRing(j: Judging, goal: Goal, weekStart: WeekStart): TodayRing | null {
  if (goal.requirement.type !== "period_total" || !inActive(goal.active_period, j.today)) return null;
  const span = periodOf(j.today, goal.requirement.period, weekStart, j.corrections);
  const window = span === null ? null : clip(span, goal.active_period);
  if (window === null || !daysOf(window).some((n) => isDue(resolve(j.input, n), n, j.corrections))) return null;
  const days = daysOf(window).filter((n) => n <= j.today);
  const progress = progressOver(goal, j.counts, days);
  if (goal.sessions.length === 0) {
    return { ring: "period_target", progress: progress.progress, goal: goal.count_policy.target };
  }
  const byId = new Map(progress.sessions.map((s) => [s.id, s.progress]));
  return { ring: "period_target", ...sessionsRing(goal.sessions, (s) => byId.get(s.id) ?? 0) };
}

/** A due day's ring for goals that aren't period totals. */
function dayRing(j: Judging, goal: Goal, total: number): TodayRing {
  const counts = countsOn(j.counts, j.today);
  const policy = goal.count_policy;
  switch (goal.requirement.type) {
    case "per_due_date":
    case "days_per_period":
      if (goal.sessions.length === 0) return { ring: "target", progress: total, goal: policy.target };
      return { ring: "target", ...sessionsRing(goal.sessions, (s) => counts.get(s.id) ?? 0) };
    case "cumulative_total": {
      if (policy.streak_threshold === "daily_pace") {
        const pace = paceOn(j.input, j.counts, j.today, j.corrections).pace;
        return { ring: "pace", progress: total, goal: Math.max(1, pace ?? 1) };
      }
      return {
        ring: "streak_amount",
        progress: total,
        goal: streakAmount(j.input, j.counts, policy, j.today, j.corrections),
      };
    }
    case "tracker":
    case "period_total": {
      const none: TodayRing = { ring: "none", progress: total, goal: null };
      if (policy.streak_threshold === "any_count") return none;
      const amount = streakAmount(j.input, j.counts, policy, j.today, j.corrections);
      return total < amount ? { ring: "streak_amount", progress: total, goal: amount } : none;
    }
  }
}

/**
 * today_ring: what a list ring fills toward today. Daily goals and N days a period: today's
 * target; period totals: the week or month so far; totals: their streak amount (the pace with
 * `daily_pace`); trackers: their number until it's reached. Nothing when today isn't due.
 */
export function todayRing(goalOnDay: GoalOnDay, { weekStart, hijriCorrections }: GoalCalendar): TodayRing {
  const j = judging(goalOnDay, hijriCorrections);
  const goal = resolve(j.input, j.today);
  const total = goalTotal(goal, countsOn(j.counts, j.today));
  const none: TodayRing = { ring: "none", progress: total, goal: null };
  if (goal.requirement.type === "period_total") return periodRing(j, goal, weekStart) ?? none;
  return isDue(goal, j.today, j.corrections) ? dayRing(j, goal, total) : none;
}

/** Whether a single-version goal is complete by its completion policy on day `n`. */
export function completedOn(goal: Goal, counts: CountIndex, n: number): boolean {
  const last = lastDay(goal.active_period);
  switch (goal.completion) {
    case "never":
      return false;
    case "when_duration_ended":
      return last !== null && n > last;
    case "when_target_reached": {
      const start = day(goal.active_period.start_date);
      if (goal.requirement.type !== "cumulative_total" || n < start) return false;
      const days = daysOf({ first: start, last: n }).filter((m) => inActive(goal.active_period, m));
      return progressMet(goal, progressOver(goal, counts, days));
    }
  }
}

/** goal_completion: derived completion on `date`, by the version in force that day. */
export function goalCompletion({ goal, counts, date }: GoalOnDay): boolean {
  const n = day(date);
  return completedOn(resolve(goal, n), indexCounts(counts), n);
}
