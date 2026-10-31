import { dayNumber, fromDayNumber, hijriMonthOn, type HijriCorrection, type WeekStart } from "@/shared/practice";
import type { Period, Weekday } from "./types";

/**
 * Days as the rules count them: day numbers (days since 1970-01-01), so arithmetic and weekdays
 * never depend on a time zone. Rules take and return `YYYY-MM-DD` text at their edges.
 */
export const day = dayNumber;
export const iso = fromDayNumber;

/** A run of days, both ends included. */
export interface Span {
  first: number;
  last: number;
}

const WEEKDAYS: readonly Weekday[] = ["sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday"];
const WEEK_INDEX: Record<WeekStart, number> = { sunday: 0, monday: 1, saturday: 6 };

/** 0 for Sunday … 6 for Saturday (1970-01-01 was a Thursday). */
const weekdayIndex = (n: number): number => (((n + 4) % 7) + 7) % 7;

export function weekdayOf(n: number): Weekday {
  return WEEKDAYS[weekdayIndex(n)] ?? "sunday";
}

export function gregorianParts(n: number): { year: number; month: number; day: number } {
  const [year = 0, month = 0, date = 0] = iso(n).split("-").map(Number);
  return { year, month, day: date };
}

export function daysInMonth(year: number, month: number): number {
  return new Date(Date.UTC(year, month, 0)).getUTCDate();
}

/** The earlier of two last days, where `null` is no end. */
export function earlier(a: number | null, b: number | null): number | null {
  if (a === null) return b;
  if (b === null) return a;
  return Math.min(a, b);
}

/** Every day of a span, in order. */
export function daysOf(span: Span): number[] {
  return Array.from({ length: Math.max(0, span.last - span.first + 1) }, (_, i) => span.first + i);
}

/** The week, Gregorian month or Hijri month a day is in; `null` outside the Hijri table. */
export function periodOf(
  n: number,
  period: Period,
  weekStart: WeekStart,
  corrections: readonly HijriCorrection[],
): Span | null {
  switch (period) {
    case "week": {
      const first = n - ((weekdayIndex(n) - WEEK_INDEX[weekStart] + 7) % 7);
      return { first, last: first + 6 };
    }
    case "month": {
      const { year, month, day: date } = gregorianParts(n);
      const first = n - date + 1;
      return { first, last: first + daysInMonth(year, month) - 1 };
    }
    case "hijri_month": {
      const month = hijriMonthOn(n, corrections);
      return month === null ? null : { first: month.start, last: month.start + month.length - 1 };
    }
  }
}

/** Code-point order, as every platform sorts IDs and dates (not the locale's collation). */
export function compareText(a: string, b: string): number {
  if (a < b) return -1;
  return a > b ? 1 : 0;
}
