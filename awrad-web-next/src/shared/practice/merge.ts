import { areValidCorrections, sortCorrections, type HijriCorrection } from "./hijri";
import { normalizedPolicy, samePolicy, type PracticePolicy } from "./policy";

/** Why the user is told something after a merge (sync.schema.json `notice_code`). */
export type MergeNotice = "hijri_corrections_replaced";

export interface MergeResult {
  /** The merged policy, corrections sorted. */
  document: PracticePolicy;
  /** Whether it differs from theirs, so it must be sent on their version. */
  requeue: boolean;
  notice: MergeNotice | null;
}

const keyOf = (c: HijriCorrection): string => `${String(c.year)}/${String(c.month)}`;
const sameCorrection = (a: HijriCorrection | undefined, b: HijriCorrection | undefined): boolean =>
  a === undefined || b === undefined ? a === b : a.offset_days === b.offset_days;

/** Hijri corrections month by month: a month mine added, changed or removed from the base wins; their other months stay. */
function mergeCorrections(base: PracticePolicy, mine: PracticePolicy, theirs: PracticePolicy): HijriCorrection[] {
  const byMonth = (list: readonly HijriCorrection[]) => new Map(list.map((c) => [keyOf(c), c]));
  const ours = byMonth(mine.hijri_corrections);
  const original = byMonth(base.hijri_corrections);
  const result = byMonth(theirs.hijri_corrections);
  for (const key of new Set([...original.keys(), ...ours.keys()])) {
    const own = ours.get(key);
    if (sameCorrection(own, original.get(key))) continue;
    if (own === undefined) result.delete(key);
    else result.set(key, own);
  }
  return sortCorrections([...result.values()]);
}

/**
 * practice_policy_merge: after a conflict, every setting where `mine` differs from `base` (the
 * server copy it was edited from) keeps mine, and the rest is theirs; Hijri corrections merge
 * month by month. If the merged corrections aren't valid, theirs are kept, with a notice.
 */
export function mergePolicy(base: PracticePolicy, mine: PracticePolicy, theirs: PracticePolicy): MergeResult {
  let corrections = mergeCorrections(base, mine, theirs);
  let notice: MergeNotice | null = null;
  if (!areValidCorrections(corrections)) {
    corrections = sortCorrections(theirs.hijri_corrections);
    notice = "hijri_corrections_replaced";
  }
  const document: PracticePolicy = {
    day_reset: mine.day_reset !== base.day_reset ? mine.day_reset : theirs.day_reset,
    calculation_method:
      mine.calculation_method !== base.calculation_method ? mine.calculation_method : theirs.calculation_method,
    madhab: mine.madhab !== base.madhab ? mine.madhab : theirs.madhab,
    week_start: mine.week_start !== base.week_start ? mine.week_start : theirs.week_start,
    hijri_corrections: corrections,
  };
  return { document, requeue: !samePolicy(document, normalizedPolicy(theirs)), notice };
}
