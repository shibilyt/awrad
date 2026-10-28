import type { TFunction } from "i18next";
import type { DhikrKind, Reference } from "@/shared/dhikr-catalog";
import {
  LONG_TEXT_MAX,
  REFERENCES_MAX,
  TITLE_MAX,
  type CustomDhikrDocument,
  type FieldProblem,
  type Languages3,
} from "@/shared/sync";

/**
 * The custom dhikr editor's values, as typed, and how they become a `custom_dhikr_document`.
 * Every text is kept as typed and trimmed on save; an empty one is `null` (API STYLE §3).
 */

export type ReferenceType = Reference["type"];
export const REFERENCE_TYPES: readonly ReferenceType[] = ["quran", "hadith", "book", "shaykh", "other"];

/** Each reference type's fields (the catalog's reference shape), the required ones first. */
export const REFERENCE_FIELDS: Record<ReferenceType, { required: readonly string[]; optional: readonly string[] }> = {
  quran: { required: ["surah", "ayah_start", "ayah_end"], optional: [] },
  hadith: { required: ["collection"], optional: ["number", "narrator", "grade"] },
  book: { required: ["title"], optional: ["author", "volume", "page"] },
  shaykh: { required: ["name"], optional: ["note"] },
  other: { required: ["text"], optional: ["url"] },
};
const NUMBERS: ReadonlySet<string> = new Set(["surah", "ayah_start", "ayah_end"]);

export interface ReferenceDraft {
  /** The reference's `id` (a key, unique in the dhikr): kept from the document, or `ref-N` for a new one. */
  id: string;
  type: ReferenceType;
  fields: Record<string, string>;
}

export interface EditorValues {
  kind: DhikrKind;
  arabic: string;
  title: { en: string; ar: string; ml: string };
  transliteration: { en: string; ml: string };
  translation: { en: string; ar: string; ml: string };
  references: ReferenceDraft[];
  tagIds: string[];
}

export const EMPTY_VALUES: EditorValues = {
  kind: "dhikr",
  arabic: "",
  title: { en: "", ar: "", ml: "" },
  transliteration: { en: "", ml: "" },
  translation: { en: "", ar: "", ml: "" },
  references: [],
  tagIds: [],
};

function referenceDraft(reference: Reference): ReferenceDraft {
  const fields: Record<string, string> = {};
  for (const [key, value] of Object.entries(reference)) {
    if (key !== "id" && key !== "type") fields[key] = String(value);
  }
  return { id: reference.id, type: reference.type, fields };
}

/** The editor's values for a saved dhikr and its tags. */
export function valuesFrom(document: CustomDhikrDocument, tagIds: readonly string[]): EditorValues {
  return {
    kind: document.kind,
    arabic: document.arabic,
    title: { en: document.title.en ?? "", ar: document.title.ar ?? "", ml: document.title.ml ?? "" },
    transliteration: { en: document.transliteration.en ?? "", ml: document.transliteration.ml ?? "" },
    translation: {
      en: document.translation.en ?? "",
      ar: document.translation.ar ?? "",
      ml: document.translation.ml ?? "",
    },
    references: document.references.map(referenceDraft),
    tagIds: [...tagIds],
  };
}

/** A new reference of `type`, with the first `ref-N` id the dhikr doesn't use. */
export function newReference(type: ReferenceType, existing: readonly ReferenceDraft[]): ReferenceDraft {
  const used = new Set(existing.map((reference) => reference.id));
  let number = 1;
  while (used.has(`ref-${String(number)}`)) number += 1;
  return { id: `ref-${String(number)}`, type, fields: {} };
}

function text(value: string): string | null {
  const trimmed = value.trim();
  return trimmed === "" ? null : trimmed;
}

function languages(values: { en: string; ar: string; ml: string }): Languages3 {
  return { en: text(values.en), ar: text(values.ar), ml: text(values.ml) };
}

/** A reference as the document has it: filled fields only, the Qur'an's numbers as numbers when they are. */
function referenceFrom(draft: ReferenceDraft): Reference {
  const reference: Record<string, unknown> = { id: draft.id, type: draft.type };
  const { required, optional } = REFERENCE_FIELDS[draft.type];
  for (const key of [...required, ...optional]) {
    const value = text(draft.fields[key] ?? "");
    if (value === null) continue;
    reference[key] = NUMBERS.has(key) && /^\d+$/.test(value) ? Number(value) : value;
  }
  // The shared validity rules check it before it's sent (`customDhikrProblems`).
  return reference as unknown as Reference;
}

/** The document to save. `audio` is kept as it was: a phone's recording stays on that phone. */
export function documentFrom(values: EditorValues, audio: CustomDhikrDocument["audio"]): CustomDhikrDocument {
  return {
    kind: values.kind,
    arabic: values.arabic.trim(),
    title: languages(values.title),
    transliteration: { en: text(values.transliteration.en), ml: text(values.transliteration.ml) },
    translation: languages(values.translation),
    audio,
    references: values.references.map(referenceFrom),
  };
}

/** Where a problem shows: the field's `name` in the form (`title.en`, `references.0`), or a group. */
export function fieldName(pointer: string): string {
  return pointer.replace(/^\//, "").replaceAll("/", ".");
}

function messageFor(problem: FieldProblem, t: TFunction): string {
  const name = fieldName(problem.field);
  switch (problem.code) {
    case "required":
    case "blank":
      if (name === "arabic") return t("library.editor.errors.arabicRequired");
      if (name === "title") return t("library.editor.errors.titleRequired");
      return t("library.editor.errors.invalid");
    case "too_long":
      return t("library.editor.errors.tooLong", { max: name.startsWith("title") ? TITLE_MAX : LONG_TEXT_MAX });
    case "too_many":
      return t("library.editor.errors.tooManyReferences", { max: REFERENCES_MAX });
    case "invalid":
      if (name === "kind") return t("library.editor.errors.kind");
      if (name.startsWith("references.")) return t("library.editor.errors.reference");
      return t("library.editor.errors.invalid");
    case "range":
      return t("library.editor.errors.ayahRange");
    case "duplicate":
    case "mismatch":
    case "not_allowed":
    case "not_found":
      return t("library.editor.errors.invalid");
  }
}

/** Messages by field name, the first problem of each field, translated. */
export function errorMessages(problems: readonly FieldProblem[], t: TFunction): Record<string, string> {
  const messages: Record<string, string> = {};
  for (const problem of problems) messages[fieldName(problem.field)] ??= messageFor(problem, t);
  return messages;
}
