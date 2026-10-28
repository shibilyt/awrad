import { useState } from "react";
import { ApiProblem } from "@/shared/api/problem";
import { useSendEdit, type Current, type Edit, type EditResult, type RejectionCode } from "@/shared/sync";

/** What an edit came to once any conflict is settled: as sent, or the server's copy kept ("Use theirs"). */
export type Settled = Exclude<EditResult, { status: "conflict" }> | { status: "theirs" };

/** An open conflict: the server's copy, the edit the person made, and their choice. */
export interface OpenConflict {
  current: Current;
  edit: Edit;
  choose: (keepMine: boolean) => void;
}

/**
 * Sends edits for the Library's pages. A `conflict` receipt waits for the person's choice in the
 * conflict dialog (`ConflictDialog`, given `conflict`): **Use theirs** keeps the server's copy, now
 * in the cache; **Keep mine** sends the same edit again on the server's version. `send` resolves
 * once that's settled. A failed batch rejects (an `ApiProblem`, or a network error).
 */
export function useEdit(accountId: string): {
  send: (edit: Edit) => Promise<Settled>;
  isPending: boolean;
  conflict: OpenConflict | null;
} {
  const { mutateAsync, isPending } = useSendEdit(accountId);
  const [conflict, setConflict] = useState<OpenConflict | null>(null);

  const send = async (edit: Edit): Promise<Settled> => {
    const result = await mutateAsync(edit);
    if (result.status !== "conflict") return result;
    const keepMine = await new Promise<boolean>((resolve) => {
      setConflict({ current: result.current, edit, choose: resolve });
    });
    setConflict(null);
    if (!keepMine) return { status: "theirs" };
    return send({ ...edit, base_version: result.current.version });
  };

  return { send, isPending, conflict };
}

/** Problem codes the Library explains (sync.yaml's x-error-codes); anything else is "unexpected". */
const PROBLEM_CODES: ReadonlySet<string> = new Set([
  "unauthenticated",
  "csrf_token_invalid",
  "account_mismatch",
  "rate_limited",
]);

/** The translation key for an edit or read that failed as a whole, by `code` only, never `detail`. */
export function problemKey(error: unknown): string {
  if (!(error instanceof ApiProblem)) return "library.sync.problems.network";
  return PROBLEM_CODES.has(error.code) ? `library.sync.problems.${error.code}` : "library.sync.problems.unexpected";
}

const REJECTION_CODES: ReadonlySet<RejectionCode> = new Set<RejectionCode>([
  "document_invalid",
  "document_too_large",
  "custom_dhikr_limit_reached",
  "tag_limit_reached",
  "tag_name_taken",
  "tag_not_found",
  "dhikr_not_found",
  "entity_not_found",
]);

/**
 * The translation key for a settled edit that didn't go through, or `null` when it did: a
 * rejection by its code, or something deleted on another device in the meantime.
 */
export function settledKey(settled: Settled): string | null {
  switch (settled.status) {
    case "applied":
    case "merged":
    case "theirs":
      return null;
    case "gone":
      return "library.sync.gone";
    case "rejected":
      return REJECTION_CODES.has(settled.code)
        ? `library.sync.rejected.${settled.code}`
        : "library.sync.problems.unexpected";
  }
}
