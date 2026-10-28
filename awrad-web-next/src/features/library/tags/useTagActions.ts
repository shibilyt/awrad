import { useTranslation } from "react-i18next";
import { newUuidV7 } from "@/shared/identity";
import { normalizeTagName, type Edit, type SyncState, type TagName } from "@/shared/sync";
import {
  problemKey,
  settledKey,
  useEdit,
  wentThrough,
  type OpenConflict,
  type Refusal,
  type Settled,
} from "../custom/useEdit";

/** 100 active tags per account (contracts/sync/v1/README.md "Limits"). */
export const TAG_LIMIT = 100;

/**
 * What a tag action came to: done (with the tag's ID), or a message to show (`null` when the
 * "Change refused" dialog already says why).
 */
export type TagActionResult = { ok: true; tagId: string } | { ok: false; message: string | null };

const NAME_PROBLEMS = {
  empty: "library.tags.errors.empty",
  too_many_graphemes: "library.tags.errors.tooLong",
  too_many_bytes: "library.tags.errors.tooLong",
} as const;

/**
 * Creating, renaming and deleting the account's tags, each one command. Names go through the
 * shared tag-name rules first (the server recomputes them), and a name another tag already has
 * is caught here before the server would merge or refuse it.
 */
export function useTagActions(
  accountId: string,
  state: SyncState,
): {
  create: (input: string) => Promise<TagActionResult>;
  rename: (tagId: string, input: string) => Promise<TagActionResult>;
  remove: (tagId: string) => Promise<TagActionResult>;
  isPending: boolean;
  conflict: OpenConflict | null;
  refused: Refusal | null;
} {
  const { t } = useTranslation();
  const { send, isPending, conflict, refused } = useEdit(accountId);

  const owner = (name: TagName & { accepted: true }) =>
    Object.values(state.user_tag).find((tag) => tag.document.normalized_name === name.normalized_name);

  const run = async (edit: Edit, done: (settled: Settled) => string): Promise<TagActionResult> => {
    try {
      const settled = await send(edit);
      // Deleting something already deleted elsewhere is done all the same.
      if (wentThrough(settled) || (edit.op === "delete" && settled.status === "gone")) {
        return { ok: true, tagId: done(settled) };
      }
      const problem = settledKey(settled);
      return { ok: false, message: problem === null ? null : t(problem) };
    } catch (error) {
      return { ok: false, message: t(problemKey(error)) };
    }
  };

  const create = async (input: string): Promise<TagActionResult> => {
    const name = normalizeTagName(input);
    if (!name.accepted) return { ok: false, message: t(NAME_PROBLEMS[name.reason]) };
    const existing = owner(name);
    if (existing !== undefined) {
      return { ok: false, message: t("library.tags.errors.exists", { name: existing.document.name }) };
    }
    if (Object.keys(state.user_tag).length >= TAG_LIMIT) {
      return { ok: false, message: t("library.sync.rejected.tag_limit_reached") };
    }
    const id = newUuidV7();
    const document = { name: name.name, normalized_name: name.normalized_name };
    return run({ entity_type: "user_tag", entity_id: id, op: "put", base_version: 0, document }, (settled) =>
      settled.status === "merged" ? settled.mergedInto : id,
    );
  };

  const rename = async (tagId: string, input: string): Promise<TagActionResult> => {
    const tag = state.user_tag[tagId];
    if (tag === undefined) return { ok: false, message: t("library.sync.gone") };
    const name = normalizeTagName(input);
    if (!name.accepted) return { ok: false, message: t(NAME_PROBLEMS[name.reason]) };
    const existing = owner(name);
    if (existing !== undefined && existing.id !== tagId) {
      return { ok: false, message: t("library.sync.rejected.tag_name_taken") };
    }
    const document = { name: name.name, normalized_name: name.normalized_name };
    return run(
      { entity_type: "user_tag", entity_id: tagId, op: "put", base_version: tag.version, document },
      () => tagId,
    );
  };

  const remove = async (tagId: string): Promise<TagActionResult> => {
    const tag = state.user_tag[tagId];
    if (tag === undefined) return { ok: true, tagId };
    return run({ entity_type: "user_tag", entity_id: tagId, op: "delete", base_version: tag.version }, () => tagId);
  };

  return { create, rename, remove, isPending, conflict, refused };
}
