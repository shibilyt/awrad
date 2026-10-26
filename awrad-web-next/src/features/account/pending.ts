/**
 * The account flow in progress: the email a code was just sent to, and the
 * password to sign in with once it's verified ("verifying doesn't sign in",
 * root ADR-2026-10-26). In memory only: never in the URL, history state or
 * storage. A reload forgets it, and the screens then ask for the email and
 * send the person to sign in.
 */
export interface PendingAccount {
  email: string;
  password: string | null;
}

let pending: PendingAccount | null = null;

export function rememberPending(next: PendingAccount): void {
  pending = next;
}

export function readPending(): PendingAccount | null {
  return pending;
}

export function forgetPending(): void {
  pending = null;
}
