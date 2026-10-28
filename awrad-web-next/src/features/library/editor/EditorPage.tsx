import { getRouteApi } from "@tanstack/react-router";
import type { ReactElement, ReactNode } from "react";
import { useTranslation } from "react-i18next";
import { useYours } from "../custom/data";
import { NotReady } from "../custom/NotReady";
import { BackBar, NotFound } from "../LibraryScreen";
import { DhikrEditor } from "./DhikrEditor";

const editRoute = getRouteApi("/library/dhikrs/$key_/edit");

/** A pushed page with Back and its title in the top bar. */
function EditorScreen({ title, children }: { title: string; children: ReactNode }): ReactElement {
  return (
    <main className="mx-auto flex w-full max-w-content flex-col pb-page-margin">
      <BackBar title={title} />
      <div className="flex flex-col gap-section-gap px-page-margin pt-sm">{children}</div>
    </main>
  );
}

/** `/library/dhikrs/new`: the editor for a new custom dhikr. */
export function NewDhikrPage(): ReactElement {
  const { t } = useTranslation();
  const yours = useYours();
  return (
    <EditorScreen title={t("library.editor.newTitle")}>
      {yours.status === "ready" ? (
        <DhikrEditor accountId={yours.accountId} state={yours.state} existing={null} />
      ) : (
        <NotReady yours={yours} />
      )}
    </EditorScreen>
  );
}

/** `/library/dhikrs/$key/edit`: the editor for one of the account's dhikrs. Built-ins can't be edited, only tagged. */
export function EditDhikrPage(): ReactElement {
  const { t } = useTranslation();
  const { key } = editRoute.useParams();
  const yours = useYours();
  if (yours.status !== "ready") {
    return (
      <EditorScreen title={t("library.editor.editTitle")}>
        <NotReady yours={yours} />
      </EditorScreen>
    );
  }
  const existing = yours.state.custom_dhikr[key];
  if (existing === undefined) return <NotFound message={t("library.notFound.custom")} />;
  return (
    <EditorScreen title={t("library.editor.editTitle")}>
      {/* Keyed by the dhikr, so another dhikr's editor starts from its own values. */}
      <DhikrEditor key={key} accountId={yours.accountId} state={yours.state} existing={existing} />
    </EditorScreen>
  );
}
