import { useQueryClient } from "@tanstack/react-query";
import { useNavigate } from "@tanstack/react-router";
import { createBrowserSession, currentAccountQuery, type Account } from "./api";
import { forgetPending, rememberPending } from "./pending";
import type { SignInNotice } from "./search";

/**
 * Signs in with a password the person already gave, after a step that
 * doesn't sign in itself (verify, reset). `null` when that sign-in fails: the
 * step still succeeded, so they're sent to sign in by hand instead.
 */
export async function signInAfter(email: string, password: string | null): Promise<Account | null> {
  if (password === null) return null;
  try {
    return await createBrowserSession(email, password, true);
  } catch {
    return null;
  }
}

/** Where to go after verify or reset: the account page when signed in, or sign-in with a notice. */
export function useFinishSignIn(notice: SignInNotice): (account: Account | null, email: string) => void {
  const queryClient = useQueryClient();
  const navigate = useNavigate();
  return (account, email) => {
    queryClient.setQueryData(currentAccountQuery.queryKey, account);
    if (account !== null) {
      forgetPending();
      void navigate({ to: "/account" });
    } else {
      rememberPending({ email, password: null });
      void navigate({ to: "/sign-in", search: { notice } });
    }
  };
}
