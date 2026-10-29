import type { FieldProblem } from "@/shared/sync";
import type { PracticePolicyDocument } from "@/shared/sync";
import { FIRST_YEAR, LAST_YEAR, MAX_OFFSET, areValidCorrections, sortCorrections } from "./hijri";

/**
 * The account practice policy (contracts/practice-settings/v1, root ADR-2026-10-29): when the
 * day resets, the prayer calculation method and madhab, the week start and the Hijri
 * corrections. It syncs as the account's one `practice_policy` entity; the device's location
 * never joins it.
 */
export type PracticePolicy = PracticePolicyDocument;
export type DayReset = PracticePolicy["day_reset"];
export type CalculationMethod = PracticePolicy["calculation_method"];
export type Madhab = PracticePolicy["madhab"];
export type WeekStart = PracticePolicy["week_start"];

export const DAY_RESETS: readonly DayReset[] = ["midnight", "maghrib"];
/** adhan's names for the frozen apps' ten methods, in the order Settings lists them. */
export const CALCULATION_METHODS: readonly CalculationMethod[] = [
  "karachi",
  "north_america",
  "muslim_world_league",
  "egyptian",
  "umm_al_qura",
  "moonsighting_committee",
  "dubai",
  "kuwait",
  "qatar",
  "singapore",
];
export const MADHABS: readonly Madhab[] = ["shafi", "hanafi"];
export const WEEK_STARTS: readonly WeekStart[] = ["saturday", "sunday", "monday"];

/** A new profile's policy, and the base to merge against when the account has none (the frozen defaults). */
export const DEFAULT_POLICY: PracticePolicy = {
  day_reset: "midnight",
  calculation_method: "karachi",
  madhab: "shafi",
  week_start: "monday",
  hijri_corrections: [],
};

const MEMBERS = ["day_reset", "calculation_method", "madhab", "week_start", "hijri_corrections"] as const;
const SETTINGS: Record<Exclude<(typeof MEMBERS)[number], "hijri_corrections">, readonly unknown[]> = {
  day_reset: DAY_RESETS,
  calculation_method: CALCULATION_METHODS,
  madhab: MADHABS,
  week_start: WEEK_STARTS,
};

type Json = Record<string, unknown>;
const isObject = (value: unknown): value is Json =>
  typeof value === "object" && value !== null && !Array.isArray(value);
const isInteger = (value: unknown, min: number, max: number): boolean =>
  typeof value === "number" && Number.isInteger(value) && value >= min && value <= max;

/** Exactly `{year, month, offset_days}`, integers inside the table and within 2 days. */
function isWellFormedCorrection(value: unknown): value is { year: number; month: number; offset_days: number } {
  if (!isObject(value)) return false;
  const keys = Object.keys(value).sort().join(",");
  return (
    keys === "month,offset_days,year" &&
    isInteger(value["year"], FIRST_YEAR, LAST_YEAR) &&
    isInteger(value["month"], 1, 12) &&
    isInteger(value["offset_days"], -MAX_OFFSET, MAX_OFFSET)
  );
}

function correctionProblems(value: unknown): FieldProblem[] {
  const field = "/hijri_corrections";
  if (!Array.isArray(value)) return [{ field, code: "invalid" }];
  const list: unknown[] = value;
  const malformed = list.flatMap((c, i) =>
    isWellFormedCorrection(c) ? [] : [{ field: `${field}/${String(i)}`, code: "invalid" as const }],
  );
  if (malformed.length > 0) return malformed;
  const corrections = list.filter(isWellFormedCorrection);
  const seen = new Set<string>();
  const duplicates: FieldProblem[] = [];
  corrections.forEach((c, i) => {
    const key = `${String(c.year)}/${String(c.month)}`;
    if (seen.has(key)) duplicates.push({ field: `${field}/${String(i)}`, code: "duplicate" });
    seen.add(key);
  });
  if (duplicates.length > 0) return duplicates;
  return areValidCorrections(corrections) ? [] : [{ field, code: "range" }];
}

function compare(a: FieldProblem, b: FieldProblem): number {
  if (a.field !== b.field) return a.field < b.field ? -1 : 1;
  return a.code < b.code ? -1 : a.code > b.code ? 1 : 0;
}

/**
 * practice_policy_validity: every problem with a policy document as `{field, code}`, pointers
 * into the document, sorted by field then code; empty when it's valid. The server checks every
 * put the same way and stays the authority.
 */
export function policyProblems(document: unknown): FieldProblem[] {
  if (!isObject(document)) return [{ field: "", code: "invalid" }];
  const problems: FieldProblem[] = Object.keys(document)
    .filter((key) => !(MEMBERS as readonly string[]).includes(key))
    .map((key) => ({ field: `/${key}`, code: "not_allowed" }));
  for (const member of MEMBERS) {
    const field = `/${member}`;
    if (!(member in document)) problems.push({ field, code: "required" });
    else if (member === "hijri_corrections") problems.push(...correctionProblems(document[member]));
    else if (!SETTINGS[member].includes(document[member])) problems.push({ field, code: "invalid" });
  }
  return problems.sort(compare);
}

/** The policy as clients write it: corrections sorted by year, then month. */
export function normalizedPolicy(policy: PracticePolicy): PracticePolicy {
  return { ...policy, hijri_corrections: sortCorrections(policy.hijri_corrections) };
}

/** Whether two policies say the same (member order aside). */
export function samePolicy(a: PracticePolicy, b: PracticePolicy): boolean {
  return (
    a.day_reset === b.day_reset &&
    a.calculation_method === b.calculation_method &&
    a.madhab === b.madhab &&
    a.week_start === b.week_start &&
    a.hijri_corrections.length === b.hijri_corrections.length &&
    a.hijri_corrections.every((c, i) => {
      const other = b.hijri_corrections[i];
      return other?.year === c.year && other.month === c.month && other.offset_days === c.offset_days;
    })
  );
}
