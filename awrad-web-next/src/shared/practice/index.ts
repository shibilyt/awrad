// Practice settings (slice 3d, contracts/practice-settings/v1, root ADR-2026-10-29): the account
// practice policy and its rules, the Hijri calendar with corrections, Maghrib from adhan, the
// effective practice day, the bundled city list, and this browser's own location.
export { loadCities, searchCities, searchKey, type City, type CityList } from "./cities";
export { clock } from "./clock";
export { addDays, asUtcInstant, dayNumber, fromDayNumber, localDate } from "./dates";
export {
  allowedOffsets,
  areValidCorrections,
  hijriCorrectionErrors,
  hijriDate,
  hijriMonthOn,
  hijriTableEnd,
  monthStart,
  nextMonth,
  offsetFor,
  sortCorrections,
  withMonthOffset,
  withoutCorrection,
  type HijriCorrection,
  type HijriCorrectionError,
  type HijriDate,
  type HijriMonth,
} from "./hijri";
export { readBrowserLocation, storedLocation, storeLocation, useDeviceLocation, type DeviceLocation } from "./location";
export { maghribOn } from "./maghrib";
export { mergePolicy, type MergeNotice, type MergeResult } from "./merge";
export {
  CALCULATION_METHODS,
  DAY_RESETS,
  DEFAULT_POLICY,
  MADHABS,
  WEEK_STARTS,
  normalizedPolicy,
  policyProblems,
  samePolicy,
  type CalculationMethod,
  type DayReset,
  type Madhab,
  type PracticePolicy,
  type WeekStart,
} from "./policy";
export { effectivePracticeDay, practiceToday, type PracticeToday } from "./practiceDay";
