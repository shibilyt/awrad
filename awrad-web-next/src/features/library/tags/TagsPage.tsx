import { useState, type ReactElement } from "react";
import { Form } from "react-aria-components";
import { useTranslation } from "react-i18next";
import { useLanguage } from "@/shared/i18n";
import type { Entity, SyncState, UserTagDocument } from "@/shared/sync";
import { BottomSheet } from "@/shared/ui/BottomSheet";
import { Button } from "@/shared/ui/Button";
import { Card } from "@/shared/ui/Card";
import { ConfirmDialog } from "@/shared/ui/ConfirmDialog";
import { FormAlert } from "@/shared/ui/FormAlert";
import { TextField } from "@/shared/ui/TextField";
import { ConflictDialog, RefusedDialog } from "../custom/ConflictDialog";
import { sortedTags, useYours } from "../custom/data";
import { NotReady } from "../custom/NotReady";
import { BackBar } from "../LibraryScreen";
import { useTagActions, type TagActionResult } from "./useTagActions";

/**
 * A one-field form (a new tag, a new name): the field, its error, and the button. Cleared after
 * it succeeds when `clearOnDone`.
 */
export function TagNameForm({
  label,
  submitLabel,
  initial = "",
  clearOnDone = false,
  isPending,
  onSubmit,
}: {
  label: string;
  submitLabel: string;
  initial?: string;
  clearOnDone?: boolean;
  isPending: boolean;
  onSubmit: (name: string) => Promise<TagActionResult>;
}): ReactElement {
  const [name, setName] = useState(initial);
  const [error, setError] = useState<string | null>(null);
  return (
    <Form
      validationBehavior="aria"
      validationErrors={error === null ? {} : { tag: error }}
      onSubmit={(event) => {
        event.preventDefault();
        void onSubmit(name).then((result) => {
          setError(result.ok ? null : result.message);
          if (result.ok && clearOnDone) setName("");
        });
      }}
      className="flex flex-col gap-sm"
    >
      <TextField name="tag" label={label} value={name} onChange={setName} autoComplete="off" />
      <Button type="submit" variant="secondary" isPending={isPending}>
        {submitLabel}
      </Button>
    </Form>
  );
}

/** How many dhikrs have the tag. */
function usageOf(state: SyncState, tagId: string): number {
  return Object.values(state.dhikr_personal).filter((entity) => entity.document.tag_ids.includes(tagId)).length;
}

/** A tag in the list: its name and how many dhikrs have it, then Rename and Delete. */
function TagRow({
  tag,
  count,
  onRename,
  onDelete,
}: {
  tag: Entity<UserTagDocument>;
  count: number;
  onRename: () => void;
  onDelete: () => void;
}): ReactElement {
  const { t } = useTranslation();
  const name = tag.document.name;
  return (
    <li className="flex flex-wrap items-center gap-sm py-xs">
      <div className="flex min-w-0 flex-1 flex-col">
        <span dir="auto" className="truncate text-row-title text-on-surface">
          {name}
        </span>
        <span className="text-caption text-on-surface-variant">{t("library.dhikrCount", { count })}</span>
      </div>
      <Button variant="secondary" size="row" aria-label={t("library.tags.renameLabel", { name })} onPress={onRename}>
        {t("library.tags.rename")}
      </Button>
      <Button variant="secondary" size="row" aria-label={t("library.tags.deleteLabel", { name })} onPress={onDelete}>
        {t("library.tags.delete")}
      </Button>
    </li>
  );
}

/** The account's tags in a card, by name, or a line saying there are none. */
function TagList({
  state,
  onRename,
  onDelete,
}: {
  state: SyncState;
  onRename: (tag: Entity<UserTagDocument>) => void;
  onDelete: (tag: Entity<UserTagDocument>) => void;
}): ReactElement {
  const { t } = useTranslation();
  const language = useLanguage();
  const tags = sortedTags(state, language);
  if (tags.length === 0) return <p className="text-body text-on-surface-variant">{t("library.tags.none")}</p>;
  return (
    <Card>
      <ul aria-label={t("library.tags.listLabel")} className="flex flex-col gap-row-gap">
        {tags.map((tag) => (
          <TagRow
            key={tag.id}
            tag={tag}
            count={usageOf(state, tag.id)}
            onRename={() => {
              onRename(tag);
            }}
            onDelete={() => {
              onDelete(tag);
            }}
          />
        ))}
      </ul>
    </Card>
  );
}

/** The new-tag form, the tag list, and the sheet and dialogs that act on one tag. */
function TagManager({ accountId, state }: { accountId: string; state: SyncState }): ReactElement {
  const { t } = useTranslation();
  const actions = useTagActions(accountId, state);
  const [renaming, setRenaming] = useState<Entity<UserTagDocument> | null>(null);
  const [deleting, setDeleting] = useState<Entity<UserTagDocument> | null>(null);
  const [alert, setAlert] = useState<string | null>(null);
  return (
    <>
      <TagNameForm
        label={t("library.tags.new")}
        submitLabel={t("library.tags.add")}
        clearOnDone
        isPending={actions.isPending}
        onSubmit={actions.create}
      />
      <FormAlert message={alert} />
      <TagList state={state} onRename={setRenaming} onDelete={setDeleting} />
      <BottomSheet
        isOpen={renaming !== null}
        onOpenChange={(isOpen) => {
          if (!isOpen) setRenaming(null);
        }}
        title={t("library.tags.renameTitle")}
      >
        {renaming !== null && (
          <TagNameForm
            label={t("library.tags.name")}
            submitLabel={t("library.tags.save")}
            initial={renaming.document.name}
            isPending={actions.isPending}
            onSubmit={async (name) => {
              const result = await actions.rename(renaming.id, name);
              if (result.ok) setRenaming(null);
              return result;
            }}
          />
        )}
      </BottomSheet>
      <ConfirmDialog
        isOpen={deleting !== null}
        onOpenChange={(isOpen) => {
          if (!isOpen) setDeleting(null);
        }}
        title={t("library.tags.deleteTitle", { name: deleting?.document.name ?? "" })}
        confirmLabel={t("library.tags.delete")}
        cancelLabel={t("library.tags.cancel")}
        isPending={actions.isPending}
        onConfirm={() => {
          if (deleting === null) return;
          void actions.remove(deleting.id).then((result) => {
            setDeleting(null);
            setAlert(result.ok ? null : result.message);
          });
        }}
      >
        <p>{t("library.tags.deleteBody")}</p>
      </ConfirmDialog>
      <ConflictDialog conflict={actions.conflict} state={state} isPending={actions.isPending} />
      <RefusedDialog refused={actions.refused} />
    </>
  );
}

/** `/library/tags`, "Manage tags" (slice 3b): create, rename and delete the account's tags. */
export function TagsPage(): ReactElement {
  const { t } = useTranslation();
  const yours = useYours();
  return (
    <main className="mx-auto flex w-full max-w-content flex-col pb-page-margin">
      <BackBar title={t("library.tags.manage")} />
      <div className="flex flex-col gap-section-gap px-page-margin pt-sm">
        {yours.status === "ready" ? (
          <TagManager accountId={yours.accountId} state={yours.state} />
        ) : (
          <NotReady yours={yours} />
        )}
      </div>
    </main>
  );
}
