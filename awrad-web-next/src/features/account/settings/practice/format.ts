import type { TFunction } from "i18next";
import { asUtcInstant, type DeviceLocation, type HijriDate, type WeekStart } from "@/shared/practice";

/** Display text for the practice settings, in the UI language: numbers, times and names from `Intl`. */

function number(value: number, language: string): string {
  return new Intl.NumberFormat(language, { useGrouping: false }).format(value);
}

/** "18 Jumada al-Ula 1448". */
export function hijriText(t: TFunction, hijri: HijriDate, language: string): string {
  return t("practice.hijriDate", {
    day: number(hijri.day, language),
    month: t(`practice.months.${String(hijri.month)}`),
    year: number(hijri.year, language),
  });
}

/** "Jumada al-Ula 1448". */
export function monthText(t: TFunction, year: number, month: number, language: string): string {
  return t("practice.monthYear", { month: t(`practice.months.${String(month)}`), year: number(year, language) });
}

/** A time of day in the browser's time zone ("5:58 PM"). */
export function timeText(instant: Date, timeZone: string, language: string): string {
  return new Intl.DateTimeFormat(language, { hour: "numeric", minute: "2-digit", timeZone }).format(instant);
}

/** A calendar date with its weekday ("Monday, 12 October"). */
export function dateText(date: string, language: string): string {
  return new Intl.DateTimeFormat(language, { weekday: "long", day: "numeric", month: "long", timeZone: "UTC" }).format(
    asUtcInstant(date),
  );
}

/** A Saturday, a Sunday and a Monday, to name them in the UI language. */
const WEEKDAY_DATES: Record<WeekStart, string> = {
  saturday: "2026-10-31",
  sunday: "2026-11-01",
  monday: "2026-11-02",
};

export function weekdayText(day: WeekStart, language: string): string {
  return new Intl.DateTimeFormat(language, { weekday: "long", timeZone: "UTC" }).format(
    asUtcInstant(WEEKDAY_DATES[day]),
  );
}

/** A country's name in the UI language, from its ISO code. */
export function countryText(code: string, language: string): string {
  return new Intl.DisplayNames([language], { type: "region" }).of(code) ?? code;
}

/** How Settings names the browser's location: the city, or the coordinates of a reading. */
export function locationText(t: TFunction, location: DeviceLocation, language: string): string {
  if (location.name !== null) return location.name;
  const degrees = new Intl.NumberFormat(language, { maximumFractionDigits: 2 });
  return t("practice.location.coordinates", {
    latitude: degrees.format(location.latitude),
    longitude: degrees.format(location.longitude),
  });
}

/** "1 day later", "As calculated (Umm al-Qura)", "2 days earlier". */
export function offsetText(t: TFunction, offset: number): string {
  if (offset === 0) return t("practice.hijri.asCalculated");
  return offset > 0 ? t("practice.hijri.later", { count: offset }) : t("practice.hijri.earlier", { count: -offset });
}
