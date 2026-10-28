import { useNavigate } from "@tanstack/react-router";
import { useState, type ReactElement } from "react";
import { useTranslation } from "react-i18next";
import type { SyncState } from "@/shared/sync";
import { Button } from "@/shared/ui/Button";
import { ConfirmDialog } from "@/shared/ui/ConfirmDialog";
import { FormAlert } from "@/shared/ui/FormAlert";
import { DeleteIcon } from "@/shared/ui/icons.gen";
import { ConflictDialog, RefusedDialog } from "./ConflictDialog";
import { problemKey, settledKey, useEdit, wentThrough } from "./useEdit";

/**
 * "Delete dhikr" on one of the account's dhikrs: a destructive confirmation (it's final, and it
 * goes from every device), then one `delete` command on the version shown. Afterwards the Library.
 */
export function DeleteDhikr({
  accountId,
  state,
  dhikrId,
  title,
}: {
  accountId: string;
  state: SyncState;
  dhikrId: string;
  title: string;
}): ReactElement {
  const { t } = useTranslation();
  const navigate = useNavigate();
  const { send, isPending, conflict, refused } = useEdit(accountId);
  const [isOpen, setOpen] = useState(false);
  const [alert, setAlert] = useState<string | null>(null);

  const remove = async () => {
    const version = state.custom_dhikr[dhikrId]?.version ?? 0;
    try {
      const settled = await send({
        entity_type: "custom_dhikr",
        entity_id: dhikrId,
        op: "delete",
        base_version: version,
      });
      setOpen(false);
      if (settled.status === "theirs") return;
      // Gone already (deleted on another device) is what was asked for.
      if (wentThrough(settled) || settled.status === "gone") {
        await navigate({ to: "/library", replace: true });
        return;
      }
      const problem = settledKey(settled);
      setAlert(problem === null ? null : t(problem));
    } catch (error) {
      setOpen(false);
      setAlert(t(problemKey(error)));
    }
  };

  return (
    <div className="flex flex-col gap-sm">
      <FormAlert message={alert} />
      <Button
        variant="secondary"
        icon={DeleteIcon}
        onPress={() => {
          setOpen(true);
        }}
      >
        {t("library.custom.delete")}
      </Button>
      <ConfirmDialog
        isOpen={isOpen && conflict === null}
        onOpenChange={setOpen}
        title={t("library.custom.deleteTitle", { title })}
        confirmLabel={t("library.custom.deleteConfirm")}
        cancelLabel={t("library.tags.cancel")}
        isPending={isPending}
        onConfirm={() => void remove()}
      >
        <p>{t("library.custom.deleteBody")}</p>
      </ConfirmDialog>
      <ConflictDialog conflict={conflict} state={state} isPending={isPending} />
      <RefusedDialog refused={refused} />
    </div>
  );
}
