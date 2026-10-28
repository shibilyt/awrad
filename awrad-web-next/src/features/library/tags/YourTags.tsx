import { useId, useState, type ReactElement } from "react";
import { useTranslation } from "react-i18next";
import type { SyncState } from "@/shared/sync";
import { Button } from "@/shared/ui/Button";
import { TagChip } from "@/shared/ui/TagChips";
import { tagIdsOf } from "../custom/data";
import { DhikrTagsSheet } from "./DhikrTagsSheet";

/**
 * A dhikr's own tags on its page (built-in or custom): the chips, in the user's order, or a
 * line saying it has none, and "Manage tags", which opens the sheet to choose them.
 */
export function YourTags({
  accountId,
  state,
  dhikrId,
}: {
  accountId: string;
  state: SyncState;
  dhikrId: string;
}): ReactElement {
  const { t } = useTranslation();
  const heading = useId();
  const [isOpen, setOpen] = useState(false);
  const names = tagIdsOf(state, dhikrId).flatMap((id) => state.user_tag[id]?.document.name ?? []);
  return (
    <section aria-labelledby={heading} className="flex flex-col gap-row-gap">
      <h2 id={heading} className="text-section-title text-on-surface">
        {t("library.tags.yours")}
      </h2>
      {names.length === 0 ? (
        <p className="text-body text-on-surface-variant">{t("library.tags.noneOnDhikr")}</p>
      ) : (
        <ul aria-label={t("library.tags.yours")} className="flex flex-wrap gap-sm">
          {names.map((name) => (
            <li key={name}>
              <TagChip>{name}</TagChip>
            </li>
          ))}
        </ul>
      )}
      <div>
        <Button
          variant="secondary"
          size="row"
          onPress={() => {
            setOpen(true);
          }}
        >
          {t("library.tags.manage")}
        </Button>
      </div>
      <DhikrTagsSheet accountId={accountId} state={state} dhikrId={dhikrId} isOpen={isOpen} onOpenChange={setOpen} />
    </section>
  );
}
