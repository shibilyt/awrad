import { queryOptions } from "@tanstack/react-query";
import { api, idempotencyKey, setCsrfToken } from "@/shared/api/client";
import { problemOf } from "@/shared/api/problem";
import type { components } from "@/shared/api/schema.gen";

/**
 * The account operations the web uses (tags `accounts` and `browser`). Each
 * throws an `ApiProblem` on failure. `device_sessions` are mobile-only and
 * never called here (ADR-2026-10-15).
 */
export type Account = components["schemas"]["Account"];

/** Retryable POSTs carry a fresh `Idempotency-Key` per user action (STYLE §10). */
function retryable() {
  return { header: { "Idempotency-Key": idempotencyKey() } };
}

/** `get_current_account`: the signed-in account, or `null` when this browser is signed out. */
export const currentAccountQuery = queryOptions({
  queryKey: ["account", "current"],
  retry: false,
  queryFn: async (): Promise<Account | null> => {
    const result = await api.GET("/api/v1/account");
    const problem = problemOf(result);
    if (problem?.code === "unauthenticated") return null;
    if (problem !== null) throw problem;
    return result.data ?? null;
  },
});

export async function registerAccount(email: string, password: string): Promise<void> {
  const problem = problemOf(await api.POST("/api/v1/accounts", { params: retryable(), body: { email, password } }));
  if (problem !== null) throw problem;
}

export async function verifyAccountEmail(email: string, code: string): Promise<void> {
  const result = await api.POST("/api/v1/accounts/verify_email", { params: retryable(), body: { email, code } });
  const problem = problemOf(result);
  if (problem !== null) throw problem;
}

export async function resendVerificationCode(email: string): Promise<void> {
  const result = await api.POST("/api/v1/accounts/resend_verification_code", { params: retryable(), body: { email } });
  const problem = problemOf(result);
  if (problem !== null) throw problem;
}

export async function requestPasswordReset(email: string): Promise<void> {
  const result = await api.POST("/api/v1/accounts/request_password_reset", { params: retryable(), body: { email } });
  const problem = problemOf(result);
  if (problem !== null) throw problem;
}

export async function resetPassword(email: string, code: string, newPassword: string): Promise<void> {
  const result = await api.POST("/api/v1/accounts/reset_password", {
    params: retryable(),
    body: { email, code, new_password: newPassword },
  });
  const problem = problemOf(result);
  if (problem !== null) throw problem;
}

/**
 * `create_browser_session`. Signing in renews the Phoenix session, so the
 * response's CSRF token replaces the anonymous one for every later write.
 */
export async function createBrowserSession(email: string, password: string, rememberMe: boolean): Promise<Account> {
  const result = await api.POST("/api/v1/browser/session", {
    params: retryable(),
    body: { email, password, remember_me: rememberMe },
  });
  const problem = problemOf(result);
  if (problem !== null) throw problem;
  if (result.data === undefined) throw new Error("create_browser_session returned no body");
  setCsrfToken(result.data.csrf_token);
  return result.data.account;
}

/**
 * `delete_browser_session`. `401` means the session had already ended, which
 * is what signing out wants. The old CSRF token dies with the session.
 */
export async function deleteBrowserSession(): Promise<void> {
  const problem = problemOf(await api.DELETE("/api/v1/browser/session"));
  setCsrfToken(null);
  if (problem !== null && problem.code !== "unauthenticated") throw problem;
}
