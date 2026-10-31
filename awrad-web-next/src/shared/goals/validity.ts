import { day } from "./days";
import type { Goal, GoalSettings, GoalTimeline, SessionKind } from "./types";
import { sameJson, settingsOf } from "./versions";

/**
 * Goal validity (goal_validity.json): what's wrong with a goal or a goal document, as sorted
 * error codes. Platforms reject invalid goals at construction, sync and import.
 */

export type GoalError =
  | "target_required"
  | "session_target_required"
  | "streak_threshold_value_required"
  | "streak_pace_not_allowed"
  | "end_date_and_duration"
  | "make_up_not_allowed"
  | "sessions_with_minimum_or_cap"
  | "session_id_mismatch"
  | "session_duplicate"
  | "session_window_empty"
  | "structural_change"
  | "versions_out_of_order"
  | "first_version_not_created_on";

/** A session's ID, derived from its kind, so shared counts match sessions across goals. */
export function sessionId(session: SessionKind): string {
  switch (session.kind) {
    case "anytime":
      return "anytime";
    case "before_prayer":
      return `before_${session.prayer}`;
    case "after_prayer":
      return `after_${session.prayer}`;
    case "at_time":
      return `at_${session.time.replace(":", "")}`;
    case "between":
      return `between_${session.from.replace(":", "")}_${session.to.replace(":", "")}`;
  }
}

/** Make-up is for daily goals, and for totals whose streak counts at an amount, filled to it. */
function makeUpAllowed(goal: Goal): boolean {
  if (goal.requirement.type === "per_due_date") return true;
  return (
    goal.requirement.type === "cumulative_total" &&
    typeof goal.count_policy.streak_threshold === "object" &&
    goal.make_up.fill === "streak"
  );
}

function sessionErrors(goal: Goal, errors: Set<GoalError>): void {
  const tracker = goal.requirement.type === "tracker";
  for (const session of goal.sessions) {
    if (!tracker && session.target === null) errors.add("session_target_required");
    if (session.id !== sessionId(session)) errors.add("session_id_mismatch");
    if (session.kind === "between" && session.from === session.to) errors.add("session_window_empty");
  }
  const policy = goal.count_policy;
  if (policy.minimum !== null || policy.maximum !== null) errors.add("sessions_with_minimum_or_cap");
  const ids = goal.sessions.map((s) => s.id);
  if (new Set(ids).size !== ids.length) errors.add("session_duplicate");
}

function goalErrorSet(goal: Goal): Set<GoalError> {
  const errors = new Set<GoalError>();
  const policy = goal.count_policy;
  const threshold = policy.streak_threshold;
  if (goal.sessions.length === 0) {
    if ((threshold === "minimum" || threshold === "target" || threshold === "maximum") && policy[threshold] === null) {
      errors.add("streak_threshold_value_required");
    }
    if (goal.requirement.type !== "tracker" && policy.target === null) errors.add("target_required");
  } else {
    sessionErrors(goal, errors);
  }
  const period = goal.active_period;
  const hasEnd = period.end_date !== null || period.duration_days !== null;
  if (period.end_date !== null && period.duration_days !== null) errors.add("end_date_and_duration");
  if (goal.make_up.window !== "off" && !makeUpAllowed(goal)) errors.add("make_up_not_allowed");
  if (threshold === "daily_pace" && !(goal.requirement.type === "cumulative_total" && hasEnd)) {
    errors.add("streak_pace_not_allowed");
  }
  return errors;
}

/** What's wrong with a goal, sorted; empty when it's valid. */
export function goalErrors(goal: Goal): GoalError[] {
  return [...goalErrorSet(goal)].sort();
}

/** The fields every version must agree on: changing one ends the goal and starts a new one. */
export function structureOf(settings: GoalSettings): Record<string, string | null> {
  const { schedule, requirement } = settings;
  return {
    schedule: schedule.kind,
    calendar: schedule.kind === "yearly" ? schedule.calendar : null,
    requirement: requirement.type,
    period: requirement.type === "period_total" || requirement.type === "days_per_period" ? requirement.period : null,
    start: settings.active_period.start_date,
  };
}

/**
 * What's wrong with a goal document, sorted: every version's errors (with the document's pauses
 * and excused days), versions out of order or not starting on `created_on`, and structural changes.
 */
export function documentErrors(document: GoalTimeline): GoalError[] {
  const errors = new Set<GoalError>();
  const { versions, paused, excused } = document;
  for (const version of versions) {
    for (const error of goalErrorSet({ ...settingsOf(version), paused, excused })) errors.add(error);
  }
  const froms = versions.map((v) => day(v.from));
  if (froms.some((from, i) => i > 0 && from <= (froms[i - 1] ?? from))) errors.add("versions_out_of_order");
  const [first] = versions;
  if (first?.from !== document.created_on) errors.add("first_version_not_created_on");
  if (first !== undefined && versions.some((v) => !sameJson(structureOf(v), structureOf(first)))) {
    errors.add("structural_change");
  }
  return [...errors].sort();
}
