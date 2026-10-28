import type { ReactElement } from "react";
import { useTranslation } from "react-i18next";
import { LargeTitleHeader } from "@/shared/ui/LargeTitleHeader";
import { BackBar } from "../LibraryScreen";
import { useYours } from "./data";
import { NotReady } from "./NotReady";
import { YoursList } from "./YourDhikrs";

/**
 * `/library/yours`, the "Your dhikrs" tile's list page (slice 3b): like a collection's, the title,
 * how many, and the account's dhikrs, newest first. A pushed page, with no bottom bar.
 */
export function YoursPage(): ReactElement {
  const { t } = useTranslation();
  const yours = useYours();
  return (
    <main className="mx-auto flex w-full max-w-content flex-col pb-page-margin">
      <BackBar />
      <LargeTitleHeader title={t("library.yours.title")} />
      {yours.status === "ready" ? (
        <YoursList state={yours.state} />
      ) : (
        <div className="px-page-margin">
          <NotReady yours={yours} />
        </div>
      )}
    </main>
  );
}
