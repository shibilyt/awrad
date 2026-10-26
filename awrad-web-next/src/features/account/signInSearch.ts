export type SignInNotice = "verified" | "password_reset";

/** The sign-in page's search: only a notice from the screen before it, never personal data. */
export function signInSearch(search: Record<string, unknown>): { notice?: SignInNotice } {
  const { notice } = search;
  return notice === "verified" || notice === "password_reset" ? { notice } : {};
}
