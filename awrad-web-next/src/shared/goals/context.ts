import type { HijriCorrection } from "@/shared/practice";
import { indexCounts, type CountIndex } from "./counts";
import { day } from "./days";
import type { GoalInput, GoalOnDay } from "./types";

/** What the rules that look across days share: the goal, its counts, the day judged, and the Hijri corrections. */
export interface Judging {
  readonly input: GoalInput;
  readonly counts: CountIndex;
  /** The day it's judged on (usually today), as a day number. */
  readonly today: number;
  readonly corrections: readonly HijriCorrection[];
}

export function judging({ goal, counts, date }: GoalOnDay, corrections: readonly HijriCorrection[]): Judging {
  return { input: goal, counts: indexCounts(counts), today: day(date), corrections };
}
