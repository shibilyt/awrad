import type { ReactElement, ReactNode } from "react";
import { useTranslation } from "react-i18next";
import { localized, transliterationFor, type Dhikr } from "@/shared/dhikr-catalog";
import { useLanguage } from "@/shared/i18n";
import { Card } from "@/shared/ui/Card";
import { AudioPlayer, type PlayerSource } from "./AudioPlayer";
import { quranReference, referenceLabel } from "./referenceLabel";

/** A labelled block of text under the Arabic: the transliteration or the translation. */
function TextSection({ title, children }: { title: string; children: string }): ReactElement {
  return (
    <section className="flex flex-col gap-xs">
      <h2 className="text-section-title text-on-surface">{title}</h2>
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

/** A recording the catalog doesn't have: a custom dhikr's upload, by its asset ID (so a new one plays afresh). */
export interface Recording {
  id: string;
  source: PlayerSource;
}

/**
 * The card holding the recited text, with the audio player bar at its bottom when there's a
 * recording: the catalog's, or the one given (a custom dhikr's upload).
 */
function TextCard({
  dhikr,
  recording,
  children,
}: {
  dhikr: Dhikr;
  recording: Recording | null;
  children: ReactNode;
}): ReactElement {
  const player: Recording | null =
    recording ?? (dhikr.audio === null ? null : { id: dhikr.key, source: { kind: "url", url: dhikr.audio.url } });
  return (
    <Card>
      <div className="flex flex-col items-center gap-lg py-sm">
        {children}
        {player !== null && <AudioPlayer key={player.id} source={player.source} />}
      </div>
    </Card>
  );
}

/**
 * A dhikr's text by kind (the slice brief's "Rendering by kind"):
 * - `quran`: the Arabic one ayah per line, its reference ("Qur'an 112:1–4"), then the
 *   transliteration and translation;
 * - `name_of_allah`: the name in `nameOfAllah`, then its meaning in `title`, both in the card;
 * - `dhikr`, `dua`, `salawat`: the Arabic, then the transliteration and translation.
 * The transliteration and translation are in the UI language, falling back to English; Arabic
 * shows no transliteration. A text the dhikr doesn't have (a custom dhikr's) leaves its section out.
 * The player bar plays the catalog's recording, or `recording` (a custom dhikr's upload).
 */
export function DhikrText({ dhikr, recording = null }: { dhikr: Dhikr; recording?: Recording | null }): ReactElement {
  const { t } = useTranslation();
  const language = useLanguage();
  const translation = localized(dhikr.translation, language);

  if (dhikr.kind === "name_of_allah") {
    return (
      <TextCard dhikr={dhikr} recording={recording}>
        <p lang="ar" dir="rtl" className="text-center text-name-of-allah text-on-surface">
          {dhikr.arabic}
        </p>
        <p dir="auto" className="text-center text-title text-on-surface">
          {translation}
        </p>
      </TextCard>
    );
  }

  const transliteration = transliterationFor(dhikr, language);
  const reference = dhikr.kind === "quran" ? quranReference(dhikr) : undefined;
  return (
    <>
      <TextCard dhikr={dhikr} recording={recording}>
        <ArabicText dhikr={dhikr} />
        {reference !== undefined && (
          <p className="text-caption text-on-surface-variant">{referenceLabel(reference, t, language)}</p>
        )}
      </TextCard>
      {transliteration !== null && transliteration !== "" && (
        <TextSection title={t("library.detail.transliteration")}>{transliteration}</TextSection>
      )}
      {translation !== "" && <TextSection title={t("library.detail.translation")}>{translation}</TextSection>}
    </>
  );
}
