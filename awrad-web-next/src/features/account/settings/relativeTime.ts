const UNITS: readonly (readonly [Intl.RelativeTimeFormatUnit, number])[] = [
  ["year", 365 * 24 * 60 * 60],
  ["month", 30 * 24 * 60 * 60],
  ["week", 7 * 24 * 60 * 60],
  ["day", 24 * 60 * 60],
  ["hour", 60 * 60],
  ["minute", 60],
];

/**
 * How long ago `instant` was, in the UI language ("3 hours ago", "yesterday",
 * "this minute"). A time slightly in the future (clock skew) reads as now.
 */
export function relativeTime(instant: string, now: number, language: string): string {
  const seconds = Math.max(0, (now - Date.parse(instant)) / 1000);
  const format = new Intl.RelativeTimeFormat(language, { numeric: "auto" });
  for (const [unit, size] of UNITS) {
    if (seconds >= size) return format.format(-Math.floor(seconds / size), unit);
  }
  return format.format(0, "minute");
}
