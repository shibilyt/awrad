import { useState, type ReactElement } from "react";
import { useTranslation } from "react-i18next";
import { useLanguage } from "@/shared/i18n";
import type { SyncState } from "@/shared/sync";
import { BottomSheet } from "@/shared/ui/BottomSheet";
import { Button } from "@/shared/ui/Button";
import { FormAlert } from "@/shared/ui/FormAlert";
import { OptionCheckboxGroup, OptionRow } from "@/shared/ui/OptionRow";
import { ConflictDialog, RefusedDialog } from "../custom/ConflictDialog";
import { sortedTags, tagIdsOf } from "../custom/data";
import { problemKey, settledKey, useEdit, wentThrough } from "../custom/useEdit";
import { TagNameForm } from "./TagsPage";
import { useTagActions } from "./useTagActions";

const MAX_TAGS = 20;

/** The sheet's content, mounted when it opens: the tags and the version it opened on. */
function DhikrTags({
  accountId,
  state,
  dhikrId,
  onDone,
}: {
  accountId: string;
  state: SyncState;
  dhikrId: string;
  onDone: () => void;
}): ReactElement {
  const { t } = useTranslation();
  const language = useLanguage();
  const { send, isPending, conflict, refused } = useEdit(accountId);
  const actions = useTagActions(accountId, state);
  const [baseVersion] = useState(() => state.dhikr_personal[dhikrId]?.version ?? 0);
  const [selected, setSelected] = useState(() => tagIdsOf(state, dhikrId));
  const [alert, setAlert] = useState<string | null>(null);
  const tags = sortedTags(state, language);

  const save = async () => {
    try {
      const settled = await send({
        entity_type: "dhikr_personal",
        entity_id: dhikrId,
        op: "put",
        base_version: baseVersion,
        document: { tag_ids: selected.filter((id) => id in state.user_tag) },
      });
      if (wentThrough(settled)) {
        onDone();
        return;
      }
      const problem = settledKey(settled);
      setAlert(problem === null ? null : t(problem));
    } catch (error) {
      setAlert(t(problemKey(error)));
    }
  };

  return (
    <div className="flex flex-col gap-lg">
      <p className="text-caption text-on-surface-variant">{t("library.tags.hint", { max: MAX_TAGS })}</p>
      {tags.length === 0 ? (
        <p className="text-body text-on-surface-variant">{t("library.tags.none")}</p>
      ) : (
        <OptionCheckboxGroup aria-label={t("library.detail.tags")} value={selected} onChange={setSelected}>
          {tags.map((tag) => (
            <OptionRow
              key={tag.id}
              value={tag.id}
              label={tag.document.name}
              isDisabled={selected.length >= MAX_TAGS && !selected.includes(tag.id)}
            />
          ))}
        </OptionCheckboxGroup>
      )}
      <TagNameForm
        label={t("library.tags.new")}
        submitLabel={t("library.tags.add")}
        clearOnDone
        isPending={actions.isPending}
        onSubmit={async (name) => {
          const result = await actions.create(name);
          if (result.ok && selected.length < MAX_TAGS) setSelected((previous) => [...previous, result.tagId]);
          return result;
        }}
      />
      <FormAlert message={alert} />
      <Button isPending={isPending} onPress={() => void save()}>
        {t("library.tags.save")}
      </Button>
      <ConflictDialog conflict={conflict ?? actions.conflict} state={state} isPending={isPending} />
      <RefusedDialog refused={refused ?? actions.refused} />
    </div>
  );
}

/** "Manage tags" on a dhikr (built-in or custom): choose its tags, or make a new one, then save. */
export function DhikrTagsSheet({
  accountId,
  state,
  dhikrId,
  isOpen,
  onOpenChange,
}: {
  accountId: string;
  state: SyncState;
  dhikrId: string;
  isOpen: boolean;
  onOpenChange: (isOpen: boolean) => void;
}): ReactElement {
  const { t } = useTranslation();
  return (
    <BottomSheet isOpen={isOpen} onOpenChange={onOpenChange} title={t("library.tags.dhikrTitle")}>
      {isOpen && (
        <DhikrTags
          accountId={accountId}
          state={state}
          dhikrId={dhikrId}
          onDone={() => {
            onOpenChange(false);
          }}
        />
      )}
    </BottomSheet>
  );
}
