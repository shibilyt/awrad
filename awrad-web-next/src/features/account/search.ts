export type SignInNotice = "verified" | "password_reset" | "session_ended";
const SIGN_IN_NOTICES: readonly unknown[] = ["verified", "password_reset", "session_ended"] satisfies SignInNotice[];

/** The sign-in page's search: only a notice from the screen before it, never personal data. */
export function signInSearch(search: Record<string, unknown>): { notice?: SignInNotice } {
  const { notice } = search;
  return SIGN_IN_NOTICES.includes(notice) ? { notice: notice as SignInNotice } : {};
}

export type AccountNotice = "password_changed" | "email_changed";
const ACCOUNT_NOTICES: readonly unknown[] = ["password_changed", "email_changed"] satisfies AccountNotice[];

/** The account page's search: a notice after a settings change. */
export function accountSearch(search: Record<string, unknown>): { notice?: AccountNotice } {
  const { notice } = search;
  return ACCOUNT_NOTICES.includes(notice) ? { notice: notice as AccountNotice } : {};
}

export type HomeNotice = "account_deleted";

/** Home's search: a notice after the account was deleted. */
export function homeSearch(search: Record<string, unknown>): { notice?: HomeNotice } {
  return search["notice"] === "account_deleted" ? { notice: "account_deleted" } : {};
}
