import { useNavigate } from "@tanstack/react-router";
import { useState } from "react";
import { useTranslation } from "react-i18next";
import { newUuidV7 } from "@/shared/identity";
import {
  customDhikrProblems,
  type CustomDhikrDocument,
  type Entity,
  type FieldProblem,
  type SyncState,
} from "@/shared/sync";
import { tagIdsOf } from "../custom/data";
import {
  problemKey,
  settledKey,
  useEdit,
  wentThrough,
  type OpenConflict,
  type Refusal,
  type Settled,
} from "../custom/useEdit";
import { documentFrom, errorMessages, type EditorValues } from "./form";

function sameTags(a: readonly string[], b: readonly string[]): boolean {
  return a.length === b.length && a.every((id, index) => id === b[index]);
}

/**
 * Saving the editor: the shared validity rules first (the server stays the authority), then the
 * dhikr as one command, then its tags as another when they changed, each on the version the
 * editor opened with, so a change made elsewhere meanwhile is a conflict, not lost. Afterwards it
 * goes to the dhikr's page.
 */
export function useSaveDhikr(
  accountId: string,
  state: SyncState,
  existing: Entity<CustomDhikrDocument> | null,
): {
  save: (values: EditorValues) => Promise<void>;
  errors: Record<string, string>;
  alert: string | null;
  isPending: boolean;
  conflict: OpenConflict | null;
  refused: Refusal | null;
} {
  const { t } = useTranslation();
  const navigate = useNavigate();
  const { send, isPending, conflict, refused } = useEdit(accountId);
  // Fixed when the editor opens: a new dhikr's ID, and the versions the edit is based on.
  const [id] = useState(() => existing?.id ?? newUuidV7());
  const [base, setBase] = useState(() => ({
    dhikr: existing?.version ?? 0,
    personal: state.dhikr_personal[id]?.version ?? 0,
    tagIds: tagIdsOf(state, id),
  }));
  const [problems, setProblems] = useState<FieldProblem[]>([]);
  const [alert, setAlert] = useState<string | null>(null);

  // Why an edit didn't go through, under the form; a refusal's reason is in its own dialog.
  const showSettled = (settled: Settled) => {
    const key = settledKey(settled);
    setAlert(key === null ? null : t(key));
  };

  const save = async (values: EditorValues): Promise<void> => {
    const document = documentFrom(values, existing?.document.audio ?? null);
    const found = customDhikrProblems(document);
    setProblems(found);
    setAlert(found.length === 0 ? null : t("library.editor.errors.check"));
    if (found.length > 0) return;
    try {
      const dhikr = await send({
        entity_type: "custom_dhikr",
        entity_id: id,
        op: "put",
        base_version: base.dhikr,
        document,
      });
      if (dhikr.status === "rejected") setProblems(dhikr.fields);
      // Saved: trying again (if the tags fail) builds on this version, not the one the editor opened with.
      if (dhikr.status === "applied") setBase((previous) => ({ ...previous, dhikr: dhikr.version }));
      if (!wentThrough(dhikr)) {
        showSettled(dhikr);
        return;
      }
      if (!sameTags(values.tagIds, base.tagIds)) {
        const tags = await send({
          entity_type: "dhikr_personal",
          entity_id: id,
          op: "put",
          base_version: base.personal,
          document: { tag_ids: values.tagIds },
        });
        if (tags.status === "applied") {
          setBase((previous) => ({ ...previous, personal: tags.version, tagIds: values.tagIds }));
        }
        if (!wentThrough(tags)) {
          showSettled(tags);
          return;
        }
      }
      await navigate({ to: "/library/dhikrs/$key", params: { key: id }, replace: true });
    } catch (error) {
      setAlert(t(problemKey(error)));
    }
  };

  return { save, errors: errorMessages(problems, t), alert, isPending, conflict, refused };
}
