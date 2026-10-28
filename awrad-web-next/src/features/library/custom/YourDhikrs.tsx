import type { ReactElement } from "react";
import { useTranslation } from "react-i18next";
import { useCatalog } from "@/shared/dhikr-catalog";
import { useLanguage } from "@/shared/i18n";
import type { SyncState } from "@/shared/sync";
import { Button } from "@/shared/ui/Button";
import { Card } from "@/shared/ui/Card";
import { CollectionTile } from "@/shared/ui/CollectionTile";
import { FilterChips } from "@/shared/ui/TagChips";
import { TextButtonLink, TextLink } from "@/shared/ui/TextLink";
import { DhikrList } from "../DhikrList";
import { Section } from "../LibraryScreen";
import { customDhikrs, sortedTags, withAllTags, type Yours } from "./data";
import { problemKey } from "./useEdit";

/** A short message in a card inside the page margin, with an optional action under it. */
function Notice({ children, action }: { children: string; action?: ReactElement }): ReactElement {
  return (
    <div className="px-page-margin">
      <Card shape="tile">
        <div className="flex flex-col items-start gap-sm">
          <p className="text-body text-on-surface-variant">{children}</p>
          {action}
        </div>
      </Card>
    </div>
  );
}

/** The "Your dhikrs" tile, with how many, opening their list (`/library/yours`). */
function YoursTile({ count }: { count: number }): ReactElement {
  const { t } = useTranslation();
  return (
    <CollectionTile to="/library/yours" heading={t("library.yours.title")} count={t("library.dhikrCount", { count })} />
  );
}

/**
 * The "Your dhikrs" collection tile (components.md, slice 3b) when the account has dhikrs of its
 * own, for the Library to put first in its tile row; `null` otherwise (none, or not read yet).
 */
export function yoursTile(yours: Yours): ReactElement | null {
  const count = yours.status === "ready" ? Object.keys(yours.state.custom_dhikr).length : 0;
  return count === 0 ? null : <YoursTile count={count} />;
}

/**
 * What the Library says about the account's own dhikrs when they can't be shown: a sign-in link
 * when signed out (the web edits online and signed in only), or a retry when they couldn't be
 * read. Nothing while loading or once they're here: the tile shows them.
 */
export function YoursNotice({ yours }: { yours: Yours }): ReactElement | null {
  const { t } = useTranslation();
  switch (yours.status) {
    case "signedOut":
      return (
        <Notice action={<TextLink to="/sign-in">{t("library.yours.signIn")}</TextLink>}>
          {t("library.yours.signedOut")}
        </Notice>
      );
    case "error":
      return (
        <Notice
          action={
            <Button variant="secondary" size="row" onPress={yours.retry}>
              {t("library.yours.retry")}
            </Button>
          }
        >
          {t(problemKey(yours.error))}
        </Notice>
      );
    case "loading":
    case "ready":
      return null;
  }
}

/** The account's dhikrs, newest first, or an empty state that offers "New dhikr". */
export function YoursList({ state }: { state: SyncState }): ReactElement {
  const { t } = useTranslation();
  const dhikrs = customDhikrs(state);
  if (dhikrs.length === 0) {
    return (
      <Notice action={<TextButtonLink to="/library/dhikrs/new">{t("library.yours.new")}</TextButtonLink>}>
        {t("library.yours.empty")}
      </Notice>
    );
  }
  return (
    <div className="flex flex-col gap-row-gap">
      <p className="px-page-margin text-caption text-on-surface-variant">
        {t("library.dhikrCount", { count: dhikrs.length })}
      </p>
      <DhikrList dhikrs={dhikrs} label={t("library.yours.title")} />
    </div>
  );
}

/**
 * "Filter by tag": the account's tags as chips, with "Manage tags". With some chosen, the dhikrs
 * (built-in and the account's own) that have every chosen tag, with how many in a `status`
 * region, or an empty state. Nothing when the account has no tags.
 */
export function TagFilter({
  state,
  selected,
  onChange,
}: {
  state: SyncState;
  selected: readonly string[];
  onChange: (selected: string[]) => void;
}): ReactElement | null {
  const { t } = useTranslation();
  const language = useLanguage();
  const catalog = useCatalog();
  const tags = sortedTags(state, language);
  if (tags.length === 0) return null;
  const chosen = selected.filter((id) => id in state.user_tag);
  const matches = chosen.length === 0 ? [] : withAllTags(state, [...customDhikrs(state), ...catalog.dhikrs], chosen);
  return (
    <Section
      title={t("library.filter.title")}
      action={<TextButtonLink to="/library/tags">{t("library.tags.manage")}</TextButtonLink>}
    >
      <div className="flex flex-col gap-row-gap">
        <div className="px-page-margin">
          <FilterChips
            label={t("library.filter.title")}
            chips={tags.map((tag) => ({ id: tag.id, label: tag.document.name }))}
            selected={chosen}
            onChange={onChange}
          />
        </div>
        {chosen.length > 0 && (
          <>
            <p role="status" className="px-page-margin text-caption text-on-surface-variant">
              {matches.length === 0
                ? t("library.filter.empty")
                : t("library.filter.results", { count: matches.length })}
            </p>
            {matches.length > 0 && <DhikrList dhikrs={matches} label={t("library.filter.resultsLabel")} />}
          </>
        )}
      </div>
    </Section>
  );
}
