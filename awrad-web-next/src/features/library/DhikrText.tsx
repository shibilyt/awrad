import type { ReactElement, ReactNode } from "react";
import { useTranslation } from "react-i18next";
import { localized, transliterationFor, type Dhikr } from "@/shared/dhikr-catalog";
import { useLanguage } from "@/shared/i18n";
import { Card } from "@/shared/ui/Card";
import { AudioButton } from "./AudioButton";
import { quranReference, referenceLabel } from "./referenceLabel";

/** A labelled block of text under the Arabic: the transliteration or the translation. */
function TextSection({ title, children }: { title: string; children: string }): ReactElement {
  return (
    <section className="flex flex-col gap-xs">
      <h2 className="text-section-title text-on-surface-variant">{title}</h2>
      <p dir="auto" className="text-body text-on-surface">
        {children}
      </p>
    </section>
  );
}

/** The Arabic in the `quran` style, centred; one ayah per line for Qur'an. */
function ArabicText({ dhikr }: { dhikr: Dhikr }): ReactElement {
  const lines = dhikr.kind === "quran" ? dhikr.arabic.split("\n") : [dhikr.arabic];
  return (
    <div lang="ar" dir="rtl" className="flex flex-col text-center text-quran text-on-surface">
      {/* Lines can repeat, and they never move, so their position is their key. */}
      {lines.map((line, index) => (
        <p key={index} className="whitespace-pre-line">
          {line}
        </p>
      ))}
    </div>
  );
}

/** The card holding the recited text, with the audio button under it when there's a recording. */
function TextCard({ dhikr, children }: { dhikr: Dhikr; children: ReactNode }): ReactElement {
  return (
    <Card>
      <div className="flex flex-col items-center gap-lg py-sm">
        {children}
        {dhikr.audio !== null && <AudioButton audio={dhikr.audio} />}
      </div>
    </Card>
  );
}

/**
 * A dhikr's text by kind (the slice brief's "Rendering by kind"):
 * - `quran`: the Arabic one ayah per line, its reference ("Qur'an 112:1–4"), then the
 *   transliteration and translation;
 * - `name_of_allah`: the name large and centred, then its meaning;
 * - `dhikr`, `dua`, `salawat`: the Arabic, then the transliteration and translation.
 * The transliteration and translation are in the UI language, falling back to English; Arabic
 * shows no transliteration.
 */
export function DhikrText({ dhikr }: { dhikr: Dhikr }): ReactElement {
  const { t } = useTranslation();
  const language = useLanguage();
  const translation = localized(dhikr.translation, language);

  if (dhikr.kind === "name_of_allah") {
    return (
      <TextCard dhikr={dhikr}>
        <p lang="ar" dir="rtl" className="text-center font-arabic text-large-title text-on-surface">
          {dhikr.arabic}
        </p>
        <p dir="auto" className="text-center text-card-title text-on-surface-variant">
          {translation}
        </p>
      </TextCard>
    );
  }

  const transliteration = transliterationFor(dhikr, language);
  const reference = dhikr.kind === "quran" ? quranReference(dhikr) : undefined;
  return (
    <>
      <TextCard dhikr={dhikr}>
        <ArabicText dhikr={dhikr} />
        {reference !== undefined && (
          <p className="text-caption text-on-surface-variant">{referenceLabel(reference, t, language)}</p>
        )}
      </TextCard>
      {transliteration !== null && (
        <TextSection title={t("library.detail.transliteration")}>{transliteration}</TextSection>
      )}
      <TextSection title={t("library.detail.translation")}>{translation}</TextSection>
    </>
  );
}
