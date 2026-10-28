import { queryOptions, type QueryClient } from "@tanstack/react-query";
import { api } from "@/shared/api/client";
import { problemOf } from "@/shared/api/problem";
import type { components } from "@/shared/api/schema.gen";

/**
 * Who is signed in to this browser, shared by every feature: the account pages, and the Library,
 * whose own dhikrs and tags belong to the account (slice 3b).
 */
export type Account = components["schemas"]["Account"];

/** Every query under this key belongs to the signed-in account. */
export const ACCOUNT_QUERY_KEY = ["account"] as const;

/** `get_current_account`: the signed-in account, or `null` when this browser is signed out. */
export const currentAccountQuery = queryOptions({
  queryKey: [...ACCOUNT_QUERY_KEY, "current"],
  retry: false,
  queryFn: async (): Promise<Account | null> => {
    const result = await api.GET("/api/v1/account");
    const problem = problemOf(result);
    if (problem?.code === "unauthenticated") return null;
    if (problem !== null) throw problem;
    return result.data ?? null;
  },
});

/**
 * Signed out (sign-out, session ended, account deleted): the current account
 * becomes `null`, which pages already watching it see, and everything else
 * cached for the account is dropped.
 */
export function forgetAccount(queryClient: QueryClient): void {
  queryClient.setQueryData(currentAccountQuery.queryKey, null);
  queryClient.removeQueries({
    queryKey: ACCOUNT_QUERY_KEY,
    predicate: (query) => query.queryKey[1] !== currentAccountQuery.queryKey[1],
  });
}
