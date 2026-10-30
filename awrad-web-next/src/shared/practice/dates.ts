/**
 * Calendar dates as `YYYY-MM-DD` text, and the arithmetic on them, by whole days. A day number
 * counts days since 1970-01-01, so a date's weekday and its distance to another never depend on
 * a time zone.
 */

const DAY_MS = 86_400_000;

/** Days since 1970-01-01 of a `YYYY-MM-DD` date. */
export function dayNumber(date: string): number {
  return Math.round(Date.parse(`${date}T00:00:00Z`) / DAY_MS);
}

/** The `YYYY-MM-DD` date of a day number. */
export function fromDayNumber(day: number): string {
  return new Date(day * DAY_MS).toISOString().slice(0, 10);
}

/** `date` moved by `days`. */
export function addDays(date: string, days: number): string {
  return fromDayNumber(dayNumber(date) + days);
}

/** A date as the UTC instant of its midnight, for formatting it with `timeZone: "UTC"`. */
export function asUtcInstant(date: string): Date {
  return new Date(dayNumber(date) * DAY_MS);
}

/** The local calendar date of an instant in an IANA time zone. */
export function localDate(instant: Date, timeZone: string): string {
  const parts = new Intl.DateTimeFormat("en-US", {
    timeZone,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).formatToParts(instant);
  const part = (type: Intl.DateTimeFormatPartTypes): string => parts.find((p) => p.type === type)?.value ?? "";
  return `${part("year")}-${part("month")}-${part("day")}`;
}
