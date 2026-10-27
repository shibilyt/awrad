import { getRouteApi } from "@tanstack/react-router";
import { useId, type ReactElement } from "react";
import { useTranslation } from "react-i18next";
import { findDhikr, findTag, localized, useCatalog, type Dhikr } from "@/shared/dhikr-catalog";
import { useLanguage } from "@/shared/i18n";
import { Card } from "@/shared/ui/Card";
import { useSecondaryFill } from "@/shared/ui/Surface";
import { DhikrText } from "./DhikrText";
import { BackBar, NotFound } from "./LibraryScreen";
import { citedLabels } from "./referenceLabel";

const route = getRouteApi("/library/dhikrs/$key");

/** The dhikr's catalog tags as chips (not yet filters). */
function Tags({ dhikr }: { dhikr: Dhikr }): ReactElement | null {
  const { t } = useTranslation();
  const language = useLanguage();
  const catalog = useCatalog();
  const fill = useSecondaryFill();
  const tags = (dhikr.tags ?? []).flatMap((key) => findTag(catalog, key) ?? []);
  if (tags.length === 0) return null;
  return (
    <ul aria-label={t("library.detail.tags")} className="flex flex-wrap gap-sm">
      {tags.map((tag) => (
        <li key={tag.key} className={`rounded-chip px-md py-xs text-label ${fill}`}>
          {tag.title[language]}
        </li>
      ))}
    </ul>
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
 * `/library/dhikrs/$key`: the title, the text by kind with the audio button, the tags, and the
 * virtues with their references. An unknown key shows not found.
 */
export function DhikrPage(): ReactElement {
  const { t } = useTranslation();
  const language = useLanguage();
  const catalog = useCatalog();
  const { key } = route.useParams();
  const dhikr = findDhikr(catalog, key);
  if (dhikr === undefined) return <NotFound message={t("library.notFound.dhikr")} />;

  return (
    <main className="mx-auto flex w-full max-w-content flex-col pb-page-margin">
      <BackBar />
      <div className="flex flex-col gap-section-gap px-page-margin">
        <h1 className="text-title text-on-surface">{dhikr.title[language]}</h1>
        <DhikrText dhikr={dhikr} />
        <Tags dhikr={dhikr} />
        <Virtues dhikr={dhikr} />
      </div>
    </main>
  );
}
