import { queryOptions, type QueryClient } from "@tanstack/react-query";
import { api, idempotencyKey, setCsrfToken } from "@/shared/api/client";
import { ApiProblem, problemOf } from "@/shared/api/problem";
import type { components } from "@/shared/api/schema.gen";
import { currentAccountQuery, type Account } from "../api";

/**
 * The account settings operations (tag `account_settings`, slice 2b). The
 * browser calls them with its cookie session, and the client adds
 * `X-CSRF-Token` to every change. Each throws an `ApiProblem` on failure;
 * `401 unauthenticated` means the session has ended (`sessionEnded.ts`).
 */
export type AccountSession = components["schemas"]["AccountSession"];

/** Every query under this key belongs to the signed-in account. */
const ACCOUNT_QUERY_KEY = ["account"] as const;

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

const PAGE_SIZE = 100;
/** Pages are followed to the end, but not forever: an account rarely has more than one. */
const MAX_PAGES = 10;

function retryable() {
  return { header: { "Idempotency-Key": idempotencyKey() } };
}

function throwIfProblem(result: { error?: unknown; response: Response }): void {
  const problem = problemOf(result);
  if (problem !== null) throw problem;
}

/** `list_account_sessions`, every page: phones and browsers, most recently used first. */
export const accountSessionsQuery = queryOptions({
  queryKey: [...ACCOUNT_QUERY_KEY, "sessions"],
  retry: false,
  queryFn: async (): Promise<AccountSession[]> => {
    const sessions: AccountSession[] = [];
    let cursor: string | null = null;
    for (let page = 0; page < MAX_PAGES; page += 1) {
      const query: { limit: number; cursor?: string } =
        cursor === null ? { limit: PAGE_SIZE } : { limit: PAGE_SIZE, cursor };
      const result = await api.GET("/api/v1/account/sessions", { params: { query } });
      throwIfProblem(result);
      if (result.data === undefined) throw new ApiProblem({ code: "unexpected_response", status: 200, detail: "" });
      sessions.push(...result.data.items);
      cursor = result.data.next_cursor;
      if (cursor === null) break;
    }
    return sessions;
  },
});

/** `revoke_account_session`. `404 not_found`: it isn't this account's, or it had already ended. */
export async function revokeAccountSession(sessionId: string): Promise<void> {
  throwIfProblem(
    await api.DELETE("/api/v1/account/sessions/{session_id}", { params: { path: { session_id: sessionId } } }),
  );
}

/** `revoke_other_account_sessions`: every session except this browser's. */
export async function revokeOtherAccountSessions(): Promise<void> {
  throwIfProblem(await api.POST("/api/v1/account/sessions/revoke_others", { params: retryable() }));
}

/** `change_password`: other sessions end; this one stays signed in. */
export async function changePassword(currentPassword: string, newPassword: string): Promise<void> {
  throwIfProblem(
    await api.POST("/api/v1/account/change_password", {
      params: retryable(),
      body: { current_password: currentPassword, new_password: newPassword },
    }),
  );
}

/** `request_email_change`: a code goes to the new address. Asking again cancels the previous code. */
export async function requestEmailChange(currentPassword: string, newEmail: string): Promise<void> {
  throwIfProblem(
    await api.POST("/api/v1/account/request_email_change", {
      params: retryable(),
      body: { current_password: currentPassword, new_email: newEmail },
    }),
  );
}

/** `confirm_email_change`: the account, now with its new email. */
export async function confirmEmailChange(code: string): Promise<Account> {
  const result = await api.POST("/api/v1/account/confirm_email_change", { params: retryable(), body: { code } });
  throwIfProblem(result);
  if (result.data === undefined) throw new ApiProblem({ code: "unexpected_response", status: 200, detail: "" });
  return result.data;
}

/** `delete_account`: the account is gone and every session ended, this one too, so its CSRF token goes. */
export async function deleteAccount(currentPassword: string): Promise<void> {
  throwIfProblem(
    await api.POST("/api/v1/account/delete", { params: retryable(), body: { current_password: currentPassword } }),
  );
  setCsrfToken(null);
}
