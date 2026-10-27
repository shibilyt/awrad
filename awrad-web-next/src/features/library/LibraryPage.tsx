import { getRouteApi } from "@tanstack/react-router";
import { useId, useState, type ReactElement } from "react";
import { useTranslation } from "react-i18next";
import { searchDhikrs, useCatalog } from "@/shared/dhikr-catalog";
import { useLanguage } from "@/shared/i18n";
import { LargeTitleHeader } from "@/shared/ui/LargeTitleHeader";
import { SearchField } from "@/shared/ui/SearchField";
import { CollectionTiles } from "./CollectionTiles";
import { DhikrList } from "./DhikrList";

const route = getRouteApi("/library/");

/** A titled part of the Library: the title in `sectionTitle`, inside the page margin. */
function Section({ title, children }: { title: string; children: ReactElement }): ReactElement {
  const heading = useId();
  return (
    <section aria-labelledby={heading} className="flex flex-col gap-row-gap">
      <h2 id={heading} className="px-page-margin text-section-title text-on-surface">
        {title}
      </h2>
      {children}
    </section>
  );
}

/** Search results only: how many (announced as they change), the rows, or an empty state. */
function SearchResults({ query }: { query: string }): ReactElement {
  const { t } = useTranslation();
  const language = useLanguage();
  const results = searchDhikrs(useCatalog(), query, language);
  return (
    <div className="flex flex-col gap-row-gap">
      <div role="status" className="px-page-margin">
        {results.length === 0 ? (
          <div className="content-swap flex flex-col items-center gap-sm py-3xl text-center">
            <p className="text-card-title text-on-surface">{t("library.search.empty", { query: query.trim() })}</p>
            <p className="text-on-surface-variant">{t("library.search.emptyHint")}</p>
          </div>
        ) : (
          <p className="text-caption text-on-surface-variant">
            {t("library.search.results", { count: results.length })}
          </p>
        )}
      </div>
      {results.length > 0 && <DhikrList dhikrs={results} label={t("library.search.resultsLabel")} />}
    </div>
  );
}

/**
 * `/library`: a large title, a search field whose query is kept in the URL (`?q=`), then the
 * collections as tiles and every dhikr as a row. While searching it shows only the results.
 */
export function LibraryPage(): ReactElement {
  const { t } = useTranslation();
  const catalog = useCatalog();
  const { q = "" } = route.useSearch();
  const navigate = route.useNavigate();
  // The field follows what's typed at once; the URL follows it (replaced, not pushed per key).
  // A navigation that clears the query (the Library tab) clears the field too.
  const [query, setQuery] = useState(q);
  const [urlQuery, setUrlQuery] = useState(q);
  if (q !== urlQuery) {
    setUrlQuery(q);
    if (q === "") setQuery("");
  }
  const searching = query.trim() !== "";

  return (
    <main className="mx-auto flex w-full max-w-content flex-col gap-section-gap pb-page-margin">
      <div className="flex flex-col">
        <LargeTitleHeader title={t("library.title")} />
        <div className="px-page-margin">
          <SearchField
            label={t("library.search.label")}
            placeholder={t("library.search.placeholder")}
            value={query}
            onChange={(value) => {
              setQuery(value);
              void navigate({ search: value.trim() === "" ? {} : { q: value }, replace: true });
            }}
          />
        </div>
      </div>
      {searching ? (
        <SearchResults query={query} />
      ) : (
        <>
          <Section title={t("library.collections")}>
            <CollectionTiles label={t("library.collections")} />
          </Section>
          <Section title={t("library.allDhikrs")}>
            <DhikrList dhikrs={catalog.dhikrs} label={t("library.allDhikrs")} />
          </Section>
        </>
      )}
    </main>
  );
}
