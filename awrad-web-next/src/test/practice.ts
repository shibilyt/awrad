import type { HttpHandler } from "msw";
import { DEFAULT_POLICY, clock, type PracticePolicy } from "@/shared/practice";
import type { Change, Receipt } from "@/shared/sync";
import type { RecordedRequest } from "./render";
import { ACCOUNT_ID, receiptHandler, signedInWithEntities } from "./sync";

/**
 * The practice settings page's tests (slice 3d): the account's policy in the changes feed, a
 * conflict on it, the commands sent, and a fixed clock. Built on the spec's examples like the
 * Library's (`./sync`); the spec's changes example has no policy, so one is added to it.
 */

/** 11:30 in Kolkata on 29 October 2026: 18 Jumada al-Ula 1448, before Maghrib. */
export const NOW = "2026-10-29T06:00:00Z";
export const TIME_ZONE = "Asia/Kolkata";

const realClock = { ...clock };

/** Fixes the page's clock and time zone; `resetClock` puts the browser's back. */
export function setClock(now: string = NOW, timeZone: string = TIME_ZONE): void {
  clock.now = () => new Date(now);
  clock.timeZone = () => timeZone;
}

export function resetClock(): void {
  Object.assign(clock, realClock);
}

/** Signed in as the spec's account, with its entities and, when given, its practice policy. */
export function signedInWithPolicy(policy: PracticePolicy | null, version = 1): HttpHandler[] {
  return signedInWithEntities((changes) =>
    policy === null
      ? changes
      : [
          ...changes,
          {
            entity_type: "practice_policy",
            entity_id: ACCOUNT_ID,
            state: "active",
            version,
            revision: 16,
            document: policy,
          },
        ],
  );
}

/** A `conflict` receipt (the spec's, at index 3) whose server copy is `theirs` at `version`. */
export function policyConflict(theirs: PracticePolicy, version: number): HttpHandler {
  return receiptHandler((receipts) => ({
    ...(receipts[3] as Receipt & { status: "conflict" }),
    current: { version, state: "active", document: theirs as Change["document"] },
  }));
}

export interface SentCommand {
  entity_type: string;
  entity_id: string;
  op: string;
  base_version: number;
  document?: PracticePolicy;
}

/** Every command the page posted, in order. */
export function sentCommands(requests: RecordedRequest[]): SentCommand[] {
  return requests
    .filter((request) => request.method === "POST" && request.path === "/api/v1/sync/commands")
    .flatMap((post) => (post.body as { commands: SentCommand[] } | undefined)?.commands ?? []);
}

export const policyWith = (changes: Partial<PracticePolicy>): PracticePolicy => ({ ...DEFAULT_POLICY, ...changes });
