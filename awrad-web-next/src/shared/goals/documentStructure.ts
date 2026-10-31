import { isValidId } from "@/shared/identity";
import { DHIKR_KINDS, LONG_TEXT_MAX, TITLE_MAX, textProblems, type FieldProblem } from "@/shared/sync";
import { MAX_VERSIONS } from "./versions";

/**
 * The goal document's structure (goal-model.schema.json `$defs/goal_document`), as `{field, code}`
 * problems (sync/v1 README "Goal documents"): a missing member is `required`, an unknown one
 * `not_allowed`, a wrong type, unknown enum value or kind, non-UUID or impossible month-day
 * `invalid`, an empty text `blank`, text over its limit `too_long`, a list over its limit
 * `too_many` (an empty `versions` list `required`), and repeated items `duplicate`.
 */

/** Checks a value at a JSON Pointer, adding what's wrong with it. */
type Check = (value: unknown, at: string, out: FieldProblem[]) => void;
type Json = Record<string, unknown>;

const MAX_COUNT = Number.MAX_SAFE_INTEGER;
const DATE = /^\d{4}-(0[1-9]|1[0-2])-(0[1-9]|[12]\d|3[01])$/;
const TIME = /^([01]\d|2[0-3]):[0-5]\d$/;
const SESSION_ID = /^[a-z][a-z0-9_]*$/;
const WEEKDAYS = ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"];
const PRAYERS = ["fajr", "dhuhr", "asr", "maghrib", "isha"];
const PERIODS = ["week", "month", "hijri_month"];
const COMPLETIONS = ["never", "when_target_reached", "when_duration_ended"];
const THRESHOLDS = ["any_count", "minimum", "target", "maximum", "daily_pace"];
const END_REASONS = ["user", "completed", "date", "structural_edit", "dhikr_deleted"];
/** Days in each Gregorian month, 29 February allowed (it falls on the 28th in common years). */
const GREGORIAN_MONTH_DAYS = [31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];

function isObject(value: unknown): value is Json {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

const invalid = (at: string, out: FieldProblem[]): void => {
  out.push({ field: at, code: "invalid" });
};

const when =
  (test: (value: unknown) => boolean): Check =>
  (value, at, out) => {
    if (!test(value)) invalid(at, out);
  };

const oneOf = (values: readonly unknown[]): Check => when((value) => values.includes(value));
const integer = (min: number, max: number): Check =>
  when((value) => typeof value === "number" && Number.isInteger(value) && value >= min && value <= max);
const matching = (pattern: RegExp): Check => when((value) => typeof value === "string" && pattern.test(value));
const date = matching(DATE);
const uuid: Check = when((value) => typeof value === "string" && isValidId(value));
const count = integer(0, MAX_COUNT);

const nullable =
  (check: Check): Check =>
  (value, at, out) => {
    if (value !== null) check(value, at, out);
  };

/** Text: not blank, at most `max` code points. */
const text =
  (max: number): Check =>
  (value, at, out) => {
    if (typeof value === "string") out.push(...textProblems(at, value, max));
    else invalid(at, out);
  };

/** An object with exactly these members. */
const object =
  (members: Record<string, Check>): Check =>
  (value, at, out) => {
    if (!isObject(value)) {
      invalid(at, out);
      return;
    }
    for (const key of Object.keys(value)) {
      if (!(key in members)) out.push({ field: `${at}/${key}`, code: "not_allowed" });
    }
    for (const [key, check] of Object.entries(members)) {
      if (key in value) check(value[key], `${at}/${key}`, out);
      else out.push({ field: `${at}/${key}`, code: "required" });
    }
  };

/** An object whose members depend on its `key` member (a schedule's kind, a requirement's type). */
const variants =
  (key: string, shapes: Record<string, Record<string, Check>>): Check =>
  (value, at, out) => {
    if (!isObject(value)) {
      invalid(at, out);
      return;
    }
    const tag = value[key];
    const shape = typeof tag === "string" ? shapes[tag] : undefined;
    if (!(key in value)) out.push({ field: `${at}/${key}`, code: "required" });
    else if (shape === undefined) invalid(`${at}/${key}`, out);
    else object({ [key]: () => undefined, ...shape })(value, at, out);
  };

/** A list of at most `max` items, at least `min` (an empty required list is `required`), optionally without repeats. */
const list =
  (item: Check, { min = 0, max = Infinity, unique = false }: { min?: number; max?: number; unique?: boolean }): Check =>
  (value, at, out) => {
    if (!Array.isArray(value)) {
      invalid(at, out);
      return;
    }
    if (value.length < min) out.push({ field: at, code: "required" });
    if (value.length > max) out.push({ field: at, code: "too_many" });
    if (unique && new Set(value.map((v) => JSON.stringify(v))).size !== value.length) {
      out.push({ field: at, code: "duplicate" });
    }
    value.forEach((v: unknown, i) => {
      item(v, `${at}/${String(i)}`, out);
    });
  };

/** A month and day; a day the month can't have (31 April, Hijri 31) is invalid on the whole. */
const monthDay =
  (monthLengths: readonly number[]): Check =>
  (value, at, out) => {
    const problems: FieldProblem[] = [];
    object({ month: integer(1, monthLengths.length), day: integer(1, 31) })(value, at, problems);
    out.push(...problems);
    if (problems.length > 0 || !isObject(value)) return;
    const length = monthLengths[(value["month"] as number) - 1] ?? 0;
    if ((value["day"] as number) > length) invalid(at, out);
  };

const yearlyRanges = (monthLengths: readonly number[]): Check =>
  list(object({ start: monthDay(monthLengths), end: monthDay(monthLengths) }), { min: 1 });

const schedule: Check = (value, at, out) => {
  const yearly = isObject(value) && value["kind"] === "yearly";
  if (yearly && value["calendar"] !== "gregorian" && value["calendar"] !== "hijri") {
    if ("calendar" in value) invalid(`${at}/calendar`, out);
    else out.push({ field: `${at}/calendar`, code: "required" });
    return;
  }
  const hijri = yearly && value["calendar"] === "hijri";
  variants("kind", {
    every_day: {},
    one_time: {},
    weekdays: { weekdays: list(oneOf(WEEKDAYS), { min: 1, unique: true }) },
    every_n_days: { every: integer(1, 366), anchor_date: nullable(date) },
    month_days: { days: list(integer(1, 31), { min: 1, unique: true }) },
    specific_dates: { dates: list(date, { min: 1, unique: true }) },
    hijri_month_days: { days: list(integer(1, 30), { min: 1, unique: true }) },
    yearly: {
      calendar: () => undefined,
      ranges: yearlyRanges(hijri ? Array<number>(12).fill(30) : GREGORIAN_MONTH_DAYS),
    },
  })(value, at, out);
};

const streakThreshold: Check = (value, at, out) => {
  if (isObject(value)) object({ amount: integer(1, MAX_COUNT) })(value, at, out);
  else oneOf(THRESHOLDS)(value, at, out);
};

const sessionTarget = { target: nullable(count) };
const session = variants("kind", {
  anytime: { id: matching(SESSION_ID), ...sessionTarget },
  before_prayer: { id: matching(SESSION_ID), prayer: oneOf(PRAYERS), ...sessionTarget },
  after_prayer: { id: matching(SESSION_ID), prayer: oneOf(PRAYERS), ...sessionTarget },
  at_time: { id: matching(SESSION_ID), time: matching(TIME), ...sessionTarget },
  between: { id: matching(SESSION_ID), from: matching(TIME), to: matching(TIME), ...sessionTarget },
});

const version = object({
  from: date,
  schedule,
  active_period: object({ start_date: date, end_date: nullable(date), duration_days: nullable(integer(1, 36600)) }),
  count_policy: object({
    minimum: nullable(count),
    target: nullable(count),
    maximum: nullable(count),
    streak_threshold: streakThreshold,
  }),
  sessions: list(session, {}),
  requirement: variants("type", {
    per_due_date: {},
    cumulative_total: {},
    tracker: {},
    period_total: { period: oneOf(PERIODS) },
    days_per_period: { period: oneOf(PERIODS), days: integer(1, 31) },
  }),
  completion: oneOf(COMPLETIONS),
  make_up: object({ window: oneOf(["off", "next_day", "within_3_days"]), fill: oneOf(["streak", "target"]) }),
});

/** The snapshot's title: every language, each text or null, and at least one text. */
const snapshotTitle: Check = (value, at, out) => {
  object({ en: nullable(text(TITLE_MAX)), ar: nullable(text(TITLE_MAX)), ml: nullable(text(TITLE_MAX)) })(
    value,
    at,
    out,
  );
  if (isObject(value) && !["en", "ar", "ml"].some((language) => typeof value[language] === "string")) {
    out.push({ field: at, code: "required" });
  }
};

const goalDocument = object({
  dhikr_id: uuid,
  dhikr_snapshot: object({ title: snapshotTitle, arabic: text(LONG_TEXT_MAX), kind: oneOf(DHIKR_KINDS) }),
  name: nullable(text(TITLE_MAX)),
  counts: oneOf(["shared", "dedicated"]),
  created_on: date,
  versions: list(version, { min: 1, max: MAX_VERSIONS }),
  paused: list(object({ from: date, to: nullable(date) }), { max: 500 }),
  excused: list(date, { max: 1000, unique: true }),
  ended: nullable(object({ on: date, reason: oneOf(END_REASONS) })),
});

/** What's wrong with a goal document's structure, unsorted; empty when it matches the schema. */
export function structureProblems(document: unknown): FieldProblem[] {
  const out: FieldProblem[] = [];
  goalDocument(document, "", out);
  return out;
}
