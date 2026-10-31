import type { HijriCorrection, WeekStart } from "@/shared/practice";

/**
 * The goal model (contracts/goal-model/v1/goal-model.schema.json) as the rules read it. Dates are
 * effective practice days (`YYYY-MM-DD`); names, not numbers, for weekdays.
 */

export type Weekday = "monday" | "tuesday" | "wednesday" | "thursday" | "friday" | "saturday" | "sunday";
export type Prayer = "fajr" | "dhuhr" | "asr" | "maghrib" | "isha";

/** A month and day in a yearly range (Gregorian or Hijri, by the schedule's calendar). */
export interface MonthDay {
  month: number;
  day: number;
}

/** Inclusive; an end before its start runs over the year end. */
export interface YearlyRange {
  start: MonthDay;
  end: MonthDay;
}

export interface YearlySchedule {
  kind: "yearly";
  calendar: "gregorian" | "hijri";
  ranges: readonly YearlyRange[];
}

/** Which days a goal is due. */
export type Schedule =
  | { kind: "every_day" }
  | { kind: "one_time" }
  | { kind: "weekdays"; weekdays: readonly Weekday[] }
  /** `anchor_date` `null` means the start date. */
  | { kind: "every_n_days"; every: number; anchor_date: string | null }
  | { kind: "month_days"; days: readonly number[] }
  | { kind: "specific_dates"; dates: readonly string[] }
  | { kind: "hijri_month_days"; days: readonly number[] }
  | YearlySchedule;

export interface ActivePeriod {
  start_date: string;
  end_date: string | null;
  duration_days: number | null;
}

/** Inclusive; `to` is `null` while still paused. */
export interface PausedRange {
  from: string;
  to: string | null;
}

/** What a day needs to keep the streak. */
export type StreakThreshold = "any_count" | "minimum" | "target" | "maximum" | "daily_pace" | { amount: number };

export interface CountPolicy {
  minimum: number | null;
  target: number | null;
  maximum: number | null;
  streak_threshold: StreakThreshold;
}

/** A session's kind only guides; its ID is derived from it (`sessionId`). */
export type SessionKind =
  | { kind: "anytime" }
  | { kind: "before_prayer" | "after_prayer"; prayer: Prayer }
  | { kind: "at_time"; time: string }
  | { kind: "between"; from: string; to: string };

/** A session carries a target only (`null` only on a tracker's session: any count). */
export type Session = SessionKind & { id: string; target: number | null };

export type Period = "week" | "month" | "hijri_month";

export type Requirement =
  | { type: "per_due_date" | "cumulative_total" | "tracker" }
  | { type: "period_total"; period: Period }
  | { type: "days_per_period"; period: Period; days: number };

export type Completion = "never" | "when_target_reached" | "when_duration_ended";

export type MakeUpWindow = "off" | "next_day" | "within_3_days";

export interface MakeUp {
  window: MakeUpWindow;
  fill: "streak" | "target";
}

/** What a dated version holds. */
export interface GoalSettings {
  schedule: Schedule;
  active_period: ActivePeriod;
  count_policy: CountPolicy;
  sessions: readonly Session[];
  requirement: Requirement;
  completion: Completion;
  make_up: MakeUp;
}

/** What a rule evaluates on one day: one version's settings plus the goal's pauses and excused days. */
export interface Goal extends GoalSettings {
  paused: readonly PausedRange[];
  excused: readonly string[];
}

export interface Version extends GoalSettings {
  /** The first practice day it's in force. */
  from: string;
}

export type EndReason = "user" | "completed" | "date" | "structural_edit" | "dhikr_deleted";

/** `on` is the goal's last day, inclusive. */
export interface Ended {
  on: string;
  reason: EndReason;
}

/** Everything about a goal's days: the goal document without its dhikr, name and counts. */
export interface GoalTimeline {
  created_on: string;
  versions: readonly Version[];
  paused: readonly PausedRange[];
  excused: readonly string[];
  ended: Ended | null;
}

/** A rule's input: a single goal (one version from its start, never ended) or a whole timeline. */
export type GoalInput = Goal | GoalTimeline;

export type CountSource = "shared" | "dedicated";

/** The `goal` sync entity's document. */
export interface GoalDocument extends GoalTimeline {
  dhikr_id: string;
  dhikr_snapshot: {
    title: { en: string | null; ar: string | null; ml: string | null };
    arabic: string;
    kind: "quran" | "dhikr" | "dua" | "salawat" | "name_of_allah";
  };
  name: string | null;
  counts: CountSource;
}

/** The `goal_order` sync entity's document: the user's order of My Goals. */
export interface GoalOrderDocument {
  goal_ids: readonly string[];
}

/** A day's total for the goal (`session` `null`) or for one session. */
export interface CountEntry {
  date: string;
  session: string | null;
  count: number;
}

/** One entry of a profile's count log; `goal_id` only for a count made in a dedicated goal. */
export interface CountLogEntry {
  id: string;
  dhikr_id: string;
  practice_day: string;
  session_id: string | null;
  goal_id: string | null;
  amount: number;
  counted_at: string;
}

/** The account's calendar settings the rules read. */
export interface GoalCalendar {
  weekStart: WeekStart;
  /** The account's Hijri month-start corrections. */
  hijriCorrections: readonly HijriCorrection[];
}

/** A goal and its counts, evaluated on a day (`date`, usually today). */
export interface GoalOnDay {
  goal: GoalInput;
  counts: readonly CountEntry[];
  date: string;
}
