import type { GoalOrderDocument } from "./types";
import { sameJson } from "./versions";

/**
 * Merging a conflicting `goal_order` without asking (goal_order_merge.json, decision 25),
 * like the practice policy: unchanged here, take theirs; otherwise mine, less the goals the
 * server dropped since the base, plus those it added, appended in its order. `requeue` when the
 * result differs from theirs, to send on the server's version.
 */
export function mergeGoalOrder(
  base: GoalOrderDocument,
  mine: GoalOrderDocument,
  theirs: GoalOrderDocument,
): { document: GoalOrderDocument; requeue: boolean } {
  if (sameJson(mine, base)) return { document: theirs, requeue: false };
  const removedThere = new Set(base.goal_ids.filter((id) => !theirs.goal_ids.includes(id)));
  const ids = mine.goal_ids.filter((id) => !removedThere.has(id));
  for (const id of theirs.goal_ids) {
    if (!ids.includes(id) && !base.goal_ids.includes(id)) ids.push(id);
  }
  const document = { goal_ids: ids };
  return { document, requeue: !sameJson(document, theirs) };
}
