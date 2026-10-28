import { api } from "@/shared/api/client";
import { problemOf } from "@/shared/api/problem";
import { newUuidV7 } from "@/shared/identity";
import { EMPTY_STATE, applyChanges } from "./state";
import type { Edit, Receipt, SyncState } from "./types";

/**
 * The two change-queue operations (contracts/api/paths/sync.yaml), as the web calls them: with
 * its cookie session (and, for the POST, CSRF, which the client adds), and `X-Awrad-Account`
 * naming the signed-in account, so the server refuses (`409 account_mismatch`) if this tab still
 * believes in an account another tab has signed out of. Each throws an `ApiProblem` on failure.
 */

export const PAGE_SIZE = 200;
/** 1,000 custom dhikrs, 100 tags and their personal records are about a dozen pages; stop well past that. */
const MAX_PAGES = 100;

/**
 * `list_sync_changes` from `after=0`, every page: all of the account's active entities. A page
 * never splits a revision, and an entity changed while we read reappears (or is deleted) on a
 * later page, so applying pages in order leaves each entity's latest state.
 */
export async function fetchSyncState(accountId: string): Promise<SyncState> {
  let state = EMPTY_STATE;
  let after = 0;
  for (let page = 0; page < MAX_PAGES; page += 1) {
    const result = await api.GET("/api/v1/sync/changes", {
      params: { header: { "X-Awrad-Account": accountId }, query: { after, limit: PAGE_SIZE } },
    });
    const problem = problemOf(result);
    if (problem !== null) throw problem;
    if (result.data === undefined) throw new Error("list_sync_changes returned no body");
    const { changes, next_after: nextAfter, has_more: hasMore, head_revision: head } = result.data;
    state = applyChanges(state, changes, head);
    if (!hasMore) return state;
    if (nextAfter <= after) throw new Error("list_sync_changes didn't move past its after");
    after = nextAfter;
  }
  throw new Error(`list_sync_changes has more than ${String(MAX_PAGES)} pages`);
}

/** The document as the wire types have it (references are the catalog's shape, typed loosely there). */
function wire(edit: Edit) {
  const command = { command_id: newUuidV7(), ...edit };
  if (command.op === "delete") return command;
  if (command.entity_type !== "custom_dhikr") return command;
  return { ...command, document: { ...command.document, references: [...command.document.references] } };
}

/**
 * `post_sync_commands` with one command: the web sends each edit on its own, straight away, with
 * a new UUIDv7 `command_id`. The receipt for it.
 */
export async function sendEdit(accountId: string, edit: Edit): Promise<Receipt> {
  const result = await api.POST("/api/v1/sync/commands", {
    params: { header: { "X-Awrad-Account": accountId } },
    body: { commands: [wire(edit)] },
  });
  const problem = problemOf(result);
  if (problem !== null) throw problem;
  const receipt = result.data?.receipts[0];
  if (receipt === undefined) throw new Error("post_sync_commands returned no receipt");
  return receipt;
}
