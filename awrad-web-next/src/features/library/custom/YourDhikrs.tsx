import type { ReactElement } from "react";
import { useTranslation } from "react-i18next";
import { useCatalog } from "@/shared/dhikr-catalog";
import { useLanguage } from "@/shared/i18n";
import type { SyncState } from "@/shared/sync";
import { Button } from "@/shared/ui/Button";
import { Card } from "@/shared/ui/Card";
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

/** Signed out: what "Your dhikrs" would hold, and a link to sign in. */
function SignedOut(): ReactElement {
  const { t } = useTranslation();
  return (
    <Notice action={<TextLink to="/sign-in">{t("library.yours.signIn")}</TextLink>}>
      {t("library.yours.signedOut")}
    </Notice>
  );
}

/**
 * The Library's "Your dhikrs" (slice 3b): the signed-in account's own dhikrs, newest first, with
 * "Manage tags"; an empty state that offers "New dhikr"; a sign-in link when signed out; and a
 * retry when they couldn't be read.
 */
export function YourDhikrs({ yours }: { yours: Yours }): ReactElement {
  const { t } = useTranslation();
  const title = t("library.yours.title");
  const manage =
    yours.status === "ready" ? (
      <TextButtonLink to="/library/tags">{t("library.tags.manage")}</TextButtonLink>
    ) : undefined;
  let content: ReactElement;
  switch (yours.status) {
    case "loading":
      content = (
        <p role="status" className="px-page-margin text-caption text-on-surface-variant">
          {t("library.yours.loading")}
        </p>
      );
      break;
    case "signedOut":
      content = <SignedOut />;
      break;
    case "error":
      content = (
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
      break;
    case "ready": {
      const dhikrs = customDhikrs(yours.state);
      content =
        dhikrs.length === 0 ? (
          <Notice action={<TextButtonLink to="/library/dhikrs/new">{t("library.yours.new")}</TextButtonLink>}>
            {t("library.yours.empty")}
          </Notice>
        ) : (
          <DhikrList dhikrs={dhikrs} label={title} />
        );
    }
  }
  return (
    <Section title={title} {...(manage === undefined ? {} : { action: manage })}>
      {content}
    </Section>
  );
}

/**
 * "Filter by tag": the account's tags as chips. With some chosen, the dhikrs (built-in and the
 * account's own) that have every chosen tag, with how many in a `status` region, or an empty
 * state. Nothing when the account has no tags.
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
    <Section title={t("library.filter.title")}>
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
