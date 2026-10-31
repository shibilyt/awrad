import { compareText, day } from "./days";
import { resolve } from "./versions";
import type { CountEntry, CountLogEntry, CountPolicy, CountSource, Goal, GoalInput, Session } from "./types";

/**
 * A goal's counts by day and session, and count attribution (count_attribution.json): which
 * count-log entries fill which goal. Counts belong to the dhikr (root ADR-2026-10-31).
 */

/** One day's counts by session (`null` for counts without one). */
export type DayCounts = ReadonlyMap<string | null, number>;
/** Every day's counts, by day number. */
export type CountIndex = ReadonlyMap<number, DayCounts>;

const NO_COUNTS: DayCounts = new Map();

export function indexCounts(counts: readonly CountEntry[]): CountIndex {
  const index = new Map<number, Map<string | null, number>>();
  for (const entry of counts) {
    const n = day(entry.date);
    const sessions = index.get(n) ?? new Map<string | null, number>();
    sessions.set(entry.session, (sessions.get(entry.session) ?? 0) + entry.count);
    index.set(n, sessions);
  }
  return index;
}

export function countsOn(index: CountIndex, n: number): DayCounts {
  return index.get(n) ?? NO_COUNTS;
}

/** Every count of a day, whatever its session. */
export function allOf(counts: DayCounts): number {
  let total = 0;
  for (const count of counts.values()) total += count;
  return total;
}

/** A day's total for the goal: all of it, or with sessions only the goal's sessions. */
export function goalTotal(goal: Goal, counts: DayCounts): number {
  if (goal.sessions.length === 0) return allOf(counts);
  return goal.sessions.reduce((total, session) => total + (counts.get(session.id) ?? 0), 0);
}

/** A session's count policy: its target, which is also its streak amount (any count without one). */
export function sessionPolicy(session: Session): CountPolicy {
  return {
    minimum: null,
    target: session.target,
    maximum: null,
    streak_threshold: session.target === null ? "any_count" : "target",
  };
}

/** What a day is judged in: the whole day (`id` `null`) or each session. */
export interface Unit {
  id: string | null;
  policy: CountPolicy;
}

export function unitsOf(goal: Goal): Unit[] {
  if (goal.sessions.length === 0) return [{ id: null, policy: goal.count_policy }];
  return goal.sessions.map((session) => ({ id: session.id, policy: sessionPolicy(session) }));
}

export function unitCount(goal: Goal, counts: DayCounts, id: string | null): number {
  return id === null ? goalTotal(goal, counts) : (counts.get(id) ?? 0);
}

/** The day's own target, for goals judged by day; `null` for totals and trackers. */
export function dailyTarget(goal: Goal, policy: CountPolicy): number | null {
  const type = goal.requirement.type;
  return type === "per_due_date" || type === "days_per_period" ? policy.target : null;
}

/** At least the target, or any count without one. */
export function meetsTarget(count: number, target: number | null): boolean {
  return target === null ? count > 0 : count >= target;
}

/** Whether a day met every unit's target (a tracker's: any count). */
export function dayMetTarget(goal: Goal, counts: DayCounts): boolean {
  const tracker = goal.requirement.type === "tracker";
  return unitsOf(goal).every(({ id, policy }) =>
    meetsTarget(unitCount(goal, counts, id), tracker ? null : policy.target),
  );
}

/** A goal whose counts are being attributed. */
export interface AttributedGoal {
  id: string;
  dhikr_id: string;
  counts: CountSource;
  goal: GoalInput;
}

/**
 * count_attribution: each goal's count entries from the count log. A shared goal takes its
 * dhikr's entries without a `goal_id`, a dedicated goal only its own. With sessions that day an
 * entry goes to its session (dropped when the goal has none of that ID); entries sum per day and
 * session, and a sum of 0 or less is no count.
 */
export function attributeCounts(goal: AttributedGoal, log: readonly CountLogEntry[]): CountEntry[] {
  const buckets = new Map<string, CountEntry>();
  for (const entry of log) {
    if (entry.dhikr_id !== goal.dhikr_id) continue;
    const mine = goal.counts === "dedicated" ? entry.goal_id === goal.id : entry.goal_id === null;
    if (!mine) continue;
    const { sessions } = resolve(goal.goal, day(entry.practice_day), { capEnded: false });
    let session: string | null = null;
    if (sessions.length > 0) {
      if (!sessions.some((s) => s.id === entry.session_id)) continue;
      session = entry.session_id;
    }
    const key = `${entry.practice_day}|${session ?? ""}`;
    const count = (buckets.get(key)?.count ?? 0) + entry.amount;
    buckets.set(key, { date: entry.practice_day, session, count });
  }
  const byDayAndSession = (a: CountEntry, b: CountEntry): number =>
    compareText(a.date, b.date) || compareText(a.session ?? "", b.session ?? "");
  return [...buckets.values()].filter((entry) => entry.count > 0).sort(byDayAndSession);
}
