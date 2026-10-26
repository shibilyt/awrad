import { useQueryClient } from "@tanstack/react-query";
import { useNavigate } from "@tanstack/react-router";
import { useEffect } from "react";
import { setCsrfToken } from "@/shared/api/client";
import { ApiProblem } from "@/shared/api/problem";
import { forgetAccount } from "./api";

/**
 * True when an authenticated request was refused because this browser's
 * session is over: revoked from another device, ended by a password change
 * elsewhere, or expired.
 */
export function isSessionEnded(error: unknown): boolean {
  return error instanceof ApiProblem && error.code === "unauthenticated";
}

/**
 * Forgets everything cached for the account and shows sign-in with a
 * "your session ended" message. It leaves first, so the account pages don't
 * redirect on their own without the message.
 */
export function useEndSession(): () => Promise<void> {
  const queryClient = useQueryClient();
  const navigate = useNavigate();
  return async () => {
    setCsrfToken(null);
    await navigate({ to: "/sign-in", search: { notice: "session_ended" } });
    forgetAccount(queryClient);
  };
}

/** Ends the session when a query's error says it has ended. */
export function useEndSessionOn(error: unknown): void {
  const endSession = useEndSession();
  const ended = isSessionEnded(error);
  useEffect(() => {
    if (ended) void endSession();
  }, [ended, endSession]);
}
