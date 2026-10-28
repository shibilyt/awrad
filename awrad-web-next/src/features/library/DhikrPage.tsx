import { getRouteApi } from "@tanstack/react-router";
import { useId, type ReactElement } from "react";
import { useTranslation } from "react-i18next";
import { findDhikr, findTag, localized, useCatalog, type Dhikr } from "@/shared/dhikr-catalog";
import { useLanguage } from "@/shared/i18n";
import { isValidId } from "@/shared/identity";
import type { CustomDhikrDocument, Entity } from "@/shared/sync";
import { Card } from "@/shared/ui/Card";
import { TagChip } from "@/shared/ui/TagChips";
import { TextButtonLink } from "@/shared/ui/TextLink";
import { asDhikr, useYours, type Yours } from "./custom/data";
import { DeleteDhikr } from "./custom/DeleteDhikr";
import { NotReady } from "./custom/NotReady";
import { DhikrText } from "./DhikrText";
import { BackBar, NotFound } from "./LibraryScreen";
import { citedLabels, referenceLabel, sourceReferences } from "./referenceLabel";
import { YourTags } from "./tags/YourTags";

const route = getRouteApi("/library/dhikrs/$key");

/** "Tags": the dhikr's catalog tags as chips. */
function Tags({ dhikr }: { dhikr: Dhikr }): ReactElement | null {
  const { t } = useTranslation();
  const language = useLanguage();
  const catalog = useCatalog();
  const heading = useId();
  const tags = (dhikr.tags ?? []).flatMap((key) => findTag(catalog, key) ?? []);
  if (tags.length === 0) return null;
  return (
    <section aria-labelledby={heading} className="flex flex-col gap-row-gap">
      <h2 id={heading} className="text-section-title text-on-surface">
        {t("library.detail.tags")}
      </h2>
      <ul className="flex flex-wrap gap-sm">
        {tags.map((tag) => (
          <li key={tag.key}>
            <TagChip>{tag.title[language]}</TagChip>
          </li>
        ))}
      </ul>
    </section>
  );
}

/** Each virtue in a card, with the references it cites under it. */
function Virtues({ dhikr }: { dhikr: Dhikr }): ReactElement | null {
  const { t } = useTranslation();
  const language = useLanguage();
  const heading = useId();
  if (dhikr.virtues.length === 0) return null;
  return (
    <section aria-labelledby={heading} className="flex flex-col gap-row-gap">
      <h2 id={heading} className="text-section-title text-on-surface">
        {t("library.detail.virtues")}
      </h2>
      <ul className="flex flex-col gap-row-gap">
        {dhikr.virtues.map((virtue) => (
          <li key={virtue.text.en}>
            <Card shape="tile">
              <p dir="auto" className="text-body text-on-surface">
                {localized(virtue.text, language)}
              </p>
              <p className="text-caption text-on-surface-variant">
                {citedLabels(dhikr, virtue.references, t, language).join(t("library.reference.list"))}
              </p>
            </Card>
          </li>
        ))}
      </ul>
    </section>
  );
}

/**
 * "Sources" (components.md, slice 3b): the reference labels not already shown, one per line in
 * `caption`, in the dhikr's order. A built-in lists those no virtue cites; a custom dhikr all of
 * its own; neither repeats the Qur'an reference a `quran` dhikr shows in its card.
 */
function Sources({ dhikr }: { dhikr: Dhikr }): ReactElement | null {
  const { t } = useTranslation();
  const language = useLanguage();
  const heading = useId();
  const references = sourceReferences(dhikr);
  if (references.length === 0) return null;
  return (
    <section aria-labelledby={heading} className="flex flex-col gap-row-gap">
      <h2 id={heading} className="text-section-title text-on-surface">
        {t("library.detail.sources")}
      </h2>
      <ul className="flex flex-col gap-xs">
        {references.map((reference) => (
          <li key={reference.id} dir="auto" className="text-caption text-on-surface-variant">
            {referenceLabel(reference, t, language)}
          </li>
        ))}
      </ul>
    </section>
  );
}

/**
 * A dhikr's page, built-in or the account's own: the text by kind, the catalog's tags, the
 * account's tags with "Manage tags" (signed in), virtues, sources, and for the account's own Edit
 * (in the top bar), a note about its phone recording, and Delete.
 */
function DhikrDetail({
  dhikr,
  yours,
  custom,
}: {
  dhikr: Dhikr;
  yours: Yours;
  custom: Entity<CustomDhikrDocument> | null;
}): ReactElement {
  const { t } = useTranslation();
  const language = useLanguage();
  const title = dhikr.title[language];
  const edit = (
    <TextButtonLink to="/library/dhikrs/$key/edit" params={{ key: dhikr.id }}>
      {t("library.custom.edit")}
    </TextButtonLink>
  );
  return (
    <main className="mx-auto flex w-full max-w-content flex-col pb-page-margin">
      <BackBar title={title} {...(custom === null ? {} : { end: edit })} />
      <div className="flex flex-col gap-section-gap px-page-margin">
        <DhikrText dhikr={dhikr} />
        {(custom?.document.audio ?? null) !== null && (
          <p className="text-caption text-on-surface-variant">{t("library.editor.audioOnPhone")}</p>
        )}
        <Tags dhikr={dhikr} />
        {yours.status === "ready" && <YourTags accountId={yours.accountId} state={yours.state} dhikrId={dhikr.id} />}
        <Virtues dhikr={dhikr} />
        <Sources dhikr={dhikr} />
        {custom !== null && yours.status === "ready" && (
          <DeleteDhikr accountId={yours.accountId} state={yours.state} dhikrId={dhikr.id} title={title} />
        )}
      </div>
    </main>
  );
}

/**
 * `/library/dhikrs/$key` (components.md "Dhikr detail screen"): a built-in by its catalog key, or
 * one of the account's own dhikrs by its ID, once they're read. Back and the title in the top bar,
 * the text by kind with the audio player bar, then the tags, the virtues with their references,
 * and the other sources. An unknown key shows not found; an ID while signed out offers sign-in.
 */
export function DhikrPage(): ReactElement {
  const { t } = useTranslation();
  const catalog = useCatalog();
  const { key } = route.useParams();
  const yours = useYours();
  const builtIn = findDhikr(catalog, key);
  if (builtIn !== undefined) return <DhikrDetail dhikr={builtIn} yours={yours} custom={null} />;
  if (yours.status === "ready") {
    const custom = yours.state.custom_dhikr[key];
    if (custom !== undefined) return <DhikrDetail dhikr={asDhikr(custom)} yours={yours} custom={custom} />;
  }
  if (yours.status === "ready" || (yours.status === "signedOut" && !isValidId(key))) {
    return <NotFound message={t("library.notFound.dhikr")} />;
  }
  return (
    <main className="mx-auto flex w-full max-w-content flex-col pb-page-margin">
      <BackBar />
      <div className="px-page-margin">
        <NotReady yours={yours} />
      </div>
    </main>
  );
}
