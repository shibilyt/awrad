/**
 * The email change in progress: the new address the code went to, and the
 * password that asked for it, so "send a new code" can ask again. In memory
 * only, like `../pending.ts`: never in the URL, history state or storage. After
 * a reload the code still works, but a new code means starting again.
 */
export interface PendingEmailChange {
  newEmail: string;
  currentPassword: string;
}

let pending: PendingEmailChange | null = null;

export function rememberEmailChange(next: PendingEmailChange): void {
  pending = next;
}

export function readEmailChange(): PendingEmailChange | null {
  return pending;
}

export function forgetEmailChange(): void {
  pending = null;
}
