import type { HijriCorrection } from "@/shared/practice";
import { indexCounts, type CountIndex } from "./counts";
import { dayStatuses } from "./dayStatus";
import { compareText, day, iso } from "./days";
import { inSchedule, isDue, isPaused, lastDay } from "./schedule";
import { HORIZON_DAYS } from "./streak";
import { completedOn } from "./today";
import type { CountEntry, GoalCalendar, GoalInput } from "./types";
import { createdOn, endedOf, resolve } from "./versions";

/**
 * My Goals placement (goal_list_placement.json, decisions 12, 25, 26, 30 and 46): History,
 * Paused, Tracking, Today or Upcoming, the first match winning, and the order in each.
 */

export interface PlacedGoal {
  id: string;
  goal: GoalInput;
  counts: readonly CountEntry[];
}

export interface Finished {
  /** `completed` (by the document or its completion policy) or `ended`. */
  finished: "completed" | "ended";
  /** Its last day. Clients write `completed` and `date` endings themselves on first seeing them. */
  on: string;
}

export interface GoalLists {
  today: string[];
  upcoming: { id: string; next_due: string | null }[];
  tracking: string[];
  paused: string[];
  history: ({ id: string } & Finished)[];
}

/** The first day from `from` to the horizon (and the goal's last day) that passes `test`, or `null`. */
function firstDayAhead(input: GoalInput, from: number, today: number, test: (n: number) => boolean): number | null {
  const last = lastDay(resolve(input, today).active_period);
  const horizon = last === null ? today + HORIZON_DAYS : Math.min(last, today + HORIZON_DAYS);
  for (let n = from; n <= horizon; n += 1) if (test(n)) return n;
  return null;
}

/** Whether, and how, a goal has finished: ended in its document, completed, past its last day, or nothing left in 400 days. */
function finishedState(
  input: GoalInput,
  counts: CountIndex,
  today: number,
  corrections: readonly HijriCorrection[],
): Finished | null {
  const ended = endedOf(input);
  if (ended !== null) return { finished: ended.reason === "completed" ? "completed" : "ended", on: ended.on };
  const goal = resolve(input, today);
  const last = lastDay(goal.active_period);
  const start = day(goal.active_period.start_date);
  if (completedOn(goal, counts, today)) {
    if (goal.completion === "when_duration_ended" && last !== null) return { finished: "completed", on: iso(last) };
    for (let n = start; n <= today; n += 1)
      if (completedOn(goal, counts, n)) return { finished: "completed", on: iso(n) };
  }
  if (last !== null && today > last) return { finished: "ended", on: iso(last) };
  const scheduledOn = (n: number) => inSchedule(resolve(input, n), n, corrections);
  if (firstDayAhead(input, today, today, scheduledOn) !== null) return null;
  for (let n = today - 1; n >= start; n -= 1) if (scheduledOn(n)) return { finished: "ended", on: iso(n) };
  return { finished: "ended", on: goal.active_period.start_date };
}

type Section = "today" | "tracking" | "paused" | "upcoming";

function sectionOf(
  item: PlacedGoal,
  counts: CountIndex,
  today: number,
  corrections: readonly HijriCorrection[],
): Section {
  const goal = resolve(item.goal, today);
  if (isPaused(goal, today)) return "paused";
  if (goal.requirement.type === "tracker") return "tracking";
  if (isDue(goal, today, corrections)) return "today";
  const statuses = dayStatuses({ input: item.goal, counts, today, corrections });
  return [...statuses.values()].some((s) => s.status === "pending") ? "today" : "upcoming";
}

interface Entry {
  id: string;
  created: string;
}

/** goal_list_placement: each goal's section, in the account's `goal_order`, then by created_on and ID. */
export function placeGoals(
  goals: readonly PlacedGoal[],
  order: readonly string[],
  date: string,
  { hijriCorrections }: Pick<GoalCalendar, "hijriCorrections">,
): GoalLists {
  const today = day(date);
  const position = (id: string) => (order.includes(id) ? order.indexOf(id) : Infinity);
  const byOrder = (a: Entry, b: Entry) =>
    position(a.id) - position(b.id) || compareText(a.created, b.created) || compareText(a.id, b.id);
  const sections: Record<Section, Entry[]> = { today: [], tracking: [], paused: [], upcoming: [] };
  const nextDue = new Map<string, string | null>();
  const history: (Entry & Finished)[] = [];
  for (const item of goals) {
    const counts = indexCounts(item.counts);
    const entry = { id: item.id, created: createdOn(item.goal) };
    const finished = finishedState(item.goal, counts, today, hijriCorrections);
    if (finished !== null) {
      history.push({ ...entry, ...finished });
      continue;
    }
    const section = sectionOf(item, counts, today, hijriCorrections);
    sections[section].push(entry);
    if (section === "upcoming") {
      const next = firstDayAhead(item.goal, today + 1, today, (n) => isDue(resolve(item.goal, n), n, hijriCorrections));
      nextDue.set(item.id, next === null ? null : iso(next));
    }
  }
  const dueOf = (entry: Entry) => nextDue.get(entry.id) ?? null;
  const soonest = (a: Entry, b: Entry) => {
    const [x, y] = [dueOf(a), dueOf(b)];
    if (x === y) return 0;
    if (x === null || y === null) return x === null ? 1 : -1;
    return compareText(x, y);
  };
  return {
    today: sections.today.sort(byOrder).map((e) => e.id),
    upcoming: sections.upcoming
      .sort((a, b) => soonest(a, b) || byOrder(a, b))
      .map((e) => ({ id: e.id, next_due: dueOf(e) })),
    tracking: sections.tracking.sort(byOrder).map((e) => e.id),
    paused: sections.paused.sort(byOrder).map((e) => e.id),
    history: history
      .sort((a, b) => compareText(b.on, a.on) || byOrder(a, b))
      .map(({ id, finished, on }) => ({ id, finished, on })),
  };
}
