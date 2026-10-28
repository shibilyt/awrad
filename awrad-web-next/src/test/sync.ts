import type { HttpHandler } from "msw";
import type { Change, CustomDhikrDocument, Receipt } from "@/shared/sync";
import { specHandler } from "./spec";

/**
 * A signed-in account with custom dhikrs and tags, for the Library's tests (and the screenshots'
 * mocks): built from the spec's own examples (`get_current_account`, `list_sync_changes`,
 * `post_sync_commands`), so the shapes can't drift from the contract.
 */

export const ACCOUNT_ID = "0b6f6a1e-6c1f-4b8e-9a51-2f3d7c1e8a90"; // get_current_account's example
export const TAHLEEL_ID = "6f04f77e-dcb6-4a29-9dc5-fcd3649c2961"; // the built-in tahleel
export const HASBI_ID = "0192f0d0-0000-7000-8000-000000000002"; // the custom dhikr in the spec's examples
export const MORNING_DHIKR_ID = "0192f0d0-0000-7000-8000-000000000005";
export const MORNING_TAG_ID = "0192f0a0-0000-7000-8000-000000000001";
export const EVENING_TAG_ID = "0192f0a0-0000-7000-8000-000000000002";

export const MORNING_DHIKR: CustomDhikrDocument = {
  kind: "dhikr",
  arabic: "أَصْبَحْنَا وَأَصْبَحَ ٱلْمُلْكُ لِلَّهِ",
  title: { en: "Morning words", ar: null, ml: null },
  transliteration: { en: "Asbahna wa asbahal-mulku lillah", ml: null },
  translation: { en: "We have reached the morning, and the dominion belongs to Allah.", ar: null, ml: null },
  audio: { local_only: true },
  references: [{ id: "ref-1", type: "hadith", collection: "Sahih Muslim", number: "2723" }],
};

interface ChangesPage {
  changes: Change[];
  next_after: number;
  has_more: boolean;
  head_revision: number;
}

/** The changes the account has: the spec's custom dhikr, one more, two tags and their uses. */
export function accountChanges(example: Change[]): Change[] {
  const hasbi = example.find((change) => change.entity_id === HASBI_ID);
  if (hasbi === undefined) throw new Error("the spec's changes example has no custom dhikr");
  const change = (
    entityType: Change["entity_type"],
    entityId: string,
    revision: number,
    document: Change["document"],
  ): Change => ({ entity_type: entityType, entity_id: entityId, state: "active", version: 1, revision, document });
  return [
    hasbi,
    change("custom_dhikr", MORNING_DHIKR_ID, 12, MORNING_DHIKR as Change["document"]),
    change("user_tag", MORNING_TAG_ID, 13, { name: "Morning", normalized_name: "morning" }),
    change("user_tag", EVENING_TAG_ID, 14, { name: "Evening", normalized_name: "evening" }),
    change("dhikr_personal", TAHLEEL_ID, 15, { tag_ids: [MORNING_TAG_ID, EVENING_TAG_ID] }),
    change("dhikr_personal", MORNING_DHIKR_ID, 16, { tag_ids: [MORNING_TAG_ID] }),
  ];
}

/** `list_sync_changes`: one page holding `pick` of the account's changes (all of them by default), once or always. */
export function changesHandler(
  pick: (changes: Change[]) => Change[] = (changes) => changes,
  once = false,
): HttpHandler {
  return specHandler("list_sync_changes", 200, {
    once,
    from: (example: ChangesPage) => ({
      ...example,
      changes: pick(accountChanges(example.changes)),
      has_more: false,
      next_after: 16,
      head_revision: 16,
    }),
  });
}

/** Signed in as the spec's account, with its entities. */
export function signedInWithEntities(pick?: (changes: Change[]) => Change[]): HttpHandler[] {
  return [specHandler("get_current_account", 200), specHandler("get_browser_csrf_token", 200), changesHandler(pick)];
}

/** `post_sync_commands` answering once with `receipt` (its command_id is the spec's). */
export function receiptHandler(receipt: (example: Receipt[]) => Receipt): HttpHandler {
  return specHandler("post_sync_commands", 200, {
    once: true,
    from: (example: { receipts: Receipt[]; head_revision: number }) => ({
      ...example,
      receipts: [receipt(example.receipts)],
    }),
  });
}

/** The receipt the spec's example has at `index` (0 applied, 1 merged, 3 conflict, 4 gone, 5 rejected, 6 duplicate). */
export function exampleReceipt(index: number): HttpHandler {
  return receiptHandler((receipts) => {
    const receipt = receipts[index];
    if (receipt === undefined) throw new Error(`the spec's receipts example has no receipt ${String(index)}`);
    return receipt;
  });
}

/** An `applied` receipt at `version`. */
export function applied(version: number): HttpHandler {
  return receiptHandler((receipts) => ({ ...(receipts[0] as Receipt & { status: "applied" }), version, revision: 17 }));
}
