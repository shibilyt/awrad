import {
  queryOptions,
  useMutation,
  useQuery,
  useQueryClient,
  type QueryClient,
  type UseMutationResult,
  type UseQueryResult,
} from "@tanstack/react-query";
import { ApiProblem } from "@/shared/api/problem";
import { ACCOUNT_QUERY_KEY, currentAccountQuery, forgetAccount } from "@/shared/session";
import { fetchSyncState, sendEdit } from "./api";
import { EMPTY_STATE, applyReceipt } from "./state";
import type { Edit, EditResult, SyncState } from "./types";

/**
 * The account's entities in TanStack Query: read from the changes feed (every page from
 * `after=0`) when a page first needs them, updated from each edit's receipt at once, and read
 * again after each edit. Keyed by the account, under `ACCOUNT_QUERY_KEY`, so signing out drops
 * them and another account never sees them.
 */
function options(accountId: string) {
  return queryOptions({
    queryKey: [...ACCOUNT_QUERY_KEY, "sync", accountId],
    queryFn: () => fetchSyncState(accountId),
    retry: false,
  });
}

export type SyncQuery = ReturnType<typeof options>;

/** The query options for an account's entities: the cache key, and how to read them. */
export function syncQuery(accountId: string): SyncQuery {
  return options(accountId);
}

/** The signed-in account's entities; idle (no request) while signed out or not known yet. */
export function useSyncState(accountId: string | null): UseQueryResult<SyncState> {
  return useQuery({ ...syncQuery(accountId ?? ""), enabled: accountId !== null });
}

/**
 * The browser's session doesn't belong to the account this page shows: signed out (`401`), or
 * another account signed in from another tab (`409 account_mismatch`). Either way the page goes
 * back to who is really signed in.
 */
function onSessionProblem(queryClient: QueryClient, error: unknown): void {
  if (!(error instanceof ApiProblem)) return;
  if (error.code === "unauthenticated") forgetAccount(queryClient);
  if (error.code === "account_mismatch") {
    queryClient.removeQueries({ queryKey: [...ACCOUNT_QUERY_KEY, "sync"] });
    void queryClient.invalidateQueries({ queryKey: currentAccountQuery.queryKey });
  }
}

/**
 * Sends one edit as a one-command batch, applies its receipt to the cache, rereads the changes
 * feed, and resolves to what became of the edit (`EditResult`). It rejects with an `ApiProblem`
 * (or a network error) when the batch itself failed; nothing was applied then.
 */
export function useSendEdit(accountId: string): UseMutationResult<EditResult, Error, Edit> {
  const queryClient = useQueryClient();
  const { queryKey } = syncQuery(accountId);
  return useMutation({
    mutationFn: async (edit: Edit): Promise<EditResult> => {
      const receipt = await sendEdit(accountId, edit);
      const applied = applyReceipt(queryClient.getQueryData<SyncState>(queryKey) ?? EMPTY_STATE, edit, receipt);
      queryClient.setQueryData(queryKey, applied.state);
      // Every page, even one no longer on screen, sees the server's state next.
      void queryClient.invalidateQueries({ queryKey, refetchType: "all" });
      return applied.result;
    },
    onError: (error) => {
      onSessionProblem(queryClient, error);
    },
  });
}

/** Watches a read of the feed for the same session problems as an edit. */
export function useSessionProblem(): (error: unknown) => void {
  const queryClient = useQueryClient();
  return (error) => {
    onSessionProblem(queryClient, error);
  };
}
