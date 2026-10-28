import { getRouteApi } from "@tanstack/react-router";
import { useState, type ReactElement } from "react";
import { useTranslation } from "react-i18next";
import { searchDhikrs, useCatalog } from "@/shared/dhikr-catalog";
import { useLanguage } from "@/shared/i18n";
import { RoundButton } from "@/shared/ui/Button";
import { AddIcon } from "@/shared/ui/icons.gen";
import { LargeTitleHeader } from "@/shared/ui/LargeTitleHeader";
import { SearchField } from "@/shared/ui/SearchField";
import { CollectionTiles } from "./CollectionTiles";
import { useYours } from "./custom/data";
import { TagFilter, YoursNotice, yoursTile } from "./custom/YourDhikrs";
import { DhikrList } from "./DhikrList";
import { Section } from "./LibraryScreen";

const route = getRouteApi("/library/");

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
 * `/library`: a large title (with "New dhikr" when signed in), a search field whose query is kept
 * in the URL (`?q=`), then the tag filter (`?tags=`, signed in), the collections as tiles ("Your
 * dhikrs" first when the account has any) and every dhikr as a row. Signed out, a note offers
 * sign-in. While searching it shows only the results.
 */
export function LibraryPage(): ReactElement {
  const { t } = useTranslation();
  const catalog = useCatalog();
  const { q = "", tags = [] } = route.useSearch();
  const navigate = route.useNavigate();
  const yours = useYours();
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
        <LargeTitleHeader
          title={t("library.title")}
          {...(yours.status === "ready"
            ? {
                action: (
                  <RoundButton
                    icon={AddIcon}
                    aria-label={t("library.yours.new")}
                    onPress={() => void navigate({ to: "/library/dhikrs/new" })}
                  />
                ),
              }
            : {})}
        />
        <div className="px-page-margin">
          <SearchField
            label={t("library.search.label")}
            value={query}
            onChange={(value) => {
              setQuery(value);
              void navigate({
                search: (previous) => ({
                  ...(previous.tags === undefined ? {} : { tags: previous.tags }),
                  ...(value.trim() === "" ? {} : { q: value }),
                }),
                replace: true,
              });
            }}
          />
        </div>
      </div>
      {searching ? (
        <SearchResults query={query} />
      ) : (
        <>
          <YoursNotice yours={yours} />
          {yours.status === "ready" && (
            <TagFilter
              state={yours.state}
              selected={tags}
              onChange={(selected) => {
                void navigate({
                  search: (previous) => ({
                    ...(previous.q === undefined ? {} : { q: previous.q }),
                    ...(selected.length === 0 ? {} : { tags: selected }),
                  }),
                  replace: true,
                });
              }}
            />
          )}
          <Section title={t("library.collections")}>
            <CollectionTiles label={t("library.collections")} first={yoursTile(yours)} />
          </Section>
          <Section title={t("library.allDhikrs")}>
            <DhikrList dhikrs={catalog.dhikrs} label={t("library.allDhikrs")} />
          </Section>
        </>
      )}
    </main>
  );
}
