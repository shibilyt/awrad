import { CalculationMethod as Methods, Coordinates, PrayerTimes, type CalculationParameters } from "adhan";
import type { CalculationMethod } from "./policy";

/** adhan-js's parameters for each of the policy's methods (practice-settings.schema.json `calculation_method`). */
const PARAMETERS: Record<CalculationMethod, () => CalculationParameters> = {
  karachi: () => Methods.Karachi(),
  north_america: () => Methods.NorthAmerica(),
  muslim_world_league: () => Methods.MuslimWorldLeague(),
  egyptian: () => Methods.Egyptian(),
  umm_al_qura: () => Methods.UmmAlQura(),
  moonsighting_committee: () => Methods.MoonsightingCommittee(),
  dubai: () => Methods.Dubai(),
  kuwait: () => Methods.Kuwait(),
  qatar: () => Methods.Qatar(),
  singapore: () => Methods.Singapore(),
};

/**
 * maghrib_time: Maghrib on a local date (`YYYY-MM-DD`) at a place, with a method, as adhan
 * computes it (sunset plus the method's adjustment, rounded to the minute). `null` where the sun
 * doesn't set or doesn't rise that day; the Maghrib reset then falls back to midnight.
 */
export function maghribOn(
  date: string,
  place: { latitude: number; longitude: number },
  method: CalculationMethod,
): Date | null {
  const [year = 0, month = 1, day = 1] = date.split("-").map(Number);
  // adhan reads the date's local year, month and day, so a local midnight names the date.
  const times = new PrayerTimes(
    new Coordinates(place.latitude, place.longitude),
    new Date(year, month - 1, day),
    PARAMETERS[method](),
  );
  const maghrib = times.maghrib as Date | undefined;
  return maghrib === undefined || Number.isNaN(maghrib.getTime()) ? null : maghrib;
}
