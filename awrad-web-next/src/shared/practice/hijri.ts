import table from "../../../../contracts/hijri-calendar/v1/umm-al-qura.json";
import { dayNumber, fromDayNumber } from "./dates";

/**
 * The Hijri calendar (contracts/hijri-calendar/v1, root ADR-2026-10-26): the shared Umm al-Qura
 * month table with the account's month-start corrections. No Hijri library: every platform reads
 * the same table, so dates agree everywhere.
 */

/** Moves a month's start by `offset_days` from the table, and every later month's until the next correction. */
export interface HijriCorrection {
  year: number;
  month: number;
  offset_days: number;
}

export interface HijriDate {
  year: number;
  month: number;
  day: number;
}

export type HijriCorrectionError =
  "duplicate_month" | "month_length_invalid" | "month_out_of_range" | "offset_out_of_range";

export const FIRST_YEAR = table.first_year;
export const LAST_YEAR = table.last_year;
/** The furthest a correction may move a month from the table, either way. */
export const MAX_OFFSET = 2;
const OFFSETS = [-2, -1, 0, 1, 2] as const;

const MONTH_STARTS = table.month_starts as Record<string, readonly string[] | undefined>;

interface TableMonth {
  year: number;
  month: number;
  /** Its first day, as a day number. */
  start: number;
}

const MONTHS: readonly TableMonth[] = Array.from({ length: LAST_YEAR - FIRST_YEAR + 1 }, (_, i) => {
  const year = FIRST_YEAR + i;
  const starts = MONTH_STARTS[String(year)];
  if (starts?.length !== 12) throw new Error(`umm-al-qura.json: ${String(year)} doesn't have 12 months`);
  return starts.map((start, month) => ({ year, month: month + 1, start: dayNumber(start) }));
}).flat();
const TABLE_END = dayNumber(table.end_exclusive);

const keyOf = (year: number, month: number): string => `${String(year)}/${String(month)}`;

/** Each month's adjusted start, then the adjusted end of the table: the last correction in force moves it too. */
function adjustedStarts(corrections: readonly HijriCorrection[]): number[] {
  const offsets = new Map(corrections.map((c) => [keyOf(c.year, c.month), c.offset_days]));
  let offset = 0;
  const starts = MONTHS.map((m) => {
    offset = offsets.get(keyOf(m.year, m.month)) ?? offset;
    return m.start + offset;
  });
  starts.push(TABLE_END + offset);
  return starts;
}

/**
 * The Hijri date of a day (`YYYY-MM-DD`, an effective practice day) and its month's length
 * (hijri_date.json): the month whose adjusted start is on or before it and whose next month's
 * start is after it. `null` for both outside the table.
 */
export function hijriDate(
  date: string,
  corrections: readonly HijriCorrection[],
): { hijri: HijriDate | null; monthLength: number | null } {
  const day = dayNumber(date);
  const starts = adjustedStarts(corrections);
  for (const [i, month] of MONTHS.entries()) {
    const start = starts[i] ?? 0;
    const next = starts[i + 1] ?? 0;
    if (day >= start && day < next) {
      return { hijri: { year: month.year, month: month.month, day: day - start + 1 }, monthLength: next - start };
    }
  }
  return { hijri: null, monthLength: null };
}

function monthLengthsValid(corrections: readonly HijriCorrection[]): boolean {
  const starts = adjustedStarts(corrections);
  return starts.slice(1).every((start, i) => {
    const length = start - (starts[i] ?? 0);
    return length === 29 || length === 30;
  });
}

/** hijri_corrections_validity: what's wrong with a set of corrections, sorted; empty when it's valid. */
export function hijriCorrectionErrors(corrections: readonly HijriCorrection[]): HijriCorrectionError[] {
  const errors = new Set<HijriCorrectionError>();
  const seen = new Set<string>();
  for (const c of corrections) {
    if (Math.abs(c.offset_days) > MAX_OFFSET) errors.add("offset_out_of_range");
    if (c.year < FIRST_YEAR || c.year > LAST_YEAR || c.month < 1 || c.month > 12) errors.add("month_out_of_range");
    const key = keyOf(c.year, c.month);
    if (seen.has(key)) errors.add("duplicate_month");
    seen.add(key);
  }
  if (errors.size === 0 && !monthLengthsValid(corrections)) errors.add("month_length_invalid");
  return [...errors].sort();
}

/** Whether a set of corrections is valid (hijri_corrections_validity). */
export function areValidCorrections(corrections: readonly HijriCorrection[]): boolean {
  return hijriCorrectionErrors(corrections).length === 0;
}

/** By year, then month: the order clients write corrections in. */
export function sortCorrections(corrections: readonly HijriCorrection[]): HijriCorrection[] {
  return [...corrections].sort((a, b) => a.year - b.year || a.month - b.month);
}

/** The month after (`year`, `month`). */
export function nextMonth(year: number, month: number): { year: number; month: number } {
  return month === 12 ? { year: year + 1, month: 1 } : { year, month: month + 1 };
}

const isBefore = (c: HijriCorrection, year: number, month: number): boolean =>
  c.year < year || (c.year === year && c.month < month);

/** The offset in force for a month: its own correction, or the last earlier one, or 0. */
export function offsetFor(corrections: readonly HijriCorrection[], year: number, month: number): number {
  const own = corrections.find((c) => c.year === year && c.month === month);
  if (own !== undefined) return own.offset_days;
  return sortCorrections(corrections.filter((c) => isBefore(c, year, month))).at(-1)?.offset_days ?? 0;
}

/** The set without a correction for (`year`, `month`). */
export function withoutCorrection(
  corrections: readonly HijriCorrection[],
  year: number,
  month: number,
): HijriCorrection[] {
  return sortCorrections(corrections.filter((c) => c.year !== year || c.month !== month));
}

/**
 * The set with (`year`, `month`) moved to `offset` from the table. An offset the earlier months
 * already carry needs no correction of its own, so the month's correction goes instead.
 */
export function withMonthOffset(
  corrections: readonly HijriCorrection[],
  year: number,
  month: number,
  offset: number,
): HijriCorrection[] {
  const rest = withoutCorrection(corrections, year, month);
  if (offsetFor(rest, year, month) === offset) return rest;
  return sortCorrections([...rest, { year, month, offset_days: offset }]);
}

/**
 * The offsets "Adjust this month" may offer for a month: those that keep the whole set valid.
 * Every month is 29 or 30 days, so it's usually the current offset and one day either side.
 */
export function allowedOffsets(corrections: readonly HijriCorrection[], year: number, month: number): number[] {
  return OFFSETS.filter((offset) => areValidCorrections(withMonthOffset(corrections, year, month, offset)));
}

/** The first day (`YYYY-MM-DD`) of a month with `offset` from the table, or `null` outside it. */
export function monthStart(year: number, month: number, offset: number): string | null {
  const tableMonth = MONTHS[(year - FIRST_YEAR) * 12 + month - 1];
  return tableMonth === undefined ? null : fromDayNumber(tableMonth.start + offset);
}
