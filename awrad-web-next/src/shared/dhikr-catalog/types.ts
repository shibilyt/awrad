/**
 * The shape of the shared dhikr catalog (contracts/dhikr-catalog/v1/dhikr-catalog.schema.json).
 * scripts/generate-catalog.mjs fails on a key these types don't have, so the two stay in step.
 */

/** Text every language carries (titles). */
export interface FullText {
  readonly en: string;
  readonly ar: string;
  readonly ml: string;
}

/** Text where only English is required; the app falls back to it. */
export interface LocalText {
  readonly en: string;
  readonly ar?: string;
  readonly ml?: string;
}

export type DhikrKind = "quran" | "dhikr" | "dua" | "salawat" | "name_of_allah";

export interface Audio {
  /** A full https URL on dhikrs.awrad.app. */
  readonly url: string;
  readonly reciter?: { readonly name: LocalText };
  readonly style: "recitation" | "melodic" | "teaching";
  /** How many recitations one play of the file holds. */
  readonly repetitions: number;
  readonly durationMs?: number;
  readonly byteSize?: number;
  readonly mimeType?: string;
  readonly sha256?: string;
  readonly attribution?: string;
}

export interface QuranReference {
  readonly id: string;
  readonly type: "quran";
  readonly surah: number;
  readonly ayah_start: number;
  readonly ayah_end: number;
}

export interface HadithReference {
  readonly id: string;
  readonly type: "hadith";
  readonly collection: string;
  readonly number?: string;
  readonly narrator?: string;
  readonly grade?: string;
}

export interface BookReference {
  readonly id: string;
  readonly type: "book";
  readonly title: string;
  readonly author?: string;
  readonly volume?: string;
  readonly page?: string;
}

export interface ShaykhReference {
  readonly id: string;
  readonly type: "shaykh";
  readonly name: string;
  readonly note?: string;
}

export interface OtherReference {
  readonly id: string;
  readonly type: "other";
  readonly text: string;
  readonly url?: string;
}

export type Reference = QuranReference | HadithReference | BookReference | ShaykhReference | OtherReference;

export interface Virtue {
  readonly text: LocalText;
  /** Ids of the dhikr's own references. */
  readonly references: readonly string[];
}

export interface Dhikr {
  readonly id: string;
  readonly key: string;
  readonly kind: DhikrKind;
  /** The recited text with harakat; one ayah per line for Qur'an. */
  readonly arabic: string;
  readonly title: FullText;
  /** In each language's own script; Arabic has none. */
  readonly transliteration: { readonly en: string; readonly ml?: string };
  /** Search terms only, never shown. */
  readonly aliases?: {
    readonly en?: readonly string[];
    readonly ar?: readonly string[];
    readonly ml?: readonly string[];
  };
  readonly tags?: readonly string[];
  readonly translation: LocalText;
  readonly audio: Audio | null;
  readonly references: readonly Reference[];
  readonly virtues: readonly Virtue[];
}

export interface Collection {
  readonly key: string;
  readonly title: FullText;
  /** Dhikr keys, in order. */
  readonly dhikrs: readonly string[];
}

export interface Tag {
  readonly key: string;
  readonly title: FullText;
}

export interface Catalog {
  readonly version: 1;
  readonly contentRevision: number;
  readonly dhikrs: readonly Dhikr[];
  readonly collections: readonly Collection[];
  readonly tags: readonly Tag[];
}
