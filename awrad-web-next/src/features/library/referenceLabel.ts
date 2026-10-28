import type { TFunction } from "i18next";
import type { Dhikr, Reference } from "@/shared/dhikr-catalog";
import type { Language } from "@/shared/i18n";

const LEFT_TO_RIGHT_ISOLATE = "\u2066";
const POP_DIRECTIONAL_ISOLATE = "\u2069";

/** Keeps "112:1–4" in order inside right-to-left text. */
function isolate(text: string, language: Language): string {
  return language === "ar" ? `${LEFT_TO_RIGHT_ISOLATE}${text}${POP_DIRECTIONAL_ISOLATE}` : text;
}

/**
 * A reference as a short label in the UI language: "Qur'an 112:1–4", "Qur'an 71:10",
 * "Sahih Muslim 408", "Sunan Abi Dawud 1518 · Da'if (al-Albani)", a book with its author, volume
 * and page, a shaykh with a note, or other text. Collection and book names are as the catalog
 * gives them.
 */
export function referenceLabel(reference: Reference, t: TFunction, language: Language): string {
  switch (reference.type) {
    case "quran": {
      const { surah, ayah_start, ayah_end } = reference;
      const ayahs = ayah_start === ayah_end ? String(ayah_start) : `${String(ayah_start)}–${String(ayah_end)}`;
      return t("library.reference.quran", { place: isolate(`${String(surah)}:${ayahs}`, language) });
    }
    case "hadith": {
      const name = [reference.collection, reference.number].filter((part) => part !== undefined).join(" ");
      return reference.grade === undefined ? name : t("library.reference.graded", { name, grade: reference.grade });
    }
    case "book":
      return [
        reference.title,
        reference.author,
        reference.volume === undefined ? undefined : t("library.reference.volume", { volume: reference.volume }),
        reference.page === undefined ? undefined : t("library.reference.page", { page: reference.page }),
      ]
        .filter((part) => part !== undefined)
        .join(t("library.reference.separator"));
    case "shaykh":
      return reference.note === undefined
        ? reference.name
        : t("library.reference.withNote", { name: reference.name, note: reference.note });
    case "other":
      return reference.text;
  }
}

/** The labels of the references a virtue cites, by id, in the order it cites them. */
export function citedLabels(dhikr: Dhikr, ids: readonly string[], t: TFunction, language: Language): string[] {
  return ids.flatMap((id) => {
    const reference = dhikr.references.find((candidate) => candidate.id === id);
    return reference === undefined ? [] : [referenceLabel(reference, t, language)];
  });
}

/** The Qur'an reference a `quran` dhikr shows under its text. */
export function quranReference(dhikr: Dhikr): Reference | undefined {
  return dhikr.references.find((reference) => reference.type === "quran");
}
