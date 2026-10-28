import type { ReactElement } from "react";
import { useTranslation } from "react-i18next";
import { useLanguage } from "@/shared/i18n";
import type { CustomDhikrDocument, DhikrPersonalDocument, SyncState, UserTagDocument } from "@/shared/sync";
import { Card } from "@/shared/ui/Card";
import { ChoiceDialog } from "@/shared/ui/ConfirmDialog";
import { TagChip } from "@/shared/ui/TagChips";
import { pickText } from "./data";
import type { OpenConflict } from "./useEdit";

/** The server's copy of what was edited, in a card: a dhikr's title and Arabic, a tag's name, or a dhikr's tags. */
function TheirVersion({ conflict, state }: { conflict: OpenConflict; state: SyncState }): ReactElement {
  const { t } = useTranslation();
  const language = useLanguage();
  const { document } = conflict.current;
  let content: ReactElement;
  if (document === null) {
    content = <p>{t("library.conflict.deleted")}</p>;
  } else if (conflict.edit.entity_type === "custom_dhikr") {
    const dhikr = document as CustomDhikrDocument;
    content = (
      <>
        <p dir="auto" className="text-row-title text-on-surface">
          {pickText(dhikr.title, language)}
        </p>
        <p lang="ar" dir="rtl" className="line-clamp-3 text-quran-line text-on-surface">
          {dhikr.arabic}
        </p>
      </>
    );
  } else if (conflict.edit.entity_type === "user_tag") {
    content = (
      <p dir="auto" className="text-row-title text-on-surface">
        {(document as UserTagDocument).name}
      </p>
    );
  } else {
    const names = (document as DhikrPersonalDocument).tag_ids.flatMap((id) => state.user_tag[id]?.document.name ?? []);
    content =
      names.length === 0 ? (
        <p>{t("library.conflict.noTags")}</p>
      ) : (
        <ul className="flex flex-wrap gap-sm">
          {names.map((name) => (
            <li key={name}>
              <TagChip>{name}</TagChip>
            </li>
          ))}
        </ul>
      );
  }
  return (
    <Card shape="tile">
      <div className="flex flex-col gap-xs">
        <p className="text-caption text-on-surface-variant">{t("library.conflict.theirs")}</p>
        {content}
      </div>
    </Card>
  );
}

/**
 * "Changed on another device" (slice 3b): the server's version of what the person just saved,
 * and the choice: **Use theirs** (keep the server's copy) or **Keep mine** (save theirs over it).
 * It can't be dismissed without choosing.
 */
export function ConflictDialog({
  conflict,
  state,
  isPending,
}: {
  conflict: OpenConflict | null;
  state: SyncState;
  isPending: boolean;
}): ReactElement {
  const { t } = useTranslation();
  return (
    <ChoiceDialog
      isOpen={conflict !== null}
      title={t("library.conflict.title")}
      isPending={isPending}
      first={{ label: t("library.conflict.useTheirs"), onPress: () => conflict?.choose(false) }}
      second={{ label: t("library.conflict.keepMine"), onPress: () => conflict?.choose(true) }}
    >
      <p>{t(conflict?.edit.op === "delete" ? "library.conflict.bodyDelete" : "library.conflict.body")}</p>
      {conflict !== null && <TheirVersion conflict={conflict} state={state} />}
    </ChoiceDialog>
  );
}
