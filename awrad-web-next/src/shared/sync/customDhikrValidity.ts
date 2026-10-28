/**
 * Which custom dhikr documents are valid (contracts/sync/v1/fixtures/custom_dhikr_validity.json,
 * sync.schema.json `custom_dhikr_document`). The editor checks before saving; the server checks
 * every put and stays the authority. Errors are `{field, code}`, `field` a JSON Pointer into the
 * document, sorted by field and then code, like a `rejected` receipt's (without `/document`).
 */

export type FieldCode =
  "required" | "blank" | "too_long" | "too_many" | "duplicate" | "not_allowed" | "invalid" | "mismatch" | "not_found";

export interface FieldProblem {
  field: string;
  code: FieldCode;
}

export const TITLE_MAX = 120;
export const LONG_TEXT_MAX = 5000;
export const REFERENCES_MAX = 20;
export const DHIKR_KINDS = ["quran", "dhikr", "dua", "salawat", "name_of_allah"] as const;

const MEMBERS = ["kind", "arabic", "title", "transliteration", "translation", "audio", "references"];
const KEY = /^[a-z0-9]+(-[a-z0-9]+)*$/;
/** JSON Schema's `pattern: "\\S"`: at least one character that isn't ECMAScript white space. */
const NOT_BLANK = /\S/u;

type Json = Record<string, unknown>;

function isObject(value: unknown): value is Json {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

/** Code points, the unit the limits count in (not UTF-16 units). */
export function codePointLength(text: string): number {
  return Array.from(text).length;
}

/** Problems with one text value: blank (empty or only spaces) and too long. */
export function textProblems(field: string, value: string, max: number): FieldProblem[] {
  const problems: FieldProblem[] = [];
  if (!NOT_BLANK.test(value)) problems.push({ field, code: "blank" });
  if (codePointLength(value) > max) problems.push({ field, code: "too_long" });
  return problems;
}

function isText(value: unknown): value is string {
  return typeof value === "string" && NOT_BLANK.test(value);
}

/** A per-language object: every language key present, each text or null, nothing else. */
function languageProblems(field: string, value: unknown, languages: readonly string[], max: number): FieldProblem[] {
  if (!isObject(value)) return [{ field, code: "invalid" }];
  const problems: FieldProblem[] = Object.keys(value)
    .filter((key) => !languages.includes(key))
    .map((key) => ({ field: `${field}/${key}`, code: "not_allowed" }));
  for (const language of languages) {
    const text = value[language];
    const at = `${field}/${language}`;
    if (!(language in value)) problems.push({ field: at, code: "required" });
    else if (typeof text === "string") problems.push(...textProblems(at, text, max));
    else if (text !== null) problems.push({ field: at, code: "invalid" });
  }
  return problems;
}

const OPTIONAL_TEXT: Record<string, readonly string[]> = {
  quran: [],
  hadith: ["number", "narrator", "grade"],
  book: ["author", "volume", "page"],
  shaykh: ["note"],
  other: [],
};
const REQUIRED_TEXT: Record<string, readonly string[]> = {
  quran: [],
  hadith: ["collection"],
  book: ["title"],
  shaykh: ["name"],
  other: ["text"],
};

function isPositiveInteger(value: unknown, max = Number.MAX_SAFE_INTEGER): boolean {
  return typeof value === "number" && Number.isInteger(value) && value >= 1 && value <= max;
}

/** The catalog's reference shape (dhikr-catalog.schema.json `reference`). */
export function isValidReference(reference: unknown): boolean {
  if (!isObject(reference) || typeof reference["id"] !== "string" || !KEY.test(reference["id"])) return false;
  const type = reference["type"];
  if (typeof type !== "string" || !(type in REQUIRED_TEXT)) return false;
  const required = REQUIRED_TEXT[type] ?? [];
  const optional = OPTIONAL_TEXT[type] ?? [];
  const numbers = type === "quran" ? ["surah", "ayah_start", "ayah_end"] : [];
  const urls = type === "other" ? ["url"] : [];
  const allowed = new Set(["id", "type", ...required, ...optional, ...numbers, ...urls]);
  if (Object.keys(reference).some((key) => !allowed.has(key))) return false;
  if (!required.every((key) => isText(reference[key]))) return false;
  if (!optional.every((key) => !(key in reference) || isText(reference[key]))) return false;
  if (type === "quran") {
    return (
      isPositiveInteger(reference["surah"], 114) &&
      isPositiveInteger(reference["ayah_start"]) &&
      isPositiveInteger(reference["ayah_end"])
    );
  }
  return !("url" in reference) || (typeof reference["url"] === "string" && URL.canParse(reference["url"]));
}

function referencesProblems(value: unknown): FieldProblem[] {
  if (!Array.isArray(value)) return [{ field: "/references", code: "invalid" }];
  const problems: FieldProblem[] = [];
  if (value.length > REFERENCES_MAX) problems.push({ field: "/references", code: "too_many" });
  value.forEach((reference: unknown, index) => {
    if (!isValidReference(reference)) problems.push({ field: `/references/${String(index)}`, code: "invalid" });
  });
  return problems;
}

function isLocalAudio(value: unknown): boolean {
  return isObject(value) && Object.keys(value).length === 1 && value["local_only"] === true;
}

function memberProblems(document: Json, member: string): FieldProblem[] {
  const field = `/${member}`;
  if (!(member in document)) return [{ field, code: "required" }];
  const value = document[member];
  switch (member) {
    case "kind":
      return (DHIKR_KINDS as readonly unknown[]).includes(value) ? [] : [{ field, code: "invalid" }];
    case "arabic":
      return typeof value === "string" ? textProblems(field, value, LONG_TEXT_MAX) : [{ field, code: "invalid" }];
    case "title": {
      const problems = languageProblems(field, value, ["en", "ar", "ml"], TITLE_MAX);
      const hasText = isObject(value) && ["en", "ar", "ml"].some((language) => typeof value[language] === "string");
      return hasText || !isObject(value) ? problems : [{ field, code: "required" }, ...problems];
    }
    case "transliteration":
      return languageProblems(field, value, ["en", "ml"], LONG_TEXT_MAX);
    case "translation":
      return languageProblems(field, value, ["en", "ar", "ml"], LONG_TEXT_MAX);
    case "audio":
      return value === null || isLocalAudio(value) ? [] : [{ field, code: "invalid" }];
    default:
      return referencesProblems(value);
  }
}

function compare(a: FieldProblem, b: FieldProblem): number {
  if (a.field !== b.field) return a.field < b.field ? -1 : 1;
  return a.code < b.code ? -1 : a.code > b.code ? 1 : 0;
}

/** Every problem with a custom dhikr document, sorted; empty when it's valid. */
export function customDhikrProblems(document: unknown): FieldProblem[] {
  if (!isObject(document)) return [{ field: "", code: "invalid" }];
  const problems: FieldProblem[] = Object.keys(document)
    .filter((key) => !MEMBERS.includes(key))
    .map((key) => ({ field: `/${key}`, code: "not_allowed" }));
  for (const member of MEMBERS) problems.push(...memberProblems(document, member));
  return problems.sort(compare);
}
