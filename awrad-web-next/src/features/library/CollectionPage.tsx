import { getRouteApi } from "@tanstack/react-router";
import type { ReactElement } from "react";
import { useTranslation } from "react-i18next";
import { collectionDhikrs, findCollection, useCatalog } from "@/shared/dhikr-catalog";
import { useLanguage } from "@/shared/i18n";
import { LargeTitleHeader } from "@/shared/ui/LargeTitleHeader";
import { DhikrList } from "./DhikrList";
import { BackBar, NotFound } from "./LibraryScreen";

const route = getRouteApi("/library/collections/$key");

/** `/library/collections/$key`: the collection's title, how many it holds, and its dhikrs in order. */
export function CollectionPage(): ReactElement {
  const { t } = useTranslation();
  const language = useLanguage();
  const catalog = useCatalog();
  const { key } = route.useParams();
  const collection = findCollection(catalog, key);
  if (collection === undefined) return <NotFound message={t("library.notFound.collection")} />;

  const title = collection.title[language];
  return (
    <main className="mx-auto flex w-full max-w-content flex-col pb-page-margin">
      <BackBar />
      <LargeTitleHeader title={title} />
      <div className="flex flex-col gap-row-gap">
        <p className="px-page-margin text-caption text-on-surface-variant">
          {t("library.dhikrCount", { count: collection.dhikrs.length })}
        </p>
        <DhikrList dhikrs={collectionDhikrs(catalog, collection)} label={title} />
      </div>
    </main>
  );
}
