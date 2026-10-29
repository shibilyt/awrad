import { useQueryClient } from "@tanstack/react-query";
import { useRef, useState } from "react";
import {
  DEFAULT_POLICY,
  mergePolicy,
  normalizedPolicy,
  policyProblems,
  samePolicy,
  type MergeNotice,
  type PracticePolicy,
} from "@/shared/practice";
import { syncQuery, useSendEdit, type Entity, type RejectionCode, type SyncState } from "@/shared/sync";

/** One edit of the policy, applied to whatever the server's copy is when it's sent. */
export type PolicyChange = (policy: PracticePolicy) => PracticePolicy;

/** Why the last edit didn't go through as made. */
export type EditFailure =
  { kind: "rejected"; code: RejectionCode } | { kind: "invalid" } | { kind: "problem"; error: unknown };

/** A conflict is merged and sent again; this many times in a row means something else is wrong. */
const MAX_SENDS = 3;

/**
 * Edits of the account practice policy (contracts/practice-settings/v1, "Syncing the policy").
 * Each change is a one-command batch, a put on the version the page has, sent one after another
 * so each builds on the last. The page shows its pending changes over the server's copy at once.
 * A `conflict` is merged by setting with the copy it was edited from as the base, and the merge
 * sent on the server's version, with no prompt (`hijri_corrections_replaced` becomes a notice).
 * An account with no policy yet gets one from its first edit: `base_version` 0, its own ID.
 */
export function usePolicyEditor(accountId: string): {
  policy: (server: PracticePolicy) => PracticePolicy;
  change: (change: PolicyChange) => void;
  notice: MergeNotice | null;
  failure: EditFailure | null;
} {
  const queryClient = useQueryClient();
  const { mutateAsync } = useSendEdit(accountId);
  const [pending, setPending] = useState<readonly PolicyChange[]>([]);
  const [notice, setNotice] = useState<MergeNotice | null>(null);
  const [failure, setFailure] = useState<EditFailure | null>(null);
  const queue = useRef<Promise<void>>(Promise.resolve());

  const loaded = (): Entity<PracticePolicy> | undefined =>
    queryClient.getQueryData<SyncState>(syncQuery(accountId).queryKey)?.practice_policy[accountId];

  const send = async (change: PolicyChange): Promise<void> => {
    const entity = loaded();
    let base = entity?.document ?? DEFAULT_POLICY;
    let version = entity?.version ?? 0;
    let mine = normalizedPolicy(change(base));
    if (policyProblems(mine).length > 0) {
      setFailure({ kind: "invalid" });
      return;
    }
    for (let attempt = 0; attempt < MAX_SENDS && !samePolicy(mine, normalizedPolicy(base)); attempt += 1) {
      const result = await mutateAsync({
        entity_type: "practice_policy",
        entity_id: accountId,
        op: "put",
        base_version: version,
        document: mine,
      });
      if (result.status === "rejected") setFailure({ kind: "rejected", code: result.code });
      if (result.status !== "conflict") return;
      const theirs = (result.current.document as PracticePolicy | null) ?? DEFAULT_POLICY;
      const merged = mergePolicy(base, mine, theirs);
      if (merged.notice !== null) setNotice(merged.notice);
      if (!merged.requeue) return;
      [base, version, mine] = [theirs, result.current.version, merged.document];
    }
    if (!samePolicy(mine, normalizedPolicy(base))) throw new Error("practice_policy kept conflicting");
  };

  const change = (next: PolicyChange): void => {
    setFailure(null);
    setNotice(null);
    setPending((changes) => [...changes, next]);
    queue.current = queue.current
      .then(() => send(next))
      .catch((error: unknown) => {
        setFailure({ kind: "problem", error });
      })
      .finally(() => {
        setPending((changes) => changes.filter((c) => c !== next));
      });
  };

  return {
    policy: (server) => pending.reduce((policy, next) => next(policy), server),
    change,
    notice,
    failure,
  };
}
