import { Suspense, useId, type ReactElement } from "react";
import { useTranslation } from "react-i18next";
import { useCatalog } from "@/shared/dhikr-catalog";
import { useLanguage } from "@/shared/i18n";
import { CollectionTile } from "@/shared/ui/CollectionTile";
import { TextButtonLink } from "@/shared/ui/TextLink";

/** Every collection as a tile, in a row that scrolls sideways, `pageMargin` at both ends. */
export function CollectionTiles({ label }: { label: string }): ReactElement {
  const { t } = useTranslation();
  const language = useLanguage();
  const catalog = useCatalog();
  return (
    <ul aria-label={label} className="flex gap-md overflow-x-auto px-page-margin">
      {catalog.collections.map((collection) => (
        <li key={collection.key} className="flex">
          <CollectionTile
            to="/library/collections/$key"
            params={{ key: collection.key }}
            heading={collection.title[language]}
            count={t("library.dhikrCount", { count: collection.dhikrs.length })}
          />
        </li>
      ))}
    </ul>
  );
}

/**
 * Home's "Featured dhikr collections": the section title, "View all" (the Library), and the
 * collection tiles. The tiles wait for the catalog's chunk in a space of their own height, so
 * nothing below them moves when they appear.
 */
export function FeaturedCollections(): ReactElement {
  const { t } = useTranslation();
  const heading = useId();
  return (
    <section aria-labelledby={heading} className="flex w-full flex-col gap-xs text-start">
      <div className="flex items-center justify-between gap-md px-page-margin">
        <h2 id={heading} className="text-section-title text-on-surface">
          {t("library.featured")}
        </h2>
        <TextButtonLink to="/library">{t("library.viewAll")}</TextButtonLink>
      </div>
      <Suspense fallback={<div className="h-collection-tile" />}>
        <CollectionTiles label={t("library.featured")} />
      </Suspense>
    </section>
  );
}
