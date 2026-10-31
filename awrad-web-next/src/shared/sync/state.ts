import type {
  CascadedChange,
  Change,
  Current,
  DocumentOf,
  Edit,
  EditResult,
  Entity,
  EntityType,
  Receipt,
  RejectedField,
  SyncState,
} from "./types";

/**
 * The web's copy of the account's entities, and how changes and receipts update it. Pure: the
 * query cache (`query.ts`) holds the result. The web has no queue, so there's never a local edit
 * to protect: the server's word always wins here, and the changes feed is reread after each edit.
 */

export const EMPTY_STATE: SyncState = {
  custom_dhikr: {},
  user_tag: {},
  dhikr_personal: {},
  practice_policy: {},
  goal: {},
  goal_order: {},
  headRevision: 0,
};

/** A copy of the state being changed. */
type Draft = { -readonly [T in EntityType]: Record<string, Entity<DocumentOf[T]>> } & { headRevision: number };

function copy(state: SyncState): Draft {
  return {
    custom_dhikr: { ...state.custom_dhikr },
    user_tag: { ...state.user_tag },
    dhikr_personal: { ...state.dhikr_personal },
    practice_policy: { ...state.practice_policy },
    goal: { ...state.goal },
    goal_order: { ...state.goal_order },
    headRevision: state.headRevision,
  };
}

/** Sets an entity. Documents come from the server (or an applied edit) for that entity type. */
function put(next: Draft, type: EntityType, id: string, version: number, document: unknown): void {
  (next[type] as Record<string, Entity<unknown>>)[id] = { id, version, document };
}

function remove(next: Draft, type: EntityType, id: string): void {
  const entities: Record<string, unknown> = next[type];
  // A record this module copied, keyed by entity ID.
  // eslint-disable-next-line @typescript-eslint/no-dynamic-delete
  delete entities[id];
  // The server's cascades, so the page is right before the feed is reread: a deleted custom
  // dhikr takes its personal record with it, and a deleted tag leaves every dhikr.
  if (type === "custom_dhikr") remove(next, "dhikr_personal", id);
  if (type === "user_tag") {
    for (const [dhikrId, entity] of Object.entries(next.dhikr_personal)) {
      const tagIds = entity.document.tag_ids.filter((tagId) => tagId !== id);
      if (tagIds.length !== entity.document.tag_ids.length) {
        next.dhikr_personal[dhikrId] = { ...entity, document: { tag_ids: tagIds } };
      }
    }
  }
}

/** A changes page applied in order: an active entity replaces ours, a deleted one goes. */
export function applyChanges(state: SyncState, changes: readonly Change[], headRevision: number): SyncState {
  const next = copy(state);
  for (const change of changes) {
    if (change.state === "deleted" || change.document === null) remove(next, change.entity_type, change.entity_id);
    else put(next, change.entity_type, change.entity_id, change.version, change.document);
  }
  next.headRevision = Math.max(next.headRevision, headRevision);
  return next;
}

/** The server's copy of the entity takes the place of ours: active, or gone. */
function adopt(next: Draft, type: EntityType, id: string, current: Current | null): void {
  if (current === null || current.state === "deleted" || current.document === null) remove(next, type, id);
  else put(next, type, id, current.version, current.document);
}

/**
 * An `applied` receipt's `cascaded` entries (a tag or custom dhikr delete): the entities the
 * server changed at the same revision. `remove` already made the same change to the documents, so
 * an active entry only takes its version; a deleted one goes.
 */
function applyCascaded(next: Draft, cascaded: readonly CascadedChange[] | null): void {
  for (const change of cascaded ?? []) {
    const entity = next[change.entity_type][change.entity_id];
    if (change.state === "deleted") remove(next, change.entity_type, change.entity_id);
    else if (entity !== undefined) put(next, change.entity_type, change.entity_id, change.version, entity.document);
  }
}

function rejectedFields(fields: readonly { field: string; code: RejectedField["code"] }[]): RejectedField[] {
  return fields.map(({ field, code }) => ({ field: field.replace(/^\/document(?=\/|$)/, ""), code }));
}

/**
 * Applies an edit's receipt to the state and says what became of it:
 * - `applied`: the edit as the server now has it (a put's document, or gone), and the versions
 *   of the entities it cascaded to (`cascaded`);
 * - `duplicate`: as its original receipt;
 * - `conflict`: the server's copy, which the user may keep or override (Keep mine);
 * - `merged`: the surviving tag, under its own ID;
 * - `gone`: removed;
 * - `rejected`: the server's copy, or removed when it has none.
 */
export function applyReceipt(state: SyncState, edit: Edit, receipt: Receipt): { state: SyncState; result: EditResult } {
  const outcome = receipt.status === "duplicate" ? receipt.original : receipt;
  const next = copy(state);
  const { entity_type: type, entity_id: id } = edit;
  let result: EditResult;
  switch (outcome.status) {
    case "applied":
      if (edit.op === "put") put(next, type, id, outcome.version, edit.document);
      else remove(next, type, id);
      applyCascaded(next, outcome.cascaded);
      next.headRevision = Math.max(next.headRevision, outcome.revision);
      result = { status: "applied", version: outcome.version };
      break;
    case "conflict":
      adopt(next, type, id, outcome.current);
      result = { status: "conflict", edit, current: outcome.current };
      break;
    case "merged":
      adopt(next, "user_tag", outcome.merged_into, outcome.current);
      result = { status: "merged", mergedInto: outcome.merged_into };
      break;
    case "gone":
      remove(next, type, id);
      result = { status: "gone" };
      break;
    case "rejected":
      adopt(next, type, id, outcome.current);
      result = { status: "rejected", code: outcome.code, fields: rejectedFields(outcome.fields) };
      break;
  }
  return { state: next, result };
}

/** The version to base the next edit of an entity on: what the server last said, or 0 to create it. */
export function knownVersion(state: SyncState, type: EntityType, id: string): number {
  return state[type][id]?.version ?? 0;
}
