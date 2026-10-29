import { addDays, localDate } from "./dates";
import { hijriDate, type HijriDate } from "./hijri";
import type { DeviceLocation } from "./location";
import { maghribOn } from "./maghrib";
import type { DayReset, PracticePolicy } from "./policy";

/**
 * effective_practice_day (contracts/goal-model/v1): the local calendar date of an instant, or
 * the next date from that day's Maghrib onwards when the day resets at Maghrib. Without a known
 * Maghrib (no location, or no sunset that day) it's the local date, as at midnight.
 */
export function effectivePracticeDay({
  instant,
  timeZone,
  dayReset,
  maghrib,
}: {
  instant: Date;
  timeZone: string;
  dayReset: DayReset;
  /** Maghrib on the instant's local date, or `null` when it isn't known. */
  maghrib: Date | null;
}): string {
  const date = localDate(instant, timeZone);
  if (dayReset === "maghrib" && maghrib !== null && instant.getTime() >= maghrib.getTime()) return addDays(date, 1);
  return date;
}

/** Today as Settings shows it: Maghrib on today's local date, the effective practice day, and its Hijri date. */
export interface PracticeToday {
  /** `null` without a location, or where the sun doesn't set today. */
  maghrib: Date | null;
  date: string;
  hijri: HijriDate | null;
  monthLength: number | null;
}

/** Today for a policy at a place (or none) in a time zone. */
export function practiceToday({
  now,
  timeZone,
  policy,
  location,
}: {
  now: Date;
  timeZone: string;
  policy: PracticePolicy;
  location: DeviceLocation | null;
}): PracticeToday {
  const today = localDate(now, timeZone);
  const maghrib = location === null ? null : maghribOn(today, location, policy.calculation_method);
  const date = effectivePracticeDay({ instant: now, timeZone, dayReset: policy.day_reset, maghrib });
  return { maghrib, date, ...hijriDate(date, policy.hijri_corrections) };
}
